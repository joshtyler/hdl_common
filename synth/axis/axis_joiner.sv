// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │
//  Open Hardware Description License, v. 1.0. If a copy                                                    │
//  of the OHDL was not distributed with this file, You                                                     │
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

// Join together multiple AXIS streams
// I.e. output a packet from stream 1, then stream 2 etc.

`include "axis/axis.h"

module axis_joiner
#(
	parameter AXIS_BYTES = 1,
	parameter AXIS_USER_BITS = 1,
	parameter NUM_STREAMS = 1
) (
	input clk,
	input sresetn,

	`S_AXIS_MULTI_PORT(axis_i, NUM_STREAMS, AXIS_BYTES, AXIS_USER_BITS),

	`M_AXIS_PORT(axis_o, AXIS_BYTES, AXIS_USER_BITS)
);

localparam integer CTR_WIDTH = NUM_STREAMS == 1? 1 : $clog2(NUM_STREAMS);
/* verilator lint_off WIDTH */
localparam CTR_MAX = NUM_STREAMS-1;


reg [CTR_WIDTH-1:0] ctr;

always @(posedge clk)
begin
	if (sresetn == 0)
	begin
		ctr <= 0;
	end else begin
		if (axis_o_tready && axis_o_tvalid && axis_i_tlast[ctr])
		begin
			if (ctr == CTR_MAX)
			begin
				ctr <= 0;
			end else begin
				ctr <= ctr + 1;
			end
		end
	end
end

genvar i;
generate
	for(i=0; i< NUM_STREAMS; i++)
			assign axis_i_tready[i] = (i == ctr)? axis_o_tready : 0;
endgenerate

assign axis_o_tvalid = axis_i_tvalid[ctr];
assign axis_o_tlast = (ctr == CTR_MAX)? axis_i_tlast[ctr] : 0; //Only output tlast on last packet
assign axis_o_tkeep = axis_i_tkeep[(1+ctr)*(AXIS_BYTES)-1 -: AXIS_BYTES];
assign axis_o_tdata = axis_i_tdata[(1+ctr)*(AXIS_BYTES*8)-1 -: AXIS_BYTES*8];
assign axis_o_tuser = axis_i_tuser[(1+ctr)*(AXIS_USER_BITS)-1 -: AXIS_USER_BITS];
/* verilator lint_on WIDTH */

endmodule
