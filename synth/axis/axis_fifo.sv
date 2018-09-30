module axis_fifo
#(
	parameter AXIS_BYTES = 1,
	parameter DEPTH = 1024
) (
	input clk,
	input sresetn,

	// Input
	output                     axis_i_tready,
	input                      axis_i_tvalid,
	input                      axis_i_tlast,
	input [(AXIS_BYTES*8)-1:0] axis_i_tdata,

	// Output
	input                       axis_o_tready,
	output                      axis_o_tvalid,
	output                      axis_o_tlast,
	output [(AXIS_BYTES*8)-1:0] axis_o_tdata
);

logic full,empty;

assign axis_i_tready = !full;
// valid lags one cycle behind empty
// This is because empty is a "ready to accept reads" signal
// So the data is valid one clock cycle after it goes low
// And when it goes high again, the data is in fact valid!
always @(posedge clk)
	if(sresetn == 0)
		axis_o_tvalid = 0;
	else
		axis_o_tvalid = !empty;

fifo
	#(
		.WIDTH((AXIS_BYTES*8)+1),
		.DEPTH(DEPTH)
	) fifo_inst (
		.clk(clk),
		.n_reset(sresetn),

		.full(full),
		.wr_en(axis_i_tvalid),
		.data_in ({axis_i_tdata, axis_i_tlast}),

		.rd_en(axis_o_tready),
		.empty(empty),
		.data_out ({axis_o_tdata, axis_o_tlast})
	);

endmodule
