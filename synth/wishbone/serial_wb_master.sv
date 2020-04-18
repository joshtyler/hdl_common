module serial_wb_master
#(
	parameter BYTES = 1,
	parameter ADDR_BITS = 8,
	parameter  SEL_WIDTH = 1
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
	input  logic                 m_wb_stall
);

logic [2:0] state;
localparam SM_GET_OP     = 3'b000;
localparam SM_GET_ADDR   = 3'b001;
localparam SM_GET_COUNT  = 3'b010;
localparam SM_BUS_ACTIVE = 3'b011;
localparam SM_LAST_ACK   = 3'b100;

logic [7:0] count, outstanding_ctr;

// At the moment the state machine is naive and assumes 1 byte data and 1 byte address
always @(posedge clk)
begin
	if(!sresetn)
	begin
		state <= SM_GET_OP;
		outstanding_ctr <= 0;
	end else begin
		if(m_wb_ack && !(m_wb_stb && !m_wb_stall))
		begin
			outstanding_ctr <= outstanding_ctr-1;
		end else if(!m_wb_ack && (m_wb_stb && !m_wb_stall)) begin
			outstanding_ctr <= outstanding_ctr+1;
		end


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
					state <= SM_GET_COUNT;
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
				if(m_wb_stb && !m_wb_stall)
				begin
					//-m_wb_addr <= m_wb_addr + 1;
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


always_comb
begin
	m_wb_stb = 0;
	if (state == SM_BUS_ACTIVE)
	begin
		if(m_wb_we)
		begin
			m_wb_stb = axis_i_tvalid;
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
			axis_i_tready = ! m_wb_stall;
		end
	end
end

assign m_wb_dat_m2s = axis_i_tdata;

assign m_wb_cyc = (state == SM_BUS_ACTIVE) || (state == SM_LAST_ACK);

axis_fifo
#(
	.AXIS_BYTES(1),
	.DEPTH(255)
) fifo_inst (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(), // It will never fill up, because the state machine only issues transactions it can store
	.axis_i_tvalid(m_wb_ack && (!m_wb_we)),
	.axis_i_tlast(1'b1), // Currently ignored
	.axis_i_tdata(m_wb_dat_s2m),

	// Output
	.axis_o_tready(axis_o_tready),
	.axis_o_tvalid(axis_o_tvalid),
	.axis_o_tlast(axis_o_tlast),
	.axis_o_tdata(axis_o_tdata)
);

endmodule
