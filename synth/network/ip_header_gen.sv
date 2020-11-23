// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │
//  Open Hardware Description License, v. 1.0. If a copy                                                    │
//  of the OHDL was not distributed with this file, You                                                     │
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

// Create an IPv4 header

// Note this is a basic implementation:
	// IHL is fixed, therefore options is not supported
	// Identification is not supported
	// Fragmentation is not supported

// Structure:
/*

{oct0:1, length, oct4:8, protocol} --> joiner --> broadcaster --------------------------> joiner ---> output
                                                         |                                 |   |
                                                          --> joiner --> checksum --> fifo --  |
                                                                |                              |
                                                       ip --> switch---------------------------
*/

`include "axis/axis.h"

module ip_header_gen
#(
	localparam integer IP_ADDR_OCTETS = 4,
	localparam integer PROTOCOL_OCTETS = 1
) (
	input clk,
	input sresetn,

	// These inputs are set before sending any data
	// They should remain constant for a whole packet
	// It is likely that they will be set to constants
	input [(IP_ADDR_OCTETS*8)-1:0] src_ip,
	input [(IP_ADDR_OCTETS*8)-1:0] dest_ip,
	input [(PROTOCOL_OCTETS*8)-1:0] protocol,

	// The length input has an AXI stream interface
	// This allows it to easily be calculated and passed to the block on the fly
	`S_AXIS_PORT_NO_USER(payload_length_axis, 2),

	`M_AXIS_PORT_NO_USER(axis_o, 1)
);

// Octets 0:1, and 4:8 are constant in this implementation
// Therefore we can get away with hardcoding it
// See https://en.wikipedia.org/wiki/IPv4#Header to decode
localparam OCTETS_0_TO_1 = 16'h4500;
// Total length goes here
//localparam OCTETS_4_TO_8 = 40'h00004000FF;
localparam OCTETS_4_TO_8 = 40'hA86C400040; //Add identification to match test packet
// Protocol goes here
// Checksum goes here
// Source IP goes here
// Destination IP goes here

`AXIS_INST_NO_USER(octets0to1_axis,1);
`AXIS_INST_NO_USER(len_byte_wide_axis,1);
`AXIS_INST_NO_USER(octets4to8_axis,1);
`AXIS_INST_NO_USER(input_joined_axis,1);
`AXIS_INST_NO_USER(main_out_axis,1);
`AXIS_INST_NO_USER(main_checksum_axis,1);
`AXIS_INST_NO_USER(ip_axis,1);
`AXIS_INST_NO_USER(ip_axis_checksum,1);
`AXIS_INST_NO_USER(ip_axis_out,1);
`AXIS_INST_NO_USER(checksum_in_axis,1);
`AXIS_INST_NO_USER(checksum_out_axis,1);
`AXIS_INST_NO_USER(checksum_fifoed_axis,1);
`AXIS_INST_NO_USER(ip_checksum_axis,1);
`AXIS_INST_NO_USER(axis_ip,1);
`AXIS_INST_NO_USER(ip_out_axis,1);

// Vector to axis for input
vector_to_axis
#(
	.VEC_BYTES(2),
	.AXIS_BYTES(1),
	.MSB_FIRST(1)
) oct_0_to_1_axis (
	.clk(clk),
	.sresetn(sresetn),

	.vec(OCTETS_0_TO_1),

	`AXIS_MAP_NO_USER(axis, octets0to1_axis)
);

vector_to_axis
#(
	.VEC_BYTES(5),
	.AXIS_BYTES(1),
	.MSB_FIRST(1)
) oct_4_to_8_axis (
	.clk(clk),
	.sresetn(sresetn),

	.vec(OCTETS_4_TO_8),

	`AXIS_MAP_NO_USER(axis, octets4to8_axis)
);

// Generate length axis. This includes the header, so we need to add that on to the payload
// Our header doesn't have options, so is a fixed 20 bytes
localparam [15:0] IP_HEADER_LEN = 20;

