// Split an AXI stream at a certain word index

`include "axis.h"

module axis_splitter
#(
	parameter AXIS_BYTES = 1,
	parameter AXIS_USER_BITS = 1,
	parameter SPLIT_WORD_OFFSET = 0
) (
	input clk,
	input sresetn,

	`S_AXIS_PORT(axis_i, AXIS_BYTES, AXIS_USER_BITS)

	`M_AXIS_PORT(axis_o1, AXIS_BYTES, AXIS_USER_BITS)
	`M_AXIS_PORT(axis_o2, AXIS_BYTES, AXIS_USER_BITS)
);

localparam integer CTR_WIDTH = SPLIT_WORD_OFFSET < 1? 1 : $clog2(SPLIT_WORD_OFFSET);

localparam logic [CTR_WIDTH-1:0] CTR_MAX = SPLIT_WORD_OFFSET;
reg [CTR_WIDTH-1:0] ctr;

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

assign axis_i_tready = ctr < CTR_MAX ? axis_o1_tready : axis_o2_tready;

assign axis_o1_tvalid = ctr < CTR_MAX ? axis_i_tvalid : 0;
assign axis_o1_tlast  = (ctr == CTR_MAX);
assign axis_o1_tdata  = axis_i_tdata;
assign axis_o1_tuser  = axis_i_tuser;

assign axis_o2_tvalid = ctr < CTR_MAX ? 0 : axis_i_tvalid;
assign axis_o2_tlast  = axis_o1_tlast;
assign axis_o2_tdata  = axis_i_tdata;
assign axis_o2_tuser  = axis_i_tuser;

endmodule
