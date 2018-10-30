// Send one packet to the first output
// The next packet to the second output
// etc

module axis_round_robin
#(
	parameter AXIS_BYTES = 1,
	parameter NUM_SLAVE_STREAMS = 1
) (
	input clk,
	input sresetn,

	// Input
	output                      axis_i_tready,
	input                       axis_i_tvalid,
	input                       axis_i_tlast,
	input [(AXIS_BYTES*8)-1:0]  axis_i_tdata,

	// Output
	input  [NUM_SLAVE_STREAMS-1 : 0]              axis_o_tready,
	output [NUM_SLAVE_STREAMS-1 : 0]              axis_o_tvalid,
	output [NUM_SLAVE_STREAMS-1 : 0]              axis_o_tlast,
	output [NUM_SLAVE_STREAMS*(AXIS_BYTES*8)-1:0] axis_o_tdata
);
	localparam AXIS_TDEST_BITS = $clog2(NUM_SLAVE_STREAMS);
	logic [AXIS_TDEST_BITS-1:0] axis_i_tdest;

	always @(posedge clk) begin
		if (sresetn == 0) begin
			axis_i_tdest <= 0;
		end else begin
			if (axis_i_tready && axis_i_tvalid && axis_i_tlast)
			begin
				axis_i_tdest <= axis_i_tdest + 1;
			end
		end
	end

	axis_switch
	#(
		.AXIS_BYTES(AXIS_BYTES),
		.AXIS_TDEST_BITS(AXIS_TDEST_BITS),
		.NUM_SLAVE_STREAMS(NUM_SLAVE_STREAMS)
	) switch (
		.clk(clk),
		.sresetn(sresetn),

		.axis_i_tready(axis_i_tready),
		.axis_i_tvalid(axis_i_tvalid),
		.axis_i_tlast (axis_i_tlast),
		.axis_i_tdest (axis_i_tdest),
		.axis_i_tdata (axis_i_tdata),

		.axis_o_tready(axis_o_tready),
		.axis_o_tvalid(axis_o_tvalid),
		.axis_o_tlast (axis_o_tlast),
		.axis_o_tdata (axis_o_tdata)
	);

endmodule
