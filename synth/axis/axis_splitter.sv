// Split an AXI stream at a certain byte index

`include "axis/axis.h"
`include "axis/utility.h"

module axis_splitter
#(
	parameter AXIS_BYTES = 1,
	parameter AXIS_USER_BITS = 1,
	parameter SPLIT_BYTE_INDEX = 0
) (
	input clk,
	input sresetn,

	// Assumed to be packed
	`S_AXIS_PORT(axis_i, AXIS_BYTES, AXIS_USER_BITS),

	`M_AXIS_PORT(axis_o1, AXIS_BYTES, AXIS_USER_BITS),
	// Will be unpacked if SPLIT_BYTE_INDEX % AXIS_BYTES != 0
	`M_AXIS_PORT(axis_o2, AXIS_BYTES, AXIS_USER_BITS)
);

localparam SPLIT_WORD_INDEX = `INTEGER_DIV_CEIL(SPLIT_BYTE_INDEX,AXIS_BYTES);
localparam LAST_WORD_REMAINDER = SPLIT_BYTE_INDEX % AXIS_BYTES;
localparam [AXIS_BYTES-1:0] O1_LAST_KEEP_MASK = (LAST_WORD_REMAINDER==0)? '1 : (2**LAST_WORD_REMAINDER)-1;
localparam [AXIS_BYTES-1:0] O2_LAST_KEEP_MASK = ~O1_LAST_KEEP_MASK;

localparam integer CTR_WIDTH = SPLIT_WORD_INDEX < 1? 1 : $clog2(SPLIT_WORD_INDEX);

localparam logic [CTR_WIDTH-1:0] CTR_MAX = SPLIT_WORD_INDEX;
logic [CTR_WIDTH-1:0] ctr;

always_ff @(posedge clk)
begin
	if (!sresetn)
	begin
		ctr <= 0;
	end else begin
		if (axis_i_tready && axis_i_tvalid)
		begin
			if(ctr < CTR_MAX)
			begin
				ctr <= ctr + 1;
			end

			if(axis_i_tlast)
			begin
				ctr <= 0;
			end
		end
	end
end

logic [AXIS_BYTES-1:0] o1_tkeep, o2_tkeep;

always_comb
begin
		o1_tkeep = 0;
		o2_tkeep = 0;
		if(ctr < CTR_MAX)
		begin
			o1_tkeep = axis_i_tkeep;
		end else if(ctr == CTR_MAX) begin
			o1_tkeep = axis_i_tkeep & O1_LAST_KEEP_MASK;
			o2_tkeep = axis_i_tkeep & O2_LAST_KEEP_MASK;
		end else begin
			o2_tkeep = axis_i_tkeep;
		end
end


// This is effectively a broadcaster, but with different tkeep values
// We need to do this because the splitting word goes to both outputs (potentially)

logic [1:0] reg_ready;
assign axis_i_tready = & reg_ready;

logic reg_valid;
assign reg_valid = axis_i_tready && axis_i_tvalid;

axis_register
#(
	.AXIS_BYTES(AXIS_BYTES),
	.AXIS_USER_BITS(AXIS_USER_BITS)
) o1_reg (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(reg_ready[0]),
	.axis_i_tvalid(reg_valid && (| o1_tkeep)),
	.axis_i_tlast (axis_i_tlast || ctr == CTR_MAX),
	.axis_i_tkeep (o1_tkeep),
	.axis_i_tdata (axis_i_tdata),
	.axis_i_tuser (axis_i_tuser),

	`AXIS_MAP(axis_o, axis_o1)
);

`AXIS_INST(axis_o2_unpacked, AXIS_BYTES, AXIS_USER_BITS);
axis_register
#(
	.AXIS_BYTES(AXIS_BYTES),
	.AXIS_USER_BITS(AXIS_USER_BITS)
) o1_reg (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(reg_ready[1]),
	.axis_i_tvalid(reg_valid && (| o2_tkeep)),
	.axis_i_tlast (axis_i_tlast),
	.axis_i_tkeep (o2_tkeep),
	.axis_i_tdata (axis_i_tdata),
	.axis_i_tuser (axis_i_tuser),

	`AXIS_MAP(axis_o, axis_o2)
);

endmodule
