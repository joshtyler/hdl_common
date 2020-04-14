// SDRAM control logic for wb_sdram.sv

// Could split most of this out into a bank machine, to support concurrent banks

// Naming convention for timing parameters
// T_XXX <= In clock cycles
// T_XXX_s <= In seconds

module  wb_sdram_controller
#(
	parameter ROW_ADDR_BITS = 12,
	parameter COL_ADDR_BITS = 9,
	parameter BANK_SEL_BITS = 2,
	parameter DATA_BYTES    = 2,
	parameter CLK_RATE      = 50e6,
	parameter T_RC_s        = 60e-9,
	parameter T_RP_s        = 15e-9,
	parameter T_CL          = 3,
	parameter T_RSC         = 2,
	parameter REFRSH_PERIOD = 64e-3,
	parameter T_RAS_min_s   = 42e-9,
	// It is advisable to be slightly cautious with T_RAS_max
	// This is because the state machine might take one or two exta cycles to honor it
	// Not currently a concern since we currently break out long before it is a problem for refreshes
	parameter T_RAS_max_s   = 99800e-9,
	parameter T_RCD_s       = 15e-9
) (
	input logic clk,
	input logic sresetn,

	output logic                                                cmd_i_ready,
	input logic                                                 cmd_i_valid,
	input logic [BANK_SEL_BITS+ROW_ADDR_BITS+COL_ADDR_BITS-1:0] cmd_i_addr,
	input logic                                                 cmd_i_we,

	output logic [ROW_ADDR_BITS-1:0] ram_a,
	output logic [BANK_SEL_BITS-1:0] ram_bs,
	output logic                     ram_cs_n,
	output logic                     ram_ras_n,
	output logic                     ram_cas_n,
	output logic                     ram_we_n,
	output logic [DATA_BYTES-1:0]    ram_dqm_n,
	output logic                     ram_cke
);

assign ram_cke = 1;
assign ram_dqm_n = '0;

localparam REFRSH_CYCLES_PER_REFRESH_PERIOD = 4096;

// Handle refreshing
localparam integer CLOCK_CYCLES_PER_REFRESH_CYCLE = (REFRSH_PERIOD/REFRSH_CYCLES_PER_REFRESH_PERIOD)/(1.0/CLK_RATE);
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
localparam integer T_RC  = T_RC_s/(1.0/CLK_RATE);
localparam integer T_RP  = T_RP_s/(1.0/CLK_RATE);
localparam integer T_RCD = T_RCD_s/(1.0/CLK_RATE);

localparam integer T_RAS_min = T_RAS_min_s/(1.0/CLK_RATE);
localparam integer T_RAS_max = T_RAS_max_s/(1.0/CLK_RATE);
// These counters are clog2(the number+1), because we need to store the parameter, not the parameter-1
logic [$clog2(T_RAS_min+1)-1:0] t_ras_min_ctr;
logic [$clog2(T_RAS_max+1)-1:0] t_ras_max_ctr;

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
assign cmd_i_ready = (state == SM_ACTIVE) && (timeout_ctr == 0) && !close_row;

always @ (posedge clk)
begin
	if(!sresetn)
	begin
		state <= SM_INIT_PRECHARGE;
		timeout_ctr <= 0;
		cmd <= CMD_NOP;
		init_refresh_ctr <= 0;
	end else begin

		cmd <= CMD_NOP;

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
		end else if((refresh_request_valid && refresh_request_ready) || (init_refresh_ctr > 0)) begin
			// If we are due a refresh cycle, this takes priority over the main state machine
			// We are either here for the periodic timer, or becuase we are doing the requrired refresh cycles after setting the mode register
			cmd <= CMD_AUTO_REFRESH;
			timeout_ctr <= T_RC;
			if(init_refresh_ctr > 0)
			begin
				init_refresh_ctr <= init_refresh_ctr-1;
			end
		end else begin
			// Main state machine
			case(state)
				SM_INIT_PRECHARGE:
				begin
					cmd <= CMD_PRECHARGE;
					ram_a[10] <= 1; // Precharge all
					timeout_ctr <= T_RP;
					state <= SM_INIT_SET_MODE;
				end
				SM_INIT_SET_MODE:
				begin
					cmd <= CMD_SET_MODE;
					ram_a <= ADDR_SET_MODE;
					ram_bs <= '0;
					state <= SM_IDLE;
					timeout_ctr <= T_RSC;
					// We need to have eight referesh cycles either before or after setting mode register
					// This counter keeps track of the cycles remaining
					init_refresh_ctr <= 4'b1000;
				end
				SM_IDLE:
				begin
					if(cmd_i_valid)
					begin
						// Open the bank and row
						// Store the opened bank and row
						ram_bs    <= cmd_i_addr_bank;
						open_bank <= cmd_i_addr_bank;
						ram_a     <= cmd_i_addr_row;
						open_row  <= cmd_i_addr_row;

						cmd <= CMD_ACTIVE;
						state <= SM_ACTIVE;
						timeout_ctr <= T_RCD;

						t_ras_min_ctr <= T_RAS_min;
						t_ras_max_ctr <= T_RAS_max;
					end
				end

				SM_ACTIVE:
				begin
					// We don't have to worry about T_RRD (bank to bank interleaved open delay) becuase we only open one bank at once
					// (And T_RRD << T_RAS_min)
					// We have to be in SM_ACTIVE within the bounds of t_RAS
					// This is both a minimum and a maximum
					// It is timed from the active command

					// At the moment we break out as soon as we see a refresh available
					// We don't have to do this, we could have a more complex system for better performance
					// N.B. This means we currenly break for refreshes long before t_ras_max is a problem

					if(close_row)
					begin
						// Only permit the close if we have been open for at least the minimum time
						if(t_ras_min_ctr == 0)
						begin
							cmd <= CMD_PRECHARGE;
							ram_a[10] <= 0; // Only precharge this bank, not all. Although it doesn't matter in current configuration
							state <= SM_IDLE;
							// T_RP is the minimum time from precharging a bank to activating a row in the SAME bank
							// If we used a different bank, we wouldn't have to wait here, but we cant guarantee this
							timeout_ctr <= T_RP;
						end
					end else if (cmd_i_valid) begin
						// N.B. we have already checked that the row and bank is the open row and bank
						// We are good to go on issuing a transaction
						if(cmd_i_we)
						begin
							cmd <= CMD_WRITE;
						end else begin
							cmd <= CMD_READ;
						end
						ram_a[10] <= 0; // Don't auto precharge
						ram_a[COL_ADDR_BITS-1:0] <= cmd_i_addr_col;
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

// We are able to do a refresh in the idle state, so do one if there is one pending
assign refresh_request_ready = (state == SM_IDLE) && (timeout_ctr == 0);

endmodule
