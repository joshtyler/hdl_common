// SDRAM control logic for wb_sdram.sv

// Could split most of this out into a bank machine, to support concurrent banks

// Naming convention for timing parameters
// T_XXX <= In clock cycles
// T_XXX_ps <= In picoseconds

module  wb_sdram_controller
#(
	parameter ROW_ADDR_BITS = 12,
	parameter COL_ADDR_BITS = 9,
	parameter BANK_SEL_BITS = 2,
	parameter DATA_BYTES    = 2,
	parameter CLK_RATE      = 50_000_000,
	parameter T_RC_ps       = 60_000,
	parameter T_RP_ps       = 15_000,
	parameter T_CL          = 3,
	parameter T_RSC         = 2,
	parameter REFRSH_PERIOD_ms = 64,
	parameter T_RAS_min_ps  = 42_000,
	// It is advisable to be slightly cautious with T_RAS_max
	// This is because the state machine might take one or two exta cycles to honor it
	// Not currently a concern since we currently break out long before it is a problem for refreshes
	parameter T_RAS_max_ps  = 99800_000,
	parameter T_RCD_ps      = 15_000,
	parameter T_WR          = 2
) (
	input logic clk,
	input logic sresetn,

	output logic                                                cmd_i_ready,
	input logic                                                 cmd_i_valid,
	input logic [BANK_SEL_BITS+ROW_ADDR_BITS+COL_ADDR_BITS-1:0] cmd_i_addr,
	input logic                                                 cmd_i_we,

	output logic read_dq_valid,

	output logic [ROW_ADDR_BITS-1:0] ram_a,
	output logic [BANK_SEL_BITS-1:0] ram_bs,
	output logic                     ram_cs_n,
	output logic                     ram_ras_n,
	output logic                     ram_cas_n,
	output logic                     ram_we_n,
	output logic [DATA_BYTES-1:0]    ram_dqm,
	output logic                     ram_cke
);

assign ram_cke = 1;
assign ram_dqm = '0;

localparam REFRSH_CYCLES_PER_REFRESH_PERIOD = 4096;

// Handle refreshing
localparam integer CLOCK_CYCLES_PER_REFRESH_CYCLE = $floor(((REFRSH_PERIOD_ms*(10.0**-3))/REFRSH_CYCLES_PER_REFRESH_PERIOD)/(1.0/CLK_RATE));
localparam REFRESH_CTR_WIDTH = $clog2(CLOCK_CYCLES_PER_REFRESH_CYCLE);
logic [REFRESH_CTR_WIDTH-1:0] refresh_ctr;

logic refresh_request_valid;
logic refresh_request_ready;

always @(posedge clk)
begin
	if(!sresetn)
	begin
		refresh_ctr <= 0;
		refresh_request_valid <= 0;
	end else begin
		if(refresh_request_valid && refresh_request_ready)
		begin
			refresh_request_valid <= 0;
		end

		refresh_ctr <= refresh_ctr + 1;
		if(refresh_ctr == CLOCK_CYCLES_PER_REFRESH_CYCLE-1)
		begin
			refresh_ctr <= 0;
			refresh_request_valid <= 1;
		end
	end
end

localparam [2:0] SM_INIT_PRECHARGE = 3'b000;
localparam [2:0] SM_INIT_SET_MODE  = 3'b001;
localparam [2:0] SM_IDLE           = 3'b010;
localparam [2:0] SM_ACTIVE         = 3'b011;
logic [2:0] state;

// Hard to know how wide to make this, I can't see any timeout needing more than 255 cycles
localparam TIMEOUT_CTR_WIDTH = 8;
logic [TIMEOUT_CTR_WIDTH-1:0] timeout_ctr;
localparam integer T_RC  = $ceil((T_RC_ps*(10.0e-12))/(1.0/CLK_RATE));
localparam integer T_RP  = $ceil((T_RP_ps*(10.0e-12))/(1.0/CLK_RATE));
localparam integer T_RCD = $ceil((T_RCD_ps*(10.0e-12))/(1.0/CLK_RATE));

localparam integer T_RAS_min = $ceil((T_RAS_min_ps*(10.0e-12))/(1.0/CLK_RATE));
localparam integer T_RAS_max = $floor((T_RAS_max_ps*(10.0e-12))/(1.0/CLK_RATE));
// These counters are clog2(the number+1), because we need to store the parameter, not the parameter-1
logic [$clog2(T_RAS_min+1)-1:0] t_ras_min_ctr;
logic [$clog2(T_RAS_max+1)-1:0] t_ras_max_ctr;

