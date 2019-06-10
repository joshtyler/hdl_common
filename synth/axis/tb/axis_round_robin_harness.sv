// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │                                                                                                          
//  Open Hardware Description License, v. 1.0. If a copy                                                    │                                                                                                          
//  of the OHDL was not distributed with this file, You                                                     │                                                                                                          
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

// Send on AXI stream slave input out to many masters

module axis_round_robin_harness
#(
	parameter AXIS_BYTES = 1
) (
	input clk,
	input sresetn,

	// Input
	output                     axis_i_tready,
	input                      axis_i_tvalid,
	input                      axis_i_tlast,
	input [(AXIS_BYTES*8)-1:0] axis_i_tdata,

	// Output 1
	input                       axis_o1_tready,
	output                      axis_o1_tvalid,
	output                      axis_o1_tlast,
	output [(AXIS_BYTES*8)-1:0] axis_o1_tdata,

	// Output 2
	input                       axis_o2_tready,
	output                      axis_o2_tvalid,
	output                      axis_o2_tlast,
	output [(AXIS_BYTES*8)-1:0] axis_o2_tdata
);

axis_round_robin
	#(
		.AXIS_BYTES(AXIS_BYTES),
		.NUM_SLAVE_STREAMS(2)
	) uut (
		.clk(clk),
		.sresetn(sresetn),

		.axis_i_tready(axis_i_tready),
		.axis_i_tvalid(axis_i_tvalid),
		.axis_i_tlast (axis_i_tlast),
		.axis_i_tdata (axis_i_tdata),

		.axis_o_tready({axis_o2_tready, axis_o1_tready}),
		.axis_o_tvalid({axis_o2_tvalid, axis_o1_tvalid}),
		.axis_o_tlast ({axis_o2_tlast,  axis_o1_tlast}),
		.axis_o_tdata ({axis_o2_tdata,  axis_o1_tdata})
	);

endmodule
