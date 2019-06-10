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
	output      payload_axis_tready,
	input       payload_axis_tvalid,
	input       payload_axis_tlast,
	input [7:0] payload_axis_tdata,

	// Output
	input out_axis_tready,
	output out_axis_tvalid,
	output out_axis_tlast,
	output [7:0] out_axis_tdata
);

logic       preamble_axis_tready;
logic       preamble_axis_tvalid;
logic       preamble_axis_tlast;
logic [7:0] preamble_axis_tdata;

logic       sof_axis_tready;
logic       sof_axis_tvalid;
logic       sof_axis_tlast;
logic [7:0] sof_axis_tdata;

logic       dst_mac_axis_tready;
logic       dst_mac_axis_tvalid;
logic       dst_mac_axis_tlast;
logic [7:0] dst_mac_axis_tdata;

logic       src_mac_axis_tready;
logic       src_mac_axis_tvalid;
logic       src_mac_axis_tlast;
logic [7:0] src_mac_axis_tdata;

logic       ethertype_axis_tready;
logic       ethertype_axis_tvalid;
logic       ethertype_axis_tlast;
logic [7:0] ethertype_axis_tdata;

logic       joined_axis_tready;
logic       joined_axis_tvalid;
logic       joined_axis_tlast;
logic [7:0] joined_axis_tdata;

logic       crc_in_axis_tready;
logic       crc_in_axis_tvalid;
logic       crc_in_axis_tlast;
logic [7:0] crc_in_axis_tdata;

logic       out_joiner_in_axis_tready;
logic       out_joiner_in_axis_tvalid;
logic       out_joiner_in_axis_tlast;
logic [7:0] out_joiner_in_axis_tdata;

logic        crc_out_axis_tready;
logic        crc_out_axis_tvalid;
logic        crc_out_axis_tlast;
logic [31:0] crc_out_axis_tdata;

logic       crc_unpacked_axis_tready;
logic       crc_unpacked_axis_tvalid;
logic       crc_unpacked_axis_tlast;
logic [7:0] crc_unpacked_axis_tdata;

logic       payload_axis_padded_tready;
logic       payload_axis_padded_tvalid;
logic       payload_axis_padded_tlast;
logic [7:0] payload_axis_padded_tdata;

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

		.axis_tready(preamble_axis_tready),
		.axis_tvalid(preamble_axis_tvalid),
		.axis_tlast (preamble_axis_tlast),
		.axis_tdata (preamble_axis_tdata)
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

		.axis_tready(sof_axis_tready),
		.axis_tvalid(sof_axis_tvalid),
		.axis_tlast (sof_axis_tlast),
		.axis_tdata (sof_axis_tdata)
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

		.axis_tready(dst_mac_axis_tready),
		.axis_tvalid(dst_mac_axis_tvalid),
		.axis_tlast (dst_mac_axis_tlast),
		.axis_tdata (dst_mac_axis_tdata)
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

		.axis_tready(src_mac_axis_tready),
		.axis_tvalid(src_mac_axis_tvalid),
		.axis_tlast (src_mac_axis_tlast),
		.axis_tdata (src_mac_axis_tdata)
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

		.axis_tready(ethertype_axis_tready),
		.axis_tvalid(ethertype_axis_tvalid),
		.axis_tlast (ethertype_axis_tlast),
		.axis_tdata (ethertype_axis_tdata)
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

	.axis_i_tready(payload_axis_tready),
	.axis_i_tvalid(payload_axis_tvalid),
	.axis_i_tlast (payload_axis_tlast),
	.axis_i_tdata (payload_axis_tdata),

	.axis_o_tready(payload_axis_padded_tready),
	.axis_o_tvalid(payload_axis_padded_tvalid),
	.axis_o_tlast (payload_axis_padded_tlast),
	.axis_o_tdata (payload_axis_padded_tdata)
);