logic [$clog2(T_WR+1)-1:0] t_wr_ctr;

logic [T_CL-1:0] t_cl_shreg;
assign read_dq_valid = t_cl_shreg[0];

logic [3:0] cmd;
localparam [3:0] CMD_NOP           = 4'b1111;
localparam [3:0] CMD_AUTO_REFRESH  = 4'b0001;
localparam [3:0] CMD_PRECHARGE     = 4'b0010;
localparam [3:0] CMD_SET_MODE      = 4'b0000;
localparam [3:0] CMD_ACTIVE        = 4'b0011;
localparam [3:0] CMD_WRITE         = 4'b0100;
localparam [3:0] CMD_READ          = 4'b0101;

assign ram_we_n  = cmd[0];
assign ram_cas_n = cmd[1];
assign ram_ras_n = cmd[2];
assign ram_cs_n  = cmd[3];

localparam [ROW_ADDR_BITS-1:0] ADDR_SET_MODE =
{
	{(ROW_ADDR_BITS-10){1'b0}},
	1'b0, // Burst read and burst write
	1'b0, // Reserved
	1'b0, // Test mode
	T_CL[2:0],
	1'b0, // Sequential addressing mode
	3'b000 // Burst length of one
};

// Use row bank column ordering
logic [COL_ADDR_BITS-1:0] cmd_i_addr_col;
logic [BANK_SEL_BITS-1:0] cmd_i_addr_bank;
logic [ROW_ADDR_BITS-1:0] cmd_i_addr_row;

assign cmd_i_addr_col  = cmd_i_addr[COL_ADDR_BITS-1:0];
assign cmd_i_addr_bank = cmd_i_addr[BANK_SEL_BITS+COL_ADDR_BITS-1:COL_ADDR_BITS];
assign cmd_i_addr_row  = cmd_i_addr[ROW_ADDR_BITS+BANK_SEL_BITS+COL_ADDR_BITS-1:BANK_SEL_BITS+COL_ADDR_BITS];

// Start up procedure:
	// After power up wait 200us (a lot more than that has passed by the time the bitstream is loaded and we are out of reset)
	// Precharge all banks
	// Program mode register
	// Do eight refresh cycles
logic [3:0] init_refresh_ctr;
logic [BANK_SEL_BITS-1:0] open_bank;
logic [ROW_ADDR_BITS-1:0] open_row;

// Signal to tell us to close the bank now if we in the active state
// Close row if:
	// Refresh is due
	// The bank has been open for the max time
	// The user wants to access data in another bank and/or row
logic close_row;
assign close_row = (refresh_request_valid|| (t_ras_max_ctr == 0) || (cmd_i_valid && ((cmd_i_addr_row != open_row) || (cmd_i_addr_bank != open_bank))));

always @(posedge clk)
begin
	if(!sresetn)
	begin
		state <= SM_INIT_PRECHARGE;
		timeout_ctr <= 0;
		init_refresh_ctr <= 0;
		t_cl_shreg <= 0;
	end else begin

		// Shift register to show when we are expecting a read response
		t_cl_shreg <= {(cmd == CMD_READ), t_cl_shreg[T_CL-1:1]};

		// Timers for active state
		if(t_ras_min_ctr > 0)
		begin
			t_ras_min_ctr <= t_ras_min_ctr-1;
		end

		if(t_ras_max_ctr > 0)
		begin
			t_ras_max_ctr <= t_ras_max_ctr-1;
		end

		if(timeout_ctr > 0)
		begin
			// If we are waiting for another operation to finish, wait here
			timeout_ctr <= timeout_ctr -1;
		end

		if(t_wr_ctr > 0)
		begin
			t_wr_ctr <= t_wr_ctr-1;
		end

		if(timeout_ctr == 0)
		begin
			// Main state machine
			case(state)
				SM_INIT_PRECHARGE:
				begin
					timeout_ctr <= T_RP;
					state <= SM_INIT_SET_MODE;
				end
				SM_INIT_SET_MODE:
				begin
					state <= SM_IDLE;
					timeout_ctr <= T_RSC;
					// We need to have eight referesh cycles either before or after setting mode register
					// This counter keeps track of the cycles remaining
					init_refresh_ctr <= 4'b1000;
				end
				SM_IDLE:
				begin
					if(cmd == CMD_ACTIVE)
					begin
						// Open the bank and row
						// Store the opened bank and row
						open_bank <= cmd_i_addr_bank;
						open_row  <= cmd_i_addr_row;

						state <= SM_ACTIVE;
						timeout_ctr <= T_RCD;

						t_ras_min_ctr <= T_RAS_min;
						t_ras_max_ctr <= T_RAS_max;
					end else if(cmd == CMD_AUTO_REFRESH)
					begin
						timeout_ctr <= T_RC;
						if(init_refresh_ctr > 0)
						begin
							init_refresh_ctr <= init_refresh_ctr-1;
						end
					end;
				end

				SM_ACTIVE:
				begin
					if(cmd == CMD_PRECHARGE)
					begin
						state <= SM_IDLE;
						timeout_ctr <= T_RP;
					end else if(cmd == CMD_WRITE) begin
						// We can't precharge until T_WR after issuing a write
						t_wr_ctr <= T_WR;
					end
				end

				default:
				begin
					state <= SM_INIT_PRECHARGE; // Should never happen
				end
			endcase
		end
	end
end

always @(*)
begin
	cmd = CMD_NOP;
	ram_a = '0;
	ram_bs = '0;
	refresh_request_ready = 0;
	cmd_i_ready = 0;
	if(sresetn && timeout_ctr == 0)
	begin
		case(state)
			SM_INIT_PRECHARGE:
			begin
				cmd = CMD_PRECHARGE;
				ram_a[10] = 1; // Precharge all
			end
			SM_INIT_SET_MODE:
			begin
				cmd = CMD_SET_MODE;
				ram_a = ADDR_SET_MODE;
				ram_bs = '0;
			end
			SM_IDLE:
			begin
				refresh_request_ready = 1;
				if(refresh_request_valid || (init_refresh_ctr > 0))
				begin
					cmd = CMD_AUTO_REFRESH;
				end else if(cmd_i_valid) begin
					cmd    = CMD_ACTIVE;
					ram_bs = cmd_i_addr_bank;
					ram_a  = cmd_i_addr_row;
				end
			end
			SM_ACTIVE:
			// We don't have to worry about T_RRD (bank to bank interleaved open delay) becuase we only open one bank at once
			// (And T_RRD << T_RAS_min)
			// We have to be in SM_ACTIVE within the bounds of t_RAS
			// This is both a minimum and a maximum
			// It is timed from the active command

			// At the moment we break out as soon as we see a refresh available
			// We don't have to do this, we could have a more complex system for better performance
			// N.B. This means we currenly break for refreshes long before t_ras_max is a problem
			begin
				if(close_row)
				begin
					// Only permit the close if we have been open for at least the minimum time
					// And we have waited long enough after a write
					if((t_ras_min_ctr == 0) && (t_wr_ctr == 0))
					begin
						cmd = CMD_PRECHARGE;
						ram_a[10] = 0; // Only precharge this bank, not all. Although it doesn't matter in current configuration
						ram_bs = open_bank;
					end
				end else begin
					// If we have a command to issue, issue it
					// Unless it is a write and we already have a read in progress
					// Previously I had the condition of only stopping a write if the read would result in bus contention
					// I.E. (cmd_i_valid && ((cmd_i_we == 0) || (t_cl_shreg[0] == 0)))
					// But the model didn't seem to like this, it would cancel the read...
					// The datasheet is a little unclear, but now I'm not sure this is a valid thing to do?
					// Until proven otherwise, I will leave this as the safer condition
					if (cmd_i_valid && ((cmd_i_we == 0) || (t_cl_shreg == 0)))
					begin
						cmd_i_ready = 1;
						// N.B. we have already checked that the row and bank is the open row and bank
						// We are good to go on issuing a transaction
						if(cmd_i_we)
						begin
							cmd = CMD_WRITE;
						end else begin
							cmd = CMD_READ;
						end
						ram_a[10] = 0; // Don't auto precharge
						ram_a[COL_ADDR_BITS-1:0] = cmd_i_addr_col;
						ram_bs = open_bank;
					end
				end
			end
		endcase
	end
end
endmodule
