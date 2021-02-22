// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │
//  Open Hardware Description License, v. 1.0. If a copy                                                    │
//  of the OHDL was not distributed with this file, You                                                     │
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

// Create a UDP header
`include "axis/axis.h"
`include "axis/utility.h"

module udp_header_gen
#(
	localparam integer PORT_OCTETS = 2,
	localparam integer PROTOCOL_OCTETS = 1
) (
	input clk,
	input sresetn,

	// These inputs are set before sending any data
	// They should remain constant for a whole packet
	// It is likely that they will be set to constants
	input [(PORT_OCTETS*8)-1:0] src_port,
	input [(PORT_OCTETS*8)-1:0] dest_port,

	// The length input has an AXI stream interface
	// This allows it to easily be calculated and passed to the block on the fly
	`S_AXIS_PORT_NO_USER(payload_length_axis, 2),

	`M_AXIS_PORT_NO_USER(axis_o, 1)
);

`AXIS_INST_NO_USER(src_port_axis, 1);
`AXIS_INST_NO_USER(dst_port_axis, 1);
`AXIS_INST_NO_USER(len_byte_wide_axis, 1);
`AXIS_INST_NO_USER(checksum_axis, 1);

`BYTE_SWAP_FUNCTION(byte_swap_2, 2);

vector_to_axis
#(
	.VEC_BYTES(PORT_OCTETS),
	.AXIS_BYTES(1),
	.MSB_FIRST(1)
) src_port_axis (
	.clk(clk),
	.sresetn(sresetn),

	.vec(src_port),

	`AXIS_MAP_NO_USER(axis, src_port_axis)
);

vector_to_axis
#(
	.VEC_BYTES(PORT_OCTETS),
	.AXIS_BYTES(1),
	.MSB_FIRST(1)
) dst_port_axis (
	.clk(clk),
	.sresetn(sresetn),

	.vec(dest_port),

	`AXIS_MAP_NO_USER(axis, dst_port_axis)
);

// We don't actually implement checksum - it is optional for ipv4
vector_to_axis
#(
	.VEC_BYTES(2),
	.AXIS_BYTES(1),
	.MSB_FIRST(1)
) checksum_axis (
	.clk(clk),
	.sresetn(sresetn),

	.vec(16'h0000),

	`AXIS_MAP_NO_USER(axis, checksum_axis)
);

// Generate length axis. This includes the header, so we need to add that on to the payload

localparam [15:0] UDP_HEADER_LEN = 8;
axis_width_converter
#(
	.AXIS_I_BYTES(2),
	.AXIS_O_BYTES(1)
) conv_length (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(payload_length_axis_tready),
	.axis_i_tvalid(payload_length_axis_tvalid),
	.axis_i_tlast (payload_length_axis_tlast),
	.axis_i_tkeep (payload_length_axis_tkeep),
	.axis_i_tdata (byte_swap_2(payload_length_axis_tdata + UDP_HEADER_LEN)),

	`AXIS_MAP_NO_USER(axis_o, len_byte_wide_axis)
);

axis_joiner
#(
	.AXIS_BYTES(1),
	.NUM_STREAMS(4)
) output_joiner (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP_4_NULL_USER(axis_i, checksum_axis, len_byte_wide_axis, dst_port_axis, src_port_axis),

	`AXIS_MAP_IGNORE_USER(axis_o, axis_o)
);

endmodule
