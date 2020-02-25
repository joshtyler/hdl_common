module simple_wb_slave
#( // Yosys doesn't currently support using the parameters in wb (e.g. wb.BYTES)
	parameter BYTES = 1,
	parameter ADDR_BITS = 8
) (
	input logic clk,
	input logic sresetn,

	wishbone.slave wb,

	output logic [(2**ADDR_BITS)*BYTES*8-1:0]  regs // Yosys doesn't support 2D arrays in ports
);

logic [(2**ADDR_BITS)*BYTES*8-1:0] reg_idx;

generate
	if (ADDR_BITS == 0)
	begin
		assign reg_idx = BYTES*8-1;
	end else begin
		assign reg_idx = (wb.addr+1)*BYTES*8-1;
	end
endgenerate

always_ff @(posedge clk)
begin
	if (wb.stb && wb.we)
	begin
		regs[reg_idx -: BYTES*8] <= wb.dat_m2s;
	end

	wb.dat_s2m <= regs[reg_idx -: BYTES*8];

	// Acknowledge reads
	wb.ack <= wb.stb;
end

// We never need to stall
assign wb.stall = 0;

endmodule
