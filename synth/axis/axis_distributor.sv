// Send on AXI stream slave input out to many masters

module axis_distributor
#(
	parameter AXIS_BYTES = 1,
	parameter NUM_STREAMS = 1
) (
	input clk,
	input sresetn,

	// Input
	output                     axis_i_tready,
	input                      axis_i_tvalid,
	input                      axis_i_tlast,
	input [(AXIS_BYTES*8)-1:0] axis_i_tdata,

	// Output
	input  [NUM_STREAMS-1 : 0]              axis_o_tready,
	output [NUM_STREAMS-1 : 0]              axis_o_tvalid,
	output [NUM_STREAMS-1 : 0]              axis_o_tlast,
	output [NUM_STREAMS*(AXIS_BYTES*8)-1:0] axis_o_tdata
);

reg [NUM_STREAMS-1 : 0] reg_ready;
// Input is ready when all registers are ready
assign axis_i_tready = & reg_ready;

// Data to registers is valid when all registers are ready, and input is valid
// N.B. This breaks AXI stream specification (we rely on the slave asserting ready before valid)
// This is okay because we have the register in the path
reg reg_valid;
assign reg_valid = axis_i_tready && axis_i_tvalid;

// Replicate all other input signals on the output
genvar i;
for(i=0; i< NUM_STREAMS; i++)
begin
	axis_register
	#(
		.AXIS_BYTES(AXIS_BYTES)
	) register (
		.clk(clk),
		.sresetn(sresetn),

		.axis_i_tready(reg_ready[i]),
		.axis_i_tvalid(reg_valid),
		.axis_i_tlast (axis_i_tlast),
		.axis_i_tdata (axis_i_tdata),

		.axis_o_tready(axis_o_tready[i]),
		.axis_o_tvalid(axis_o_tvalid[i]),
		.axis_o_tlast (axis_o_tlast[i]),
		.axis_o_tdata (axis_o_tdata[(1+i)*(AXIS_BYTES*8)-1 -: (AXIS_BYTES*8)])
	);
end

endmodule
