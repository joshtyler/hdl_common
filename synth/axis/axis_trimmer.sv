// Trim an axi stream to a variable length
// Assumes a packed stream to save logic

`include "axis/axis.h"

module axis_trimmer
#(
	parameter AXIS_BYTES = 1,
	parameter AXIS_USER_BITS = 1,
	parameter LENGTH_BITS = 1
) (
	input clk,
	input sresetn,

	`S_AXIS_PORT(axis_i, AXIS_BYTES, AXIS_USER_BITS),
	// Need to add keep to properly support trim to arbitrary byte length
	input logic [LENGTH_BITS-1:0] axis_i_len_bytes, // Valid alongside data

	`M_AXIS_PORT(axis_o, AXIS_BYTES, AXIS_USER_BITS)
);

logic [LENGTH_BITS-1:0] ctr;

always_ff @(posedge clk)
begin
	if (!sresetn)
	begin
		ctr <= 0;
	end else begin
		if (axis_i_tready && axis_i_tvalid)
		begin
			if(ctr < axis_i_len_bytes)
			begin
				ctr <= ctr + AXIS_BYTES[LENGTH_BITS-1:0];
			end

			if(axis_i_tlast)
			begin
				ctr <= 0;
			end
		end
	end
end

assign axis_i_tready = (ctr >= axis_i_len_bytes) ? 1'b1 : axis_o_tready;

assign axis_o_tvalid = (ctr >= axis_i_len_bytes)? 0 : axis_i_tvalid;
assign axis_o_tlast  = axis_i_tlast || (ctr+AXIS_BYTES[LENGTH_BITS-1:0] >= axis_i_len_bytes);
assign axis_o_tdata  = axis_i_tdata;
assign axis_o_tuser  = axis_i_tuser;


endmodule
