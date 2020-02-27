module simple_wb_slave
#( // Yosys doesn't currently support using the parameters in wb (e.g. s_wb_BYTES)
	parameter BYTES = 1,
	parameter ADDR_BITS = 8,
	parameter [(2**ADDR_BITS)*BYTES*8-1:0] INITAL_VAL = '0,
	localparam SEL_WIDTH = 1
) (
	input logic clk,
	input logic sresetn,

	/* verilator lint_off LITENDIAN */
	input  logic [ADDR_BITS-1:0] s_wb_addr   ,
	/* verilator lint_on LITENDIAN */
	input  logic [BYTES*8-1:0]   s_wb_dat_m2s,
	output logic [BYTES*8-1:0]   s_wb_dat_s2m,
	input  logic                 s_wb_we     ,
	input  logic [SEL_WIDTH-1:0] s_wb_sel    ,
	input  logic                 s_wb_stb    ,
	input  logic                 s_wb_cyc    ,
	output logic                 s_wb_ack    ,
	output logic                 s_wb_stall  ,

	output logic [(2**ADDR_BITS)*BYTES*8-1:0] regs = INITAL_VAL // Yosys doesn't support 2D arrays in ports
);

logic [(2**ADDR_BITS)*BYTES*8-1:0] reg_idx;

generate
	if (ADDR_BITS == 0)
	begin
		assign reg_idx = BYTES*8-1;
	end else begin
		assign reg_idx = (s_wb_addr+1)*BYTES*8-1;
	end
endgenerate

always_ff @(posedge clk)
begin
	if (s_wb_stb && s_wb_we)
	begin
		regs[reg_idx -: BYTES*8] <= s_wb_dat_m2s;
	end

	s_wb_dat_s2m <= regs[reg_idx -: BYTES*8];

	// Acknowledge reads
	s_wb_ack <= s_wb_stb;
end

// We never need to stall
assign s_wb_stall = 0;

endmodule
