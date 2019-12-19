interface wishbone #(parameter BYTES = 1, parameter ADDR_BITS = 8);
	logic [ADDR_BITS-1 : 0] addr;
	logic [(8*BYTES)-1:0] wdat, rdat;
	logic we, stb, ack, cyc;

	modport master
	(
		output addr,
		output dat_m2s,
		output dat_s2m,
		output we,
		output sel,
		output stb,
		output cyc,
		input  ack,
		input  stall

	);

	modport slave
	(
		input  addr,
		input  dat_m2s,
		input  dat_s2m,
		input  we,
		input  sel,
		input  stb,
		input  cyc,
		output ack,
		output stall
	);
endinterface

module serial_wb_master
#(
	parameter BYTES = 1,
	parameter ADDR_BITS = 8
) (
	input logic clk,
	input logic sresetn,

	// Serial input to block
	output logic                        axis_i_tready,
	input  logic                        axis_i_tvalid,
	input  logic                        axis_i_tlast,
	input  logic [(AXIS_I_BYTES*8)-1:0] axis_i_tdata,

	// Serial output from block
	input  logic                        axis_i_tready,
	output logic                        axis_i_tvalid,
	output logic                        axis_i_tlast,
	output logic [(AXIS_I_BYTES*8)-1:0] axis_i_tdata,

	// Wishbone master bus
	wishbone.master wb
);

logic [1:0] state;
localparam SM_GET_OP = 2'b00;
localparam SM_GET_ADDR = 2'b01;
localparam SM_BUS_ACTIVE =2'b10;
localparam SM_LAST_ACK = 2'b11

// At the moment the state machine is naive and assumes 1 byte data and 1 byte address
always @posedge(clk)
begin
	if(!sresetn)
	begin
		state <= SM_GET_OP;
	end else begin
		case(state)
			SM_GET_OP: begin
				if(axis_i_tready && axis_i_tvalid)
				begin
					wb.we <= axis_i_tdata[0];
					state <= SM_GET_ADDR;
				end
			end
			SM_GET_ADDR: begin
				if(axis_i_tready && axis_i_tvalid)
				begin
					wb.addr <= axis_i_tdata;
					state <= SM_GET_ADDR;
				end
			end
			SM_BUS_ACTIVE: begin
				if(wb.stb && !wb.stall)
				begin
					wb.addr <= wb.addr + 1;
					state <= SM_LAST_ACK;
				end
			SM_LAST_ACK: begin
				if(wb.ack) begin

				end
			end
			end
		endcase
	end
end

endmodule
