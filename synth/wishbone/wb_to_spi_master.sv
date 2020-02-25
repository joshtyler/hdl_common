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
) config_wb();

wishbone
#(
	.BYTES(BYTES),
	.ADDR_BITS(0)
) axis_wb();

wb_interconnect
#(
	.NUM_MASTERS(2),
	.ADDR_BITS(ADDR_BITS),
	.BYTES(BYTES),
	.SEL_WIDTH(1),
	.MASTER_ADDRESSES({
		{(ADDR_BITS-2){1'b0}},2'b10,
		{(ADDR_BITS-2){1'b0}},2'b01
	}),
	.MASTER_ADDRESS_MASKS({
		{(ADDR_BITS){1'b1}},
		{(ADDR_BITS){1'b1}}
	})
) ic (
	.s_wb(wb),
	.m_addr(),
	.m_dat_m2s({axis_wb.dat_m2s, config_wb.dat_m2s}),
	.m_dat_s2m({axis_wb.dat_s2m, config_wb.dat_s2m}),
	.m_we({axis_wb.we, config_wb.we}),
	.m_sel({axis_wb.sel, config_wb.sel}),
	.m_stb({axis_wb.stb, config_wb.stb}),
	.m_cyc({axis_wb.cyc, config_wb.cyc}),
	.m_ack({axis_wb.ack, config_wb.ack}),
	.m_stall({axis_wb.stall, config_wb.stall})
);

logic [7:0] config_reg;
simple_wb_slave
#(
	.BYTES(BYTES),
	.ADDR_BITS(0)
) cs_inst (
	.clk(clk),
	.sresetn(sresetn),
	.wb(config_wb),
	.regs(config_reg)
);
assign ss = config_reg[0];

logic       axis_wb_to_spi_tready;
logic       axis_wb_to_spi_tvalid;
logic [7:0] axis_wb_to_spi_tdata;

logic       axis_spi_to_wb_tready;
logic       axis_spi_to_wb_tvalid;
logic [7:0] axis_spi_to_wb_tdata;

wb_axis_bridge
#(
	.BYTES(BYTES)
) brige_inst (
	.clk(clk),
	.sresetn(sresetn),

	.wb_stb(axis_wb.stb),
	.wb_we(axis_wb.we),
	.wb_data_i(axis_wb.dat_m2s),
	.wb_data_o(axis_wb.dat_s2m),
	.wb_ack(axis_wb.ack),
	.wb_stall(axis_wb.stall),

	.axis_i_tready(axis_spi_to_wb_tready),
	.axis_i_tvalid(axis_spi_to_wb_tvalid),
	.axis_i_tdata(axis_spi_to_wb_tdata),

	.axis_o_tready(axis_wb_to_spi_tready),
	.axis_o_tvalid(axis_wb_to_spi_tvalid),
	.axis_o_tdata(axis_wb_to_spi_tdata)
);

axis_spi_bridge
#(
	.AXIS_BYTES(BYTES)
) spi_inst (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(axis_wb_to_spi_tready),
	.axis_i_tvalid(axis_wb_to_spi_tvalid),
	.axis_i_tdata(axis_wb_to_spi_tdata),

	.axis_o_tready(axis_spi_to_wb_tready),
	.axis_o_tvalid(axis_spi_to_wb_tvalid),
	.axis_o_tdata(axis_spi_to_wb_tdata),

	.sck(sck),
	.miso(miso),
	.mosi(mosi)
);

endmodule
