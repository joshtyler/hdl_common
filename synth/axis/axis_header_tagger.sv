// Strip a header from an AXI stream and tag it onto the output

`include "axis/axis.h"
`include "axis/utility.h"

module axis_header_tagger
#(
	parameter AXIS_BYTES = 1,
	parameter AXIS_USER_BITS = 1,
	parameter HEADER_LENGTH_BYTES = 1,
	parameter REQUIRE_PACKED_OUTPUT = 1
) (
	input clk,
	input sresetn,

	// Assumed to be packed
	`S_AXIS_PORT(axis_i, AXIS_BYTES, AXIS_USER_BITS),

	// Will be unpacked if HEADER_LENGTH % AXIS_BYTES != 0 and REQUIRE_PACKED_OUTPUT != 0
	`M_AXIS_PORT(axis_o, AXIS_BYTES, AXIS_USER_BITS),
	output logic [HEADER_LENGTH_BYTES*8-1 : 0] axis_o_header
);

localparam SPLIT_WORD_INDEX = `INTEGER_DIV_CEIL(HEADER_LENGTH_BYTES-1,AXIS_BYTES);
localparam LAST_WORD_REMAINDER = (HEADER_LENGTH_BYTES) % AXIS_BYTES;
localparam [AXIS_BYTES-1:0] HEADER_LAST_KEEP_MASK = (LAST_WORD_REMAINDER==0)? '1 : (2**LAST_WORD_REMAINDER)-1;
localparam [AXIS_BYTES-1:0] DATA_LAST_KEEP_MASK = ~HEADER_LAST_KEEP_MASK;

localparam integer CTR_WIDTH = SPLIT_WORD_INDEX < 1? 1 : $clog2(SPLIT_WORD_INDEX+1);
localparam [CTR_WIDTH-1:0] CTR_MAX = SPLIT_WORD_INDEX[CTR_WIDTH-1:0];
logic [CTR_WIDTH-1:0] ctr;

// Have a dummy header output variable so that we don't run past the end
logic [(SPLIT_WORD_INDEX+1)*AXIS_BYTES*8-1:0] axis_o_header_widened;
assign axis_o_header = axis_o_header_widened[HEADER_LENGTH_BYTES*8-1:0];

// N.B. We currently only the system once axis_o_tlast has been seen
// This means we effectively block whilst the packer is processing
// To get around this, we could modify the packer to pass through a tag alongside the data
logic flushing;
always_ff @(posedge clk)
begin
	if (!sresetn || (axis_o_tready && axis_o_tvalid && axis_o_tlast))
	begin
		ctr <= 0;
		flushing <= 0;
		// Below this line resets are not needed, but included to reduce logic
		axis_o_header_widened <= 0;
	end else begin
		if (axis_i_tready && axis_i_tvalid)
		begin
			if(ctr < CTR_MAX)
			begin
				ctr <= ctr + 1;
				axis_o_header_widened[ctr*AXIS_BYTES*8 +: AXIS_BYTES*8] <= axis_i_tdata;
			end

			if(axis_unpacked_o_tready && axis_unpacked_o_tvalid && axis_unpacked_o_tlast)
			begin
				flushing <= 1;
			end
		end
	end
end

`AXIS_INST(axis_unpacked_o, AXIS_BYTES, AXIS_USER_BITS);

// When the beats are just the header, always consume
// From the handover beat, handover to the packer
// Once the packer has seen tlast, wait to flush the output before accepting a new packet
always_comb
begin
	axis_i_tready = 0;
	axis_unpacked_o_tvalid = 0;
	if(ctr < CTR_MAX-1)
	begin
		axis_i_tready = 1'b1;
		axis_unpacked_o_tvalid = 1'b0;
	end else if(!flushing) begin
		axis_unpacked_o_tvalid = axis_i_tvalid;
		axis_i_tready = axis_unpacked_o_tready;
	end
end

assign axis_unpacked_o_tlast  = axis_i_tlast;
assign axis_unpacked_o_tkeep  = (ctr < CTR_MAX)? axis_i_tkeep & DATA_LAST_KEEP_MASK : axis_i_tkeep;
assign axis_unpacked_o_tdata  = axis_i_tdata;
assign axis_unpacked_o_tuser  = axis_i_tuser;

// We need at least one register stage in here to make sure that axis_o_header is valid on the first beat
// axis_packer provides this as a matter of course, but we will inset one manually in the case it is not needed
generate
	if(REQUIRE_PACKED_OUTPUT && ((HEADER_LENGTH_BYTES % AXIS_BYTES) != 0))
	begin
		axis_packer
		#(
			.AXIS_BYTES(AXIS_BYTES)
		) packer (
			.clk(clk),
			.sresetn(sresetn),

			`AXIS_MAP_NO_USER(axis_i, axis_unpacked_o),
			`AXIS_MAP_NO_USER(axis_o, axis_o)
		);
	end else begin
		axis_register
		#(
			.AXIS_BYTES(AXIS_BYTES)
		) packer (
			.clk(clk),
			.sresetn(sresetn),

			`AXIS_MAP_NULL_USER(axis_i, axis_unpacked_o),
			`AXIS_MAP_IGNORE_USER(axis_o, axis_o)
		);
	end
endgenerate

endmodule
