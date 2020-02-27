module serial_wb_master
#(
	parameter BYTES = 1,
	parameter ADDR_BITS = 8,
	localparam  SEL_WIDTH = 1
) (
	input logic clk,
	input logic sresetn,

	// Serial input to block
	output logic                        axis_i_tready,
	input  logic                        axis_i_tvalid,
	input  logic                        axis_i_tlast,
	input  logic [(BYTES*8)-1:0] axis_i_tdata,

	// Serial output from block
	input  logic                        axis_o_tready,
	output logic                        axis_o_tvalid,
	output logic                        axis_o_tlast,
	output logic [(BYTES*8)-1:0] axis_o_tdata,

	// Wishbone master bus
	output logic [ADDR_BITS-1:0] m_wb_addr   ,
	output logic [BYTES*8-1:0]   m_wb_dat_m2s,
	input  logic [BYTES*8-1:0]   m_wb_dat_s2m,
	output logic                 m_wb_we     ,
	output logic [SEL_WIDTH-1:0] m_wb_sel    ,
	output logic                 m_wb_stb    ,
	output logic                 m_wb_cyc    ,
	input  logic                 m_wb_ack    ,
	input  logic                 m_wb_stall  ,

	output logic [1:0] state
);

//logic [1:0] state;
localparam SM_GET_OP = 2'b00;
localparam SM_GET_ADDR = 2'b01;
localparam SM_BUS_ACTIVE = 2'b10;
localparam SM_LAST_ACK = 2'b11;

// At the moment the state machine is naive and assumes 1 byte data and 1 byte address
always @(posedge clk)
begin
	if(!sresetn)
	begin
		state <= SM_GET_OP;
	end else begin
		case(state)
			SM_GET_OP: begin
				if(axis_i_tready && axis_i_tvalid)
				begin
					m_wb_we <= axis_i_tdata[0];
					state <= SM_GET_ADDR;
				end
			end
			SM_GET_ADDR: begin
				if(axis_i_tready && axis_i_tvalid)
				begin
					m_wb_addr <= axis_i_tdata;
					state <= SM_BUS_ACTIVE;
				end
			end
			SM_BUS_ACTIVE: begin
				if(m_wb_stb && !m_wb_stall)
				begin
					//m_wb_addr <= m_wb_addr + 1;
					state <= SM_LAST_ACK;
				end
			end
			SM_LAST_ACK: begin
				if(m_wb_ack) begin
					state <= SM_GET_OP;
				end
			end
		endcase
	end
end

logic out_reg_ready;

always_comb
begin
	m_wb_stb = 0;
	if (state == SM_BUS_ACTIVE)
	begin
		if(m_wb_we)
		begin
			m_wb_stb = axis_i_tvalid;
		end else begin
			// This only works because we are doing one txn at a time
			// The logic breaks if have more than one in flight transaction
			// At this point we need a FIFO
			m_wb_stb = out_reg_ready;
		end
	end
end

always_comb
begin
	axis_i_tready = 0;
	if ((state == SM_GET_OP) || (state == SM_GET_ADDR))
	begin
		axis_i_tready = 1;
	end else if (state == SM_BUS_ACTIVE) begin
		if(m_wb_we)
		begin
			axis_i_tready = ! m_wb_stall;
		end
	end
end

assign m_wb_dat_m2s = axis_i_tdata;

assign m_wb_cyc = (state == SM_BUS_ACTIVE) || (state == SM_LAST_ACK);


axis_register
#(
	.AXIS_BYTES(BYTES)
) m_wb_to_axis_reg (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(out_reg_ready),
	.axis_i_tvalid(m_wb_ack && (!m_wb_we)),
	.axis_i_tlast(1), // Only valid because we only support a burst of one at the moment
	.axis_i_tdata(m_wb_dat_s2m),

	.axis_o_tready(axis_o_tready),
	.axis_o_tvalid(axis_o_tvalid),
	.axis_o_tlast(axis_o_tlast),
	.axis_o_tdata(axis_o_tdata)
);

endmodule
