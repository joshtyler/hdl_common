module wb_to_spi_master
#(
	localparam BYTES = 1,
	localparam ADDR_BITS = 8
) (
	input logic clk,
	input logic sresetn,

	wishbone.slave wb,

	output logic sck,
	output logic ss,
	input logic miso,
	output logic mosi
);

wishbone
#(
	.BYTES(BYTES),
	.ADDR_BITS(0)
) wb_axis();

wishbone
#(
	.BYTES(BYTES),
	.ADDR_BITS(0)
) wb_cs();

wb_interconnect
#(
	.NUM_SLAVES(2),
	.MASTER_ADDR_BITS(ADDR_BITS),
	.SLAVE_ADDRESSES({
		{(ADDR_BITS-2){1'b0}},2'b01,
		{(ADDR_BITS-2){1'b0}},2'b10
	}),
	.SLAVE_ADDRESS_BITS({0,0})
) ic (
	.m_wb(wb),
	.s_wb({wb_axis,wb_cs})
);

logic [7:0] config_reg;
simple_wb_slave
#(
	.BYTES(BYTES),
	.ADDR_BITS(0)
) cs_inst (
	.clk(clk),
	.sresetn(sresetn),
	.wb(wb_cs),
	.regs(config_reg)
);
assign ss = config_reg[0];

wb_axis_bridge
#(
	.BYTES(BYTES),
) brige_inst (
	.clk(clk),
	.sresetn(sresetn),

	.wb_stb(wb_axis.stb),
	.wb_we(wb_axis.we),
	.wb_data_i(wb_axis.dat_m2s),
	.wb_data_o(wb_axis.dat_s2m),
	.wb_ack(wb_axis.ack),
	.wb_stall(wb_axis.stall),

	.axis_i_tready(uart_rx_tready),
	.axis_i_tvalid(uart_rx_tvalid),
	.axis_i_tdata(uart_rx_tdata),

	.axis_o_tready(uart_tx_tready),
	.axis_o_tvalid(uart_tx_tvalid),
	.axis_o_tdata(uart_tx_tdata)
);

endmodule
