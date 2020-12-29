// Filter out bad axis packets
// Drop the remainder of the packet up until tlast if error ever goes high

`include "axis/axis.h"

module axis_error_filter_async
#(
	parameter AXIS_BYTES = 1,
	parameter AXIS_USER_BITS = 1,
	parameter LOG2_DEPTH = 8
) (
	input i_clk,
	input i_sresetn,

	input o_clk,
	input o_sresetn,

	input logic i_valid;
	input logic i_last;
	input logic [AXIS_BYTES*8-1:0] i_data;
	input logic [AXIS_USER_BITS-1:0] i_user;
	input logic i_error,

	`M_AXIS_PORT(axis_o, AXIS_BYTES, AXIS_USER_BITS)
);

	`AXIS_INST(axis_i, AXIS_BYTES, AXIS_USER_BITS);
	logic overflowed;

	always_ff @(posedge i_clk)
	begin
		if(!i_sresetn)
		begin
			error_latch <= 0;
		end else begin
			if(axis_i_tready && axis_i_tvalid)
			begin
				if(axis_i_tlast)
				begin
					// Reset the latch on the last beat
					error_latch <= 0;
				end else if(axis_i_error) begin
					// Otherwise latch any errors
					error_latch <= 1;
				end
			end
		end
	end

	// Pass signals through, unless we overflow
	// In this case, discard all of the current packet
	logic axis_i_tdrop;
	assign axis_i_tvalid = i_tvalid || overflowed;
	assign axis_i_tlast  = i_last;
	assign axis_i_tdata  = i_data;
	assign axis_i_tuser  = i_user;
	assign axis_i_tdrop  = i_error || overflowed;

	axis_packet_fifo_async
	#(
		.AXIS_BYTES(AXIS_BYTES),
		.LOG2_DEPTH(LOG2_DEPTH)
	) fifo_inst (
		.i_clk(i_clk),
		.i_sresetn(i_sresetn),

		.o_clk(o_clk),
		.o_sresetn(o_sresetn),

		`AXIS_MAP(axis_i, axis_i),
		.axis_i_drop(axis_i_drop),
		`AXIS_MAP(axis_o, axis_o)
	);

endmodule
