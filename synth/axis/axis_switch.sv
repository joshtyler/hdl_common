// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │
//  Open Hardware Description License, v. 1.0. If a copy                                                    │
//  of the OHDL was not distributed with this file, You                                                     │
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

// Send one slave to many masters based upon tdest
// Support for multiple slaves may be added later

`include "axis.h"

module axis_switch
#(
	parameter AXIS_BYTES = 1,
	parameter AXIS_USER_BITS = 1,
	parameter NUM_SLAVE_STREAMS = 1,
	localparam AXIS_DEST_BITS = (NUM_SLAVE_STREAMS == 1? 1 : $clog2(NUM_SLAVE_STREAMS))
) (
	input clk,
	input sresetn,

	`S_AXIS_PORT(axis_i, AXIS_BYTES, AXIS_USER_BITS),
	input logic [AXIS_DEST_BITS-1:0] axis_i_tdest,

	`M_AXIS_MULTI_PORT(axis_o, NUM_SLAVE_STREAMS, AXIS_BYTES, AXIS_USER_BITS)
);

assign axis_i_tready = axis_o_tready[axis_i_tdest];

genvar i;
for(i=0; i < NUM_SLAVE_STREAMS; i=i+1)
begin
	assign axis_o_tlast[i] = axis_i_tlast;
	assign axis_o_tdata[((i+1)*AXIS_BYTES*8)-1 -: AXIS_BYTES*8] = axis_i_tdata;
	assign axis_o_tuser[((i+1)*AXIS_USER_BITS)-1 -: AXIS_USER_BITS] = axis_i_tuser;

	always @(*)
		if(axis_i_tdest == i)
		begin
			axis_o_tvalid[i] = axis_i_tvalid;
		end else begin
			axis_o_tvalid[i] = 0;
		end
end

endmodule
