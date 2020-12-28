// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │
//  Open Hardware Description License, v. 1.0. If a copy                                                    │
//  of the OHDL was not distributed with this file, You                                                     │
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

// Create an IPv4 header
// Process four bytes wide becase this makes most sense

`include "axis/axis.h"
`include "axis/utility.h"

module ip_header_gen
(
	input clk,
	input sresetn,

	output logic        axis_i_tready,
	input  logic        axis_i_tvalid,
	input  logic [31:0] axis_i_src_ip,
	input  logic [31:0] axis_i_dst_ip,
	input  logic [15:0] axis_i_length_bytes, // Of payload
	input  logic [7:0]  axis_i_protocol,

	`M_AXIS_PORT_NO_USER(axis_o, 4)
);


// N.B. We don't use a broadcaster on the input because we know we will only accept the transaction once the output is gone
// The flow control works (the output won't go until the checksum is valid)
// This saves resource, which would otherwise be spent for no real benefit
// Just be slightly mindful of this before messing with the flow control in this block

`BYTE_SWAP_FUNCTION(byte_swap_2, 2);
`BYTE_SWAP_FUNCTION(byte_swap_4, 4);

logic [31:0] word_0;
logic [31:0] word_1;
logic [15:0] word_2_lower;
logic [31:0] word_3;
logic [31:0] word_4;
assign word_0       = { byte_swap_2(axis_i_length_bytes+5*4), 8'h00, 4'h4, 4'h5};
assign word_1       = { byte_swap_2({3'b010, 13'h000}), 16'h0000}; // Don't fragment
assign word_2_lower = { axis_i_protocol, 8'hFF};
assign word_3 = byte_swap_4(axis_i_src_ip);
assign word_4 = byte_swap_4(axis_i_dst_ip);


// Feed the checksum the source and destination IP first
// That way if the output stalls we lose fewer cycles waiting for the checksum to be valid
// We could add register stages to the input of the checksum generator to improve throughput

// Byte swap 2 all the numbers because the checksummer expects little endian
`AXIS_INST_NO_USER(axis_checksum_i,4);

logic axis_checksum_o_tready;
logic axis_checksum_o_tvalid;
logic [15:0] axis_checksum_o_tdata_le;

ip_checksum
#(
	.AXIS_BYTES(4)
) checksummer (
	.clk,
	.sresetn,

	`AXIS_MAP_NO_USER(axis_i, axis_checksum_i),

	.axis_o_tready(axis_checksum_o_tready),
	.axis_o_tvalid(axis_checksum_o_tvalid),
	.axis_o_csum(axis_checksum_o_tdata_le)
);

localparam [2:0] CTR_MAX = 3'd4;
localparam [2:0] CTR_CHECKSUM_IDX = 3'd2;
logic [2:0] checksum_ctr, output_ctr;;

always_comb
begin
	axis_checksum_i_tdata = 0;
	case(checksum_ctr)
		0 : axis_checksum_i_tdata = {byte_swap_2(word_3[31:16]), byte_swap_2(word_3[15:0])};
		1 : axis_checksum_i_tdata = {byte_swap_2(word_4[31:16]), byte_swap_2(word_4[15:0])};
		2 : axis_checksum_i_tdata = {byte_swap_2(word_0[31:16]), byte_swap_2(word_0[15:0])};
		3 : axis_checksum_i_tdata = {byte_swap_2(word_1[31:16]), byte_swap_2(word_1[15:0])};
		4 : axis_checksum_i_tdata = {16'h0000, byte_swap_2(word_2_lower)};
	endcase
end

always_ff @(posedge clk)
begin
	if ((!sresetn) || (axis_checksum_i_tready && axis_checksum_i_tvalid && axis_checksum_i_tlast))
	begin
		checksum_ctr <= 0;
	end else begin
		if(axis_checksum_i_tready && axis_checksum_i_tvalid)
		begin
			checksum_ctr <= checksum_ctr + 1;
		end
	end
end

assign axis_checksum_i_tvalid = axis_i_tvalid && checksum_ctr <= CTR_MAX;
assign axis_checksum_i_tlast = (checksum_ctr == CTR_MAX);
assign axis_checksum_o_tready = (output_ctr == CTR_CHECKSUM_IDX);


assign axis_i_tready = axis_o_tready && axis_o_tlast;
// We know that axis_i_tvalid is true when output_ctr == CTR_CHECKSUM_IDX, so can save some LUTs
assign axis_o_tvalid = (output_ctr == CTR_CHECKSUM_IDX)? axis_checksum_o_tvalid : axis_i_tvalid;
assign axis_o_tlast = (output_ctr == CTR_MAX);

always_comb
begin
	axis_o_tdata = 0;
	case(output_ctr)
		0 : axis_o_tdata = word_0;
		1 : axis_o_tdata = word_1;
		2 : axis_o_tdata = {byte_swap_2(axis_checksum_o_tdata_le), word_2_lower};
		3 : axis_o_tdata = word_3;
		4 : axis_o_tdata = word_4;
	endcase
end

always_ff @(posedge clk)
begin
	if ((!sresetn) || (axis_o_tready && axis_o_tvalid && axis_o_tlast))
	begin
		output_ctr <= 0;
	end else begin
		if(axis_o_tready && axis_o_tvalid)
		begin
			output_ctr <= output_ctr + 1;
		end
	end
end
endmodule
