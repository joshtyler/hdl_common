// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │
//  Open Hardware Description License, v. 1.0. If a copy                                                    │
//  of the OHDL was not distributed with this file, You                                                     │
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

// Enforce a gap between packets

`include "axis/axis.h"

module axis_spacer
#(
	parameter AXIS_BYTES = 1,
	parameter AXIS_USER_BITS = 1,
	parameter GAP_CYCLES = 1
) (
	input clk,
	input sresetn,

	`S_AXIS_PORT(axis_i, AXIS_BYTES, AXIS_USER_BITS),
	`M_AXIS_PORT(axis_o, AXIS_BYTES, AXIS_USER_BITS)
);
localparam integer CTR_WIDTH = GAP_CYCLES == 1? 1 : $clog2(GAP_CYCLES);
/* verilator lint_off WIDTH */
localparam [CTR_WIDTH-1:0] CTR_MAX = GAP_CYCLES -1;
/* verilator lint_on WIDTH */
logic [CTR_WIDTH-1:0] ctr;

logic [0:0] state;
localparam PASS = 1'b0;
localparam HALT = 1'b1;

assign axis_i_tready = (state == PASS)? axis_o_tready : 0;
assign axis_o_tvalid = (state == PASS)? axis_i_tvalid : 0;
assign axis_o_tlast = axis_i_tlast;
assign axis_o_tkeep = axis_i_tkeep;
assign axis_o_tdata = axis_i_tdata;
assign axis_o_tuser = axis_i_tuser;


always @(posedge clk)
	if (sresetn == 0)
	begin
		state <= PASS;
	end else begin
		case(state)
			PASS: begin
				if (axis_i_tready && axis_i_tvalid && axis_i_tlast) begin
					ctr <= 0;
					state <= HALT;
				end
			end
			HALT: begin
				if (ctr == CTR_MAX) begin
					state <= PASS;
				end
				ctr <= ctr + 1;
			end
		endcase
	end

endmodule
