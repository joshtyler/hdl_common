module wb_to_spi_master
#(
	localparam BYTES = 1,
	localparam ADDR_BITS = 8,
	localparam SEL_WIDTH = 1
) (
	input logic clk,
	input logic sresetn,

	input  logic [ADDR_BITS-1:0] s_wb_addr,
	input  logic [BYTES*8-1:0]   s_wb_dat_m2s,
	output logic [BYTES*8-1:0]   s_wb_dat_s2m,
	input  logic                 s_wb_we,
	input  logic [SEL_WIDTH-1:0] s_wb_sel,
	input  logic                 s_wb_stb,
	input  logic                 s_wb_cyc,
	output logic                 s_wb_ack,
	output logic                 s_wb_stall,

	output logic sck,
	output logic ss,
	input logic miso,
	output logic mosi
);

logic [BYTES*8-1:0]   wb_axis_dat_m2s , wb_config_dat_m2s , wb_inject_dat_m2s;
logic [BYTES*8-1:0]   wb_axis_dat_s2m , wb_config_dat_s2m , wb_inject_dat_s2m;
logic                 wb_axis_we      , wb_config_we      , wb_inject_we     ;
logic                 wb_axis_stb     , wb_config_stb     , wb_inject_stb    ;
logic                 wb_axis_cyc     , wb_config_cyc     , wb_inject_cyc    ;
logic                 wb_axis_ack     , wb_config_ack     , wb_inject_ack    ;
logic                 wb_axis_stall   , wb_config_stall   , wb_inject_stall  ;


