// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │
//  Open Hardware Description License, v. 1.0. If a copy                                                    │
//  of the OHDL was not distributed with this file, You                                                     │
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

// Send on AXI stream slave input out to many masters

module axis_broadcaster
#(
	parameter AXIS_BYTES = 1,
	parameter AXIS_USER_BITS = 1,
	parameter NUM_STREAMS = 2
) (
	input clk,
	input sresetn,

	// Input
	output                     axis_i_tready,
	input                      axis_i_tvalid,
	input                      axis_i_tlast,
	input [(AXIS_BYTES*8)-1:0] axis_i_tdata,
	input [AXIS_USER_BITS-1:0] axis_i_tuser,

	// Output
	input  [NUM_STREAMS-1 : 0]              axis_o_tready,
	output [NUM_STREAMS-1 : 0]              axis_o_tvalid,
	output [NUM_STREAMS-1 : 0]              axis_o_tlast,
	output [NUM_STREAMS*(AXIS_BYTES*8)-1:0] axis_o_tdata
	output [NUM_STREAMS*AXIS_USER_BITS-1:0] axis_o_tuser,
);

reg [NUM_STREAMS-1 : 0] reg_ready;
// Input is ready when all registers are ready
assign axis_i_tready = & reg_ready;

// Data to registers is valid when all registers are ready, and input is valid
// N.B. This breaks AXI stream specification (we rely on the slave asserting ready before valid)
// This is okay because we have the register in the path
logic reg_valid;
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
		.axis_i_tuser (axis_i_tuser),

		.axis_o_tready(axis_o_tready[i]),
		.axis_o_tvalid(axis_o_tvalid[i]),
		.axis_o_tlast (axis_o_tlast[i]),
		.axis_o_tdata (axis_o_tdata[(1+i)*(AXIS_BYTES*8)-1 -: (AXIS_BYTES*8)])
		.axis_o_tuser (axis_o_tuser[(1+i)*AXIS_USER_BITS-1 -: AXIS_USER_BITS])
	);
end

endmodule
