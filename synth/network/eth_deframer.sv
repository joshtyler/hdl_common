`include "axis/axis.h"
`include "utility.h"

module eth_deframer
#(
	// Just support four bytes wide. This makes deframing much easier
	parameter integer AXIS_BYTES = 4
	parameter REQUIRE_PACKED_OUTPUT = 1
) (
	input clk,
	input sresetn,

	`S_AXIS_PORT_NO_USER(axis_i, AXIS_BYTES),

	// Not packed if 14 % AXIS_BYTES != 0
	`M_AXIS_PORT_NO_USER(axis_o, AXIS_BYTES),
	output logic [6*8-1:0] axis_o_dst_mac,
	output logic [6*8-1:0] axis_o_src_mac,
	output logic [2*8-1:0] axis_o_ethertype
);

`BYTE_SWAP_FUNCTION(byte_swap_6, 6)
`BYTE_SWAP_FUNCTION(byte_swap_2, 2)

logic [14*8-1] header;
axis_header_tagger
#(
	.AXIS_BYTES(AXIS_BYTES),
	.HEADER_LENGTH_BYTES(14),
	.REQUIRE_PACKED_OUTPUT(REQUIRE_PACKED_OUTPUT)
) trimmer (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP_NULL_USER(axis_i, axis_i),

	`AXIS_MAP_IGNORE_USER(axis_o, axis_o),
	.axis_o_header(header)
);

assign axis_o_dst_mac   = byte_swap_6(header[6*8-1 :0]);
assign axis_o_src_mac   = byte_swap_6(header[12*8-1:6*8]);
assign axis_o_ethertype = byte_swap_2(header[14*8-1:12*8]);

endmodule
