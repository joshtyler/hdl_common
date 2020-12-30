// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │
//  Open Hardware Description License, v. 1.0. If a copy                                                    │
//  of the OHDL was not distributed with this file, You                                                     │
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

// Create an ethernet frame

// AXI Stream in and out

// Format :
	// Preamble
	// Start of frame delimiter
	// MAC Source
	// MAC Destination
	// Ethertype
	// Payload
	// CRC

`include "axis/axis.h"

module eth_framer
#(
	localparam integer PREAMBLE_OCTETS = 7,
	localparam integer SOF_OCTETS = 1,
	localparam integer MAC_OCTETS = 6,
	localparam integer ETHERTYPE_OCTETS = 2
) (
	input clk,
	input sresetn,

	input [(MAC_OCTETS*8)-1:0] src_mac, //Source MAC
	input [(MAC_OCTETS*8)-1:0] dst_mac, //Destination MAC
	input [(ETHERTYPE_OCTETS*8)-1:0] ethertype, //Ethertype MAC

	// Payload input
	`S_AXIS_PORT_NO_USER(payload_axis, 1),

	// Output
	`M_AXIS_PORT_NO_USER(out_axis, 1)
);

`AXIS_INST_NO_USER(preamble_axis, 1);
`AXIS_INST_NO_USER(sof_axis, 1);
`AXIS_INST_NO_USER(dst_mac_axis, 1);
`AXIS_INST_NO_USER(src_mac_axis, 1);
`AXIS_INST_NO_USER(ethertype_axis, 1);
`AXIS_INST_NO_USER(joined_axis, 1);
`AXIS_INST_NO_USER(crc_in_axis, 1);
`AXIS_INST_NO_USER(out_joiner_in_axis, 1);
`AXIS_INST_NO_USER(crc_out_axis, 4);
`AXIS_INST_NO_USER(crc_unpacked_axis, 1);
`AXIS_INST_NO_USER(payload_axis_padded, 1);

// Preamble Stream
vector_to_axis
	#(
		.VEC_BYTES(PREAMBLE_OCTETS),
		.AXIS_BYTES(1),
		.MSB_FIRST(1)
	) preamble_axis_gen (
		.clk(clk),
		.sresetn(sresetn),

		.vec({PREAMBLE_OCTETS{8'h55}}),

		`AXIS_MAP_NO_USER(axis, preamble_axis)
	);

// SoF Stream
vector_to_axis
	#(
		.VEC_BYTES(SOF_OCTETS),
		.AXIS_BYTES(1),
		.MSB_FIRST(1)
	) sof_axis_gen (
		.clk(clk),
		.sresetn(sresetn),

		.vec(8'hD5),

		`AXIS_MAP_NO_USER(axis, sof_axis)
	);

// DEST MAC Stream
vector_to_axis
	#(
		.VEC_BYTES(MAC_OCTETS),
		.AXIS_BYTES(1),
		.MSB_FIRST(1)
	) dst_mac_axis_gen (
		.clk(clk),
		.sresetn(sresetn),

		.vec(dst_mac),

		`AXIS_MAP_NO_USER(axis, dst_mac_axis)
	);

// SRC MAC Stream
vector_to_axis
	#(
		.VEC_BYTES(MAC_OCTETS),
		.AXIS_BYTES(1),
		.MSB_FIRST(1)
	) src_mac_axis_gen (
		.clk(clk),
		.sresetn(sresetn),

		.vec(src_mac),

		`AXIS_MAP_NO_USER(axis, src_mac_axis)
	);

//Ethertype stream
vector_to_axis
	#(
		.VEC_BYTES(ETHERTYPE_OCTETS),
		.AXIS_BYTES(1),
		.MSB_FIRST(1)
	) ethertype_axis_gen (
		.clk(clk),
		.sresetn(sresetn),

		.vec(ethertype),

		`AXIS_MAP_NO_USER(axis, ethertype_axis)
	);

// Pad input to minimum size with zeros
axis_padder
#(
	.AXIS_BYTES(1),
	.MIN_LENGTH(46), //Minimum ethernet payload length
	.PAD_VALUE(0)
) padder (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP_NO_USER(axis_i, payload_axis),

	`AXIS_MAP_NO_USER(axis_o, payload_axis_padded)
);

// Join streams together
axis_joiner
#(
	.AXIS_BYTES(1),
	.NUM_STREAMS(4)
) joiner (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP_4_NULL_USER(axis_i, payload_axis_padded, ethertype_axis, src_mac_axis, dst_mac_axis),

	`AXIS_MAP_IGNORE_USER(axis_o, joined_axis)
);

// Distribute framed data top joiner and CRC
axis_broadcaster
#(
	.AXIS_BYTES(1),
	.NUM_STREAMS(2)
) bcaster (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP_NULL_USER(axis_i, joined_axis),

	`AXIS_MAP_2_IGNORE_USER(axis_o, crc_in_axis, out_joiner_in_axis)
);

// CRC calculation
eth_crc crc_gen (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP_NO_USER(axis_i, crc_in_axis),
	`AXIS_MAP_NO_USER(axis_o, crc_out_axis)
);

// Unpack crc
axis_width_converter
#(
	.AXIS_I_BYTES(4),
	.AXIS_O_BYTES(1)
) crc_unpacker (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP_NO_USER(axis_i, crc_out_axis),
	`AXIS_MAP_NO_USER(axis_o, crc_unpacked_axis)
);

// Final output
axis_joiner
#(
	.AXIS_BYTES(1),
	.NUM_STREAMS(4)
) out_joiner (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP_4_NULL_USER(axis_i, crc_unpacked_axis, out_joiner_in_axis, sof_axis, preamble_axis),
	`AXIS_MAP_IGNORE_USER(axis_o, out_axis)
);

endmodule
