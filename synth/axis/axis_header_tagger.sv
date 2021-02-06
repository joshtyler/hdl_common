// Strip a header from an AXI stream and tag it onto the output

`include "axis/axis.h"
`include "axis/utility.h"

module axis_header_tagger
#(
	parameter AXIS_BYTES = 1,
	parameter AXIS_USER_BITS = 1,
	parameter HEADER_LENGTH_BYTES = 0,
	parameter REQUIRE_PACKED_OUTPUT = 1
) (
	input clk,
	input sresetn,

	// Assumed to be packed
	`S_AXIS_PORT(axis_i, AXIS_BYTES, AXIS_USER_BITS),

	// Will be unpacked if HEADER_LENGTH % AXIS_BYTES != 0
	`M_AXIS_PORT(axis_o, AXIS_BYTES, AXIS_USER_BITS),
	output logic [HEADER_LENGTH_BYTES-1 : 0] axis_o_header
);

`AXIS_INST(axis_header, AXIS_BYTES);
`AXIS_INST(axis_o_gated, AXIS_BYTES);

axis_splitter
#(
	.AXIS_BYTES(AXIS_BYTES),
	.AXIS_USER_BITS(AXIS_USER_BITS),
	.SPLIT_BYTE_INDEX(HEADER_LENGTH_BYTES)
) splitter (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP(axis_i, axis_i),

	`AXIS_MAP(axis_o1, axis_header),
	`AXIS_MAP(axis_o2, axis_o_gated)
);

axis_width_converter
#(
	.AXIS_I_BYTES(AXIS_BYTES),
	.AXIS_O_BYTES(HEADER_LENGTH_BYTES)
) splitter (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP(axis_i, axis_i),
	.axis_o_tready(axis_o_tvalid && axis_o_tlast), // Accept the header on the last beat of the real output
	.axis_o_tvalid(header_valid),
	.axis_o_tlast()
	.axis_o_tkeep(),
	.axis_o_tdata(axis_o_header)
);

`AXIS_INST(axis_unpacked_o, AXIS_BYTES);

assign axis_o_tready_gated    = header_valid && axis_unpacked_o_tready;
assign axis_unpacked_o_tvalid = header_valid && axis_o_gated_tvalid;
assign axis_unpacked_o_tlast  = axis_o_gated_tlast;
assign axis_unpacked_o_tkeep  = axis_o_gated_tkeep;
assign axis_unpacked_o_tdata  = axis_o_gated_tdata;
assign axis_unpacked_o_tuser  = axis_o_gated_tuesr;

generate
	if(REQUIRE_PACKED_OUTPUT && ((HEADER_LENGTH_BYTES % AXIS_BYTES) != 0))
	begin
		axis_packer
		#(
			.AXIS_BYTES(AXIS_BYTES)
		) rx_mac (
			.clk(clk),
			.sresetn(sresetn),

			`AXIS_MAP_NO_USER(axis_i, axis_unpacked_o),
			`AXIS_MAP_NO_USER(axis_o, axis_o),
		);
	end else begin
		assign axis_unpacked_o_tready = axis_o_tready;
		assign axis_o_tvalid = axis_unpacked_o_tvalid;
		assign axis_o_tlast  = axis_unpacked_o_tlast;
		assign axis_o_tkeep  = axis_unpacked_o_tkeep;
		assign axis_o_tdata  = axis_unpacked_o_tdata;
		assign axis_o_tuser  = axis_unpacked_o_tuesr;
	end
endgenerate

endmodule