// Join streams together
axis_joiner
#(
	.AXIS_BYTES(1),
	.NUM_STREAMS(4)
) joiner (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready({  payload_axis_padded_tready,
	                ethertype_axis_tready,
	                  src_mac_axis_tready,
	                  dst_mac_axis_tready}),
	.axis_i_tvalid({  payload_axis_padded_tvalid,
	                ethertype_axis_tvalid,
	                  src_mac_axis_tvalid,
	                  dst_mac_axis_tvalid}),
	.axis_i_tlast ({  payload_axis_padded_tlast,
                  ethertype_axis_tlast,
                    src_mac_axis_tlast,
                    dst_mac_axis_tlast}),
	.axis_i_tdata ({  payload_axis_padded_tdata,
                  ethertype_axis_tdata,
                    src_mac_axis_tdata,
                    dst_mac_axis_tdata}),

.axis_o_tready(joined_axis_tready),
.axis_o_tvalid(joined_axis_tvalid),
.axis_o_tlast (joined_axis_tlast),
.axis_o_tdata (joined_axis_tdata)
);

// Distribute framed data top joiner and CRC
axis_broadcaster
#(
	.AXIS_BYTES(1),
	.NUM_STREAMS(2)
) bcaster (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(joined_axis_tready),
	.axis_i_tvalid(joined_axis_tvalid),
	.axis_i_tlast (joined_axis_tlast),
	.axis_i_tdata (joined_axis_tdata),

	.axis_o_tready({ crc_in_axis_tready,
	                 out_joiner_in_axis_tready}),
	.axis_o_tvalid({ crc_in_axis_tvalid,
	                 out_joiner_in_axis_tvalid}),
	.axis_o_tlast ({ crc_in_axis_tlast,
                   out_joiner_in_axis_tlast}),
	.axis_o_tdata ({ crc_in_axis_tdata,
                   out_joiner_in_axis_tdata})
);

// CRC calculation
eth_crc crc_gen (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(crc_in_axis_tready),
	.axis_i_tvalid(crc_in_axis_tvalid),
	.axis_i_tlast (crc_in_axis_tlast),
	.axis_i_tdata (crc_in_axis_tdata),

	.axis_o_tready(crc_out_axis_tready),
	.axis_o_tvalid(crc_out_axis_tvalid),
	.axis_o_tlast (crc_out_axis_tlast),
	.axis_o_tdata (crc_out_axis_tdata)
);

// Unpack crc
axis_width_converter
#(
	.AXIS_I_BYTES(4),
	.AXIS_O_BYTES(1)
) crc_unpacker (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(crc_out_axis_tready),
	.axis_i_tvalid(crc_out_axis_tvalid),
	.axis_i_tlast (crc_out_axis_tlast),
	.axis_i_tdata (crc_out_axis_tdata),

	.axis_o_tready(crc_unpacked_axis_tready),
	.axis_o_tvalid(crc_unpacked_axis_tvalid),
	.axis_o_tlast (crc_unpacked_axis_tlast),
	.axis_o_tdata (crc_unpacked_axis_tdata)
);

// Final output
axis_joiner
#(
	.AXIS_BYTES(1),
	.NUM_STREAMS(4)
) out_joiner (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready({ crc_unpacked_axis_tready,
	                 out_joiner_in_axis_tready,
                   sof_axis_tready,
                   preamble_axis_tready}),
	.axis_i_tvalid({ crc_unpacked_axis_tvalid,
	                 out_joiner_in_axis_tvalid,
                   sof_axis_tvalid,
                   preamble_axis_tvalid}),
	.axis_i_tlast ({ crc_unpacked_axis_tlast,
                   out_joiner_in_axis_tlast,
                   sof_axis_tlast,
                   preamble_axis_tlast}),
	.axis_i_tdata ({ crc_unpacked_axis_tdata,
                   out_joiner_in_axis_tdata,
                   sof_axis_tdata,
                   preamble_axis_tdata}),

.axis_o_tready(out_axis_tready),
.axis_o_tvalid(out_axis_tvalid),
.axis_o_tlast (out_axis_tlast),
.axis_o_tdata (out_axis_tdata)
);

endmodule
