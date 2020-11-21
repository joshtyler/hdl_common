// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │
//  Open Hardware Description License, v. 1.0. If a copy                                                    │
//  of the OHDL was not distributed with this file, You                                                     │
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

// Send one packet to the first output
// The next packet to the second output
// etc

`include "axis/axis.h"

module axis_round_robin
#(
	parameter AXIS_BYTES = 1,
	parameter AXIS_USER_BITS = 1,
	parameter NUM_SLAVE_STREAMS = 1
) (
	input clk,
	input sresetn,

	`S_AXIS_PORT(axis_i, AXIS_BYTES, AXIS_USER_BITS),
	`M_AXIS_MULTI_PORT(axis_o, NUM_SLAVE_STREAMS, AXIS_BYTES, AXIS_USER_BITS)
);
	// Avoid null vector
	localparam AXIS_TDEST_BITS = NUM_SLAVE_STREAMS == 1? 1 : $clog2(NUM_SLAVE_STREAMS);
	logic [AXIS_TDEST_BITS-1:0] axis_i_tdest;

	always @(posedge clk) begin
		if (sresetn == 0) begin
			axis_i_tdest <= 0;
		end else begin
			if (axis_i_tready && axis_i_tvalid && axis_i_tlast)
			begin
				axis_i_tdest <= axis_i_tdest + 1;
			end
		end
	end

	axis_switch
	#(
		.AXIS_BYTES(AXIS_BYTES),
		.AXIS_USER_BITS(AXIS_USER_BITS),
		.NUM_SLAVE_STREAMS(NUM_SLAVE_STREAMS)
	) switch (
		.clk(clk),
		.sresetn(sresetn),

		`AXIS_MAP(axis_i, axis_i),
		.axis_i_tdest (axis_i_tdest),

		`AXIS_MAP(axis_o, axis_o)
	);

endmodule