wb_interconnect
#(
	.NUM_MASTERS(3),
	.ADDR_BITS(ADDR_BITS),
	.BYTES(BYTES),
	.SEL_WIDTH(1),
	.MASTER_ADDRESSES({
		{(ADDR_BITS-2){1'b0}},2'b11,
		{(ADDR_BITS-2){1'b0}},2'b10,
		{(ADDR_BITS-2){1'b0}},2'b01
	}),
	.MASTER_ADDRESS_MASKS({
		{(ADDR_BITS){1'b1}},
		{(ADDR_BITS){1'b1}},
		{(ADDR_BITS){1'b1}}
	})
) ic (
	.s_wb_addr   (s_wb_addr   ),
	.s_wb_dat_m2s(s_wb_dat_m2s),
	.s_wb_dat_s2m(s_wb_dat_s2m),
	.s_wb_we     (s_wb_we     ),
	.s_wb_sel    (s_wb_sel    ),
	.s_wb_stb    (s_wb_stb    ),
	.s_wb_cyc    (s_wb_cyc    ),
	.s_wb_ack    (s_wb_ack    ),
	.s_wb_stall  (s_wb_stall  ),

	.m_wb_addr(),
	.m_wb_dat_m2s({wb_inject_dat_m2s , wb_axis_dat_m2s , wb_config_dat_m2s }),
	.m_wb_dat_s2m({wb_inject_dat_s2m , wb_axis_dat_s2m , wb_config_dat_s2m }),
	.m_wb_we     ({wb_inject_we      , wb_axis_we      , wb_config_we      }),
	.m_wb_sel    (),
	.m_wb_stb    ({wb_inject_stb     , wb_axis_stb     , wb_config_stb     }),
	.m_wb_cyc    ({wb_inject_cyc     , wb_axis_cyc     , wb_config_cyc     }),
	.m_wb_ack    ({wb_inject_ack     , wb_axis_ack     , wb_config_ack     }),
	.m_wb_stall  ({wb_inject_stall   , wb_axis_stall   , wb_config_stall   })
);

// Handle config reads and writes
logic discard_rx_data;
logic axis_spi_bridge_active;

always_ff @(posedge clk)
begin
	if (!sresetn)
	begin
		ss <= 1;
		discard_rx_data <= 0;
	end else begin

		if (wb_config_stb && wb_config_we && (!wb_config_stall))
		begin
			ss <= wb_config_dat_m2s[0];
			discard_rx_data <= wb_config_dat_m2s[1];
		end
	end

	wb_config_dat_s2m <= {6'b000000, discard_rx_data, ss};

	wb_config_ack <= wb_config_stb && (!wb_config_stall);
end
// Don't allow changing config whilst data is being transferred
// This stops us from de-asserting SS half way through a transfer
assign wb_config_stall = wb_config_stb && axis_spi_bridge_active;


logic       axis_wb_to_spi_tready;
logic       axis_wb_to_spi_tvalid;
logic [7:0] axis_wb_to_spi_tdata;

logic       axis_spi_to_wb_tready;
logic       axis_spi_to_wb_tvalid;
logic [7:0] axis_spi_to_wb_tdata;

logic       axis_spi_to_wb_buf_tready;
logic       axis_spi_to_wb_buf_tvalid;
logic [7:0] axis_spi_to_wb_buf_tdata;

// Register to inject bytes into stream
// When the counter is non zero, inject that many dummy bytes into the stream
// This is realistic since the reason to inject is because we want to read from the device
// To make the logic simple, assume that we are not trying to write at the same time
logic [7:0] inject_ctr;
always_ff @(posedge clk)
begin
	if (!sresetn)
	begin
		inject_ctr <= 0;
	end else begin

		if (wb_inject_stb && wb_inject_we)
		begin
			inject_ctr<= wb_inject_dat_m2s;
		end else if (axis_wb_to_spi_tready && (inject_ctr != 0))  begin
			inject_ctr<= inject_ctr-1;
		end
	end;

	wb_inject_dat_s2m <= inject_ctr;

	wb_inject_ack <= wb_inject_stb;
end
// We never need to stall
assign wb_inject_stall = 0;




wb_axis_bridge
#(
	.BYTES(BYTES)
) brige_inst (
	.clk(clk),
	.sresetn(sresetn),

	.wb_stb   (wb_axis_stb),
	.wb_we    (wb_axis_we),
	.wb_data_i(wb_axis_dat_m2s),
	.wb_data_o(wb_axis_dat_s2m),
	.wb_ack   (wb_axis_ack),
	.wb_stall (wb_axis_stall),

	.axis_i_tready(axis_spi_to_wb_buf_tready),
	.axis_i_tvalid(axis_spi_to_wb_buf_tvalid),
	.axis_i_tdata (axis_spi_to_wb_buf_tdata),

	.axis_o_tready(axis_wb_to_spi_tready),
	.axis_o_tvalid(axis_wb_to_spi_tvalid),
	.axis_o_tdata(axis_wb_to_spi_tdata)
);

// FIFO the data back from the SPI bus so that outstanding transactions are possible
axis_fifo
#(
	.AXIS_BYTES(1),
	.DEPTH(256)
) fifo_inst (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(axis_spi_to_wb_tready),
	.axis_i_tvalid(axis_spi_to_wb_tvalid),
	.axis_i_tlast(1),
	.axis_i_tdata (axis_spi_to_wb_tdata),

	// Output
	.axis_o_tready(axis_spi_to_wb_buf_tready),
	.axis_o_tvalid(axis_spi_to_wb_buf_tvalid),
	.axis_o_tlast (),
	.axis_o_tdata (axis_spi_to_wb_buf_tdata)
);


// This is actually the input valid signal
// We are cheating slightly, we know that the SPI bridge is only transferring data when the input data is valid
// (i.e. it doesn't buffer internally, it only asserts ready when it is done with the data)
assign axis_spi_bridge_active = axis_wb_to_spi_tvalid || (inject_ctr != 0);

axis_spi_bridge
#(
	.AXIS_BYTES(BYTES)
) spi_inst (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(axis_wb_to_spi_tready),
	.axis_i_tvalid(axis_spi_bridge_active),
	.axis_i_tdata(axis_wb_to_spi_tdata),
	.axis_i_tuser(discard_rx_data),

	.axis_o_tready(axis_spi_to_wb_tready),
	.axis_o_tvalid(axis_spi_to_wb_tvalid),
	.axis_o_tdata (axis_spi_to_wb_tdata),

	.sck(sck),
	.miso(miso),
	.mosi(mosi)
);

endmodule
