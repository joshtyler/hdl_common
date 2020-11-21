// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │
//  Open Hardware Description License, v. 1.0. If a copy                                                    │
//  of the OHDL was not distributed with this file, You                                                     │
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

`include "axis/axis.h"

module axis_broadcaster_harness
#(
	parameter AXIS_BYTES = 1
) (
	input clk,
	input sresetn,

	`S_AXIS_PORT_NO_USER(axis_i, AXIS_BYTES),
	`M_AXIS_PORT_NO_USER(axis_o1, AXIS_BYTES),
	`M_AXIS_PORT_NO_USER(axis_o2, AXIS_BYTES)
);

axis_broadcaster
	#(
		.AXIS_BYTES(AXIS_BYTES),
		.NUM_STREAMS(2)
	) uut (
		.clk(clk),
		.sresetn(sresetn),
		`AXIS_MAP_NULL_USER(axis_i, axis_i),
		`AXIS_MAP_2_IGNORE_USER(axis_o, axis_o1, axis_o2)
	);

endmodule
