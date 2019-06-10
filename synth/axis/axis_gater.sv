// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │                                                                                                          
//  Open Hardware Description License, v. 1.0. If a copy                                                    │                                                                                                          
//  of the OHDL was not distributed with this file, You                                                     │                                                                                                          
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

// Block an axi stream

module axis_gater
#(
	parameter AXIS_BYTES = 1,
	// If 0 this is a combinatorial block.
	// If 1, asserting c_pass will let 1 packet through
	parameter PACKET_WISE = 0
) (
	input clk,
	input sresetn,

	output c_ready,
	input c_pass,

	// Input
	output                     axis_i_tready,
	input                      axis_i_tvalid,
	input                      axis_i_tlast,
	input [(AXIS_BYTES*8)-1:0] axis_i_tdata,

	// Output
	input                       axis_o_tready,
	output                      axis_o_tvalid,
	output                      axis_o_tlast,
	output [(AXIS_BYTES*8)-1:0] axis_o_tdata
);

logic pass;

generate

	if (PACKET_WISE) begin
		logic state;
		localparam SM_WAIT = 0;
		localparam SM_PASS = 1;

		assign c_ready = (state == SM_WAIT);
		assign pass = (state == SM_PASS);

		always @(posedge clk)
			if(sresetn == 0) begin
				state <= SM_WAIT;
			end else begin
				case(state)
					SM_WAIT: if(c_pass) state <= SM_PASS;
					SM_PASS: if(axis_o_tready && axis_o_tvalid && axis_o_tlast) state <= SM_WAIT;
				endcase;
			end
	end else begin
		assign c_ready = 1;
		assign pass = c_pass;
	end
endgenerate

assign axis_i_tready = pass? axis_o_tready : 0;
assign axis_o_tvalid = pass? axis_i_tvalid : 0;
assign axis_o_tlast = axis_i_tlast;
assign axis_o_tdata = axis_i_tdata;
endmodule