axis_width_converter
#(
	.AXIS_I_BYTES(2),
	.AXIS_O_BYTES(1),
	.MSB_FIRST(1)
) conv_length (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(payload_length_axis_tready),
	.axis_i_tvalid(payload_length_axis_tvalid),
	.axis_i_tlast (payload_length_axis_tlast),
	.axis_i_tdata (payload_length_axis_tdata + IP_HEADER_LEN),

	`AXIS_MAP_NO_USER(axis_o, len_byte_wide_axis)
);

// Join inputs together

// Dummy AXI stream for protocol
`AXIS_INST_NO_USER(prot_axis, PROTOCOL_OCTETS);
// prot_axis_tready is ignored
assign prot_axis_tvalid = 1'b1;
assign prot_axis_tlast = 1'b1;
assign prot_axis_tdata = protocol;

axis_joiner
#(
	.AXIS_BYTES(1),
	.NUM_STREAMS(4)
) input_joiner (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP_4_NULL_USER(axis_i, prot_axis, octets4to8_axis, len_byte_wide_axis, octets0to1_axis),
	`AXIS_MAP_IGNORE_USER(axis_o, input_joined_axis)
);

// Distribute first past of message to checksum and output
axis_broadcaster
#(
	.AXIS_BYTES(1),
	.NUM_STREAMS(2)
) in_bcaster (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP_NULL_USER(axis_i, input_joined_axis),
	`AXIS_MAP_2_IGNORE_USER(axis_o, main_out_axis, main_checksum_axis)
);


axis_joiner
#(
	.AXIS_BYTES(1),
	.NUM_STREAMS(2)
) checksum_joiner (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP_2_NULL_USER(axis_i, main_checksum_axis, ip_checksum_axis),
	`AXIS_MAP_IGNORE_USER(axis_o, checksum_in_axis)
);

`AXIS_INST_NO_USER(checksum_in_2b,2);

axis_width_converter
#(
	.AXIS_I_BYTES(1),
	.AXIS_O_BYTES(2),
	.MSB_FIRST(1)
) checksum_in_conv (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP_NO_USER(axis_i, checksum_in_axis),
	`AXIS_MAP_NO_USER(axis_o, checksum_in_2b)
);

logic csum_2b_tready;
logic csum_2b_tvalid;
logic [15:0] csum_2b;

udp_checksum
#(
	.AXIS_BYTES(2)
) checksum (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP_NO_USER(axis_i, checksum_in_2b),

	.axis_o_tready(csum_2b_tready),
	.axis_o_tvalid(csum_2b_tvalid),
	.axis_o_csum (csum_2b)
);
axis_width_converter
#(
	.AXIS_I_BYTES(2),
	.AXIS_O_BYTES(1),
	.MSB_FIRST(1)
) checksum_out_conv (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(csum_2b_tready),
	.axis_i_tvalid(csum_2b_tvalid),
	.axis_i_tlast (1'b1),
	.axis_i_tdata (csum_2b),

	`AXIS_MAP_NO_USER(axis_o, checksum_out_axis)
);

axis_fifo
#(
	.AXIS_BYTES(1)
) checksum_fifo (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP_NULL_USER(axis_i, checksum_out_axis),
	`AXIS_MAP_IGNORE_USER(axis_o, checksum_fifoed_axis)
);

vector_to_axis
#(
	.VEC_BYTES(2*IP_ADDR_OCTETS),
	.AXIS_BYTES(1),
	.MSB_FIRST(1)
) ip_vec (
	.clk(clk),
	.sresetn(sresetn),

	.vec({src_ip, dest_ip}),

	`AXIS_MAP_NO_USER(axis, axis_ip)
);

axis_round_robin
#(
	.AXIS_BYTES(1),
	.NUM_SLAVE_STREAMS(2)
) ip_round_robin (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP_NULL_USER(axis_i, axis_ip),

	`AXIS_MAP_2_IGNORE_USER(axis_o, ip_out_axis, ip_checksum_axis)
);

axis_joiner
#(
	.AXIS_BYTES(1),
	.NUM_STREAMS(3)
) output_joiner (
	.clk(clk),
	.sresetn(sresetn),
	`AXIS_MAP_3_NULL_USER(axis_i, ip_out_axis, checksum_fifoed_axis, main_out_axis),
	`AXIS_MAP_IGNORE_USER(axis_o, axis_o)
);

endmodule
