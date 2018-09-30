// Interface an RMII Phy to two AXIS streams
// Data width is fixed at 8 bits because this is fundamental to how it works
// N.B. This module assumes 100 BASE TX communication

module rmii_to_axis
(
	input clk, // 50MHz
	input sresetn,

	// RMII interface
	output [1:0] txd,
	output tx_en,
	input [1:0] rxd,
	input crs_dv,
	input rx_er,

	// TX AXIS
	output      tx_axis_ready,
	input       tx_axis_tvalid,
	input       tx_axis_tlast, //Not currently used
	input [7:0] tx_axis_tdata,

	// Rx axis
	output       rx_axis_tvalid,
	output       rx_axis_tlast,
	output [7:0] rx_axis_tdata
);

// N.B. Rx interface is not currently implemented
assign rx_axis_tvalid = 0;
assign rx_axis_tlast = 0;
assign rx_axis_tdata = 0;

logic [7:0] tx_data_latch;

// Latch the data when it is valid
always @(posedge clk)
	if (tx_axis_ready && tx_axis_tvalid)
		tx_data_latch <= tx_axis_tdata;

/*
// Directly output the input data if the counter is zero
// Otherwise output from the latched data
always @(*)
	if(ctr == 0)
		txd = tx_axis_tdata[ (1+ctr)*2 -: 2];
	else

		txd = tx_data_latch[ (1+ctr)*2 -: 2];
*/
	assign txd = tx_data_latch[ ((1+ctr)*2)-1 -: 2];

// Request data when we are outputting the last word
assign tx_axis_ready = (ctr == 3);


reg [1 : 0] ctr;

always @(posedge clk)
begin
	if (sresetn == 0)
	begin
		ctr <= 3;
		tx_en <= 0;
	end else begin
		if (ctr == 3) begin
			// Latch the output enable to the input valid when we are requesting a new word
			tx_en <= tx_axis_tvalid;
			if (tx_axis_tvalid) begin
				ctr <= 0;
			end
		end else begin
			ctr <= ctr + 1;
		end
	end
end


endmodule
