module serial_wb_master
#(
	parameter BYTES = 1, // Wishbone only, stream is fixed as byte wide
	parameter ADDR_BITS = 8,
	parameter SEL_WIDTH = 1 // Anything other than 1 is currently not implemented
) (
	input logic clk,
	input logic sresetn,

	// Serial input to block
	output logic                 axis_i_tready,
	input  logic                 axis_i_tvalid,
	input  logic                 axis_i_tlast,
	input  logic [7:0]           axis_i_tdata,

	// Serial output from block
	input  logic                 axis_o_tready,
	output logic                 axis_o_tvalid,
	output logic                 axis_o_tlast,
	output logic [7:0]           axis_o_tdata,

	// Wishbone master bus
	output logic [ADDR_BITS-1:0] m_wb_addr   ,
	output logic [BYTES*8-1:0]   m_wb_dat_m2s,
	input  logic [BYTES*8-1:0]   m_wb_dat_s2m,
	output logic                 m_wb_we     ,
	output logic [SEL_WIDTH-1:0] m_wb_sel    ,
	output logic                 m_wb_stb    ,
	output logic                 m_wb_cyc    ,
	input  logic                 m_wb_ack    ,
	input  logic                 m_wb_stall
);

logic [2:0] state;
localparam SM_GET_OP     = 3'b000;
localparam SM_GET_ADDR   = 3'b001;
localparam SM_GET_COUNT  = 3'b010;
localparam SM_BUS_ACTIVE = 3'b011;
localparam SM_LAST_ACK   = 3'b100;

logic [7:0] count, outstanding_ctr;

logic auto_increment_address;

logic beat_sent;
assign beat_sent = (m_wb_stb && !m_wb_stall);

/* verilator lint_off REALCVT */
localparam integer ADDRESS_BYTES = $ceil(ADDR_BITS/(8.0));
/* verilator lint_on REALCVT */
localparam integer ADDR_CTR_WIDTH = ADDRESS_BYTES == 1? 1 : $clog2(ADDRESS_BYTES); // Needed because a null vector is illegal in verilog
logic [ADDR_CTR_WIDTH-1:0] addr_ctr;

// Having our address signal be a multiple of the stream width makes assignment easier
logic[ADDRESS_BYTES*8-1:0] addr;
assign m_wb_addr = addr[ADDR_BITS-1:0];

assign m_wb_sel = '1;

always_ff @(posedge clk)
begin
	if(!sresetn)
	begin
		state <= SM_GET_OP;
		outstanding_ctr <= 0;
	end else begin
		if(m_wb_ack && !beat_sent)
		begin
			outstanding_ctr <= outstanding_ctr-1;
		end else if(!m_wb_ack && beat_sent) begin
			outstanding_ctr <= outstanding_ctr+1;
		end

		// Don't increment the address on the last beat to ensure we don't burst passed the end of a component
		if(beat_sent && auto_increment_address && (count != 0))
		begin
			addr <= addr + 1;
		end

		case(state)
			SM_GET_OP: begin
				if(axis_i_tready && axis_i_tvalid)
				begin
					auto_increment_address <= axis_i_tdata[1];
					m_wb_we <= axis_i_tdata[0];
					/* verilator lint_off WIDTH */
					addr_ctr <= ADDRESS_BYTES-1;
					/* verilator lint_on WIDTH */
					state <= SM_GET_ADDR;
				end
			end
			SM_GET_ADDR: begin
				if(axis_i_tready && axis_i_tvalid)
				begin
					addr[addr_ctr*8 +: 8] <= axis_i_tdata; // big endian
					addr_ctr <= addr_ctr-1;
					if(addr_ctr == 0)
					begin
						state <= SM_GET_COUNT;
					end
				end
			end
			SM_GET_COUNT: begin
				if(axis_i_tready && axis_i_tvalid)
				begin
					count <= axis_i_tdata-1; // -1 because we will always do the first in SM_BUS_ACTIVE
					state <= SM_BUS_ACTIVE;
				end
			end

			SM_BUS_ACTIVE: begin
				if(beat_sent)
				begin
					count <= count-1;
					if(count == 0)
					begin
						state <= SM_LAST_ACK;
					end
				end
			end
			SM_LAST_ACK: begin
				if(outstanding_ctr == 0 && !axis_o_tvalid) begin
					state <= SM_GET_OP;
				end
			end
			default : state <= SM_GET_OP;
		endcase
	end
