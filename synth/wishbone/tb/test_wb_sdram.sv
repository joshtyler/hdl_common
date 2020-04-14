`timescale 1ns/1ps

module test_wb_sdram;

logic clk = 0;
always
begin
	clk = !clk;
	#10;
end



logic sresetn;
reset_gen
#(
	.POLARITY(0)
) reset_gen_inst (
	.clk(clk),
	.en(1'b1),
	.sreset(sresetn)
);


parameter ROW_ADDR_BITS = 12;
parameter COL_ADDR_BITS = 9;
parameter BANK_SEL_BITS = 2;
parameter DATA_BYTES = 2;
parameter CLK_RATE      = 50e6;
parameter T_RC_s        = 60e-9;
parameter T_RP_s        = 15e-9;
parameter T_CL          = 3;
parameter T_RSC         = 2;
parameter REFRSH_PERIOD = 64e-3;
parameter T_RAS_min_s   = 42e-9;
parameter T_RAS_max_s   = 99800e-9;
parameter T_RCD_s       = 15e-9;
parameter WB_ADDR_BITS = BANK_SEL_BITS+ROW_ADDR_BITS+COL_ADDR_BITS;


logic [ROW_ADDR_BITS-1:0] ram_a;
logic [BANK_SEL_BITS-1:0] ram_bs;
logic [DATA_BYTES*8-1:0]  ram_dq_o;
logic                     ram_dq_oe;
logic [DATA_BYTES*8-1:0]  ram_dq_i;
logic                     ram_cs_n;
logic                     ram_ras_n;
logic                     ram_cas_n;
logic                     ram_we_n;
logic [DATA_BYTES-1:0]    ram_dqm_n;
logic                     ram_cke;

logic [WB_ADDR_BITS-1:0] s_wb_addr;
logic [DATA_BYTES*8-1:0] s_wb_dat_m2s;
logic [DATA_BYTES*8-1:0] s_wb_dat_s2m;
logic                    s_wb_we;
logic                    s_wb_stb;
logic                    s_wb_ack;
logic                    s_wb_stall;

wb_sdram
#(
	.ROW_ADDR_BITS(ROW_ADDR_BITS),
	.COL_ADDR_BITS(COL_ADDR_BITS),
	.BANK_SEL_BITS(BANK_SEL_BITS),
	.DATA_BYTES   (DATA_BYTES   ),
	.CLK_RATE     (CLK_RATE     ),
	.T_RC_s       (T_RC_s       ),
	.T_RP_s       (T_RP_s       ),
	.T_CL         (T_CL         ),
	.T_RSC        (T_RSC        ),
	.REFRSH_PERIOD(REFRSH_PERIOD),
	.T_RAS_min_s  (T_RAS_min_s  ),
	.T_RCD_s      (T_RCD_s      ),
	. WB_ADDR_BITS( WB_ADDR_BITS)
) uut (
	.clk(clk),
	.sresetn(sresetn),

	.s_wb_addr(s_wb_addr),
	.s_wb_dat_m2s(s_wb_dat_m2s),
	.s_wb_dat_s2m(s_wb_dat_s2m),
	.s_wb_we(s_wb_we),
	.s_wb_stb(s_wb_stb),
	.s_wb_ack(s_wb_ack),
	.s_wb_stall(s_wb_stall),

	.ram_a    (ram_a),
	.ram_bs   (ram_bs),
	.ram_dq_o (ram_dq_o),
	.ram_dq_oe(ram_dq_oe),
	.ram_dq_i (ram_dq_i),
	.ram_cs_n (ram_cs_n),
	.ram_ras_n(ram_ras_n),
	.ram_cas_n(ram_cas_n),
	.ram_we_n (ram_we_n),
	.ram_dqm_n(ram_dqm_n),
	.ram_cke  (ram_cke)
);

// Really dumb stimulus
// Assumes that the uut will always be ready etc(!)
initial
begin
	s_wb_addr = '0;
	s_wb_dat_m2s = '0;
	s_wb_we = 0;
	s_wb_stb = 0;

	$dumpfile("uut.vcd");
	$dumpvars(0,test_wb_sdram);
	#200000ns;

	// Test write
	@(posedge clk)

	s_wb_dat_m2s = 16'h5555;
	s_wb_we = 1;
	s_wb_stb = 1;
	@(posedge clk)
	s_wb_stb = 0;

	// Test write
	//@(posedge clk)
	s_wb_addr = 23'd832;
	s_wb_dat_m2s = 16'hABCD;
	s_wb_we = 1;
	s_wb_stb = 1;
	@(posedge clk)
	s_wb_stb = 0;

	// Test read
	//@(posedge clk)
	s_wb_addr = '0;
	s_wb_we = 0;
	s_wb_stb = 1;
	@(posedge clk)
	s_wb_stb = 0;

	// Test read
	//@(posedge clk)
	s_wb_addr = 23'd832;
	s_wb_we = 0;
	s_wb_stb = 1;
	@(posedge clk)
	s_wb_stb = 0;

	#200000ns $finish;
end

wire [DATA_BYTES*8-1:0]  ram_dq;
assign ram_dq_i = ram_dq;
assign ram_dq = ram_dq_oe? ram_dq_o : 'z;

mt48lc16m16a2 ram_inst
(
	.Dq    (ram_dq),
	.Addr  (ram_a),
	.Ba    (ram_bs),
	.Clk   (clk),
	.Cke   (ram_cke),
	.Cs_n  (ram_cs_n),
	.Ras_n (ram_ras_n),
	.Cas_n (ram_cas_n),
	.We_n  (ram_we_n),
	.Dqm   (ram_dqm_n)
);


endmodule
