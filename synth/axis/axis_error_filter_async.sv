// Filter out bad axis packets
// Drop the remainder of the packet up until tlast if error ever goes high

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

	output logic                      axis_i_tready,
	input  logic                      axis_i_tvalid,
	input  logic                      axis_i_tlast,
	input  logic [(AXIS_BYTES*8)-1:0] axis_i_tdata,
	input  logic [AXIS_USER_BITS-1:0] axis_i_tuser,
	input  logic                      axis_i_error,

	input  logic                      axis_o_tready,
	output logic                      axis_o_tvalid,
	output logic                      axis_o_tlast,
	output logic [(AXIS_BYTES*8)-1:0] axis_o_tdata,
	output logic [AXIS_USER_BITS-1:0] axis_o_tuser
);

	logic error_latch;
	logic axis_i_tvalid_gated;

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

	assign axis_i_tvalid_gated = axis_i_tvalid && (!error_latch);

	axis_packet_fifo_async
	#(
		.AXIS_BYTES(AXIS_BYTES),
		.LOG2_DEPTH(LOG2_DEPTH)
	) fifo_inst (
		.i_clk(i_clk),
		.i_sresetn(i_sresetn),

		.o_clk(o_clk),
		.o_sresetn(o_sresetn),

		.axis_i_tready(axis_i_tready),
		.axis_i_tvalid(axis_i_tvalid_gated),
		.axis_i_tlast (axis_i_tlast),
		.axis_i_tdata (axis_i_tdata),
		.axis_i_tuser (axis_i_tuser),
		.axis_i_drop  (axis_i_error),

		.axis_o_tready(axis_o_tready),
		.axis_o_tvalid(axis_o_tvalid),
		.axis_o_tlast (axis_o_tlast),
		.axis_o_tdata (axis_o_tdata),
		.axis_o_tuser (axis_o_tuser)
	);

endmodule