end

logic axis_widen_i_tready;
logic axis_widen_i_tvalid;

logic axis_widen_o_tready;
logic axis_widen_o_tvalid;

axis_width_converter
#(
	.AXIS_I_BYTES(1),
	.AXIS_O_BYTES(BYTES),
	.MSB_FIRST(1) // Big endian
) input_dat_widen (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(axis_widen_i_tready),
	.axis_i_tvalid(axis_widen_i_tvalid),
	.axis_i_tlast(1'b0),
	.axis_i_tdata(axis_i_tdata),

	.axis_o_tready(axis_widen_o_tready),
	.axis_o_tvalid(axis_widen_o_tvalid),
	.axis_o_tlast(),
	.axis_o_tdata(m_wb_dat_m2s)
);

always_comb
begin
	m_wb_stb = 0;
	if (state == SM_BUS_ACTIVE)
	begin
		if(m_wb_we)
		begin
			m_wb_stb = axis_widen_o_tvalid;
		end else begin
			m_wb_stb = 1;
		end
	end
end

always_comb
begin
	axis_i_tready = 0;
	if ((state == SM_GET_OP) || (state == SM_GET_ADDR) || (state == SM_GET_COUNT))
	begin
		axis_i_tready = 1;
	end else if (state == SM_BUS_ACTIVE) begin
		if(m_wb_we)
		begin
			axis_i_tready = axis_widen_i_tready;
		end
	end
end

always_comb
begin
	axis_widen_o_tready = 0;
	axis_widen_i_tvalid = 0;
	if (state == SM_BUS_ACTIVE) begin
		if(m_wb_we)
		begin
			axis_widen_o_tready = ! m_wb_stall;
			axis_widen_i_tvalid = axis_i_tvalid;
		end
	end
end

assign m_wb_cyc = (state == SM_BUS_ACTIVE) || (state == SM_LAST_ACK);

logic axis_o_wide_tready;
logic axis_o_wide_tvalid;
logic [BYTES*8-1:0] axis_o_wide_tdata;

axis_fifo
#(
	.AXIS_BYTES(BYTES),
	.LOG2_DEPTH(8)
) fifo_inst (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(), // It will never fill up, because the state machine only issues transactions it can store
	.axis_i_tvalid(m_wb_ack && (!m_wb_we)),
	.axis_i_tlast(1'b1), // Currently ignored
	.axis_i_tdata(m_wb_dat_s2m),
	.axis_i_tuser(1'b0),

	// Output
	.axis_o_tready(axis_o_wide_tready),
	.axis_o_tvalid(axis_o_wide_tvalid),
	.axis_o_tlast(),
	.axis_o_tdata(axis_o_wide_tdata),
	.axis_o_tuser()
);

axis_width_converter
#(
	.AXIS_I_BYTES(BYTES),
	.AXIS_O_BYTES(1),
	.MSB_FIRST(1) // Big endian
) output_dat_narrow (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(axis_o_wide_tready),
	.axis_i_tvalid(axis_o_wide_tvalid),
	.axis_i_tlast(1'b1),
	.axis_i_tdata(axis_o_wide_tdata),

	.axis_o_tready(axis_o_tready),
	.axis_o_tvalid(axis_o_tvalid),
	.axis_o_tlast(axis_o_tlast),
	.axis_o_tdata(axis_o_tdata)
);

endmodule
