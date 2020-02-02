module simple_wb_slave
#( // Yosys doesn't currently support using the parameters in wb (e.g. wb.BYTES)
	parameter BYTES = 1,
	parameter ADDR_BITS = 8
) (
	input logic clk,
	input logic sresetn,

	wishbone.slave wb,

	output logic [(2**ADDR_BITS)*BYTES-1:0]  regs, // Yosys doesn't support 2D arrays in ports
	output logic [7:0] leds
);

assign regs = '0;

//logic [wb.BYTES*8-1:0] regs_packed [2**wb.ADDR_BITS-1:0];
logic [1*BYTES-1:0] regs_packed [2**ADDR_BITS-1:0];

always_ff @(posedge clk)
begin
	if (wb.stb && wb.we)
	begin
		leds <= wb.dat_m2s; // TEMP assignment
	end

	//wb.dat_s2m <= regs[7:0]; // TEMP assignment

	// Acknowledge reads
	wb.ack <= wb.stb;
end

//assign leds = regs[7:0];

// We never need to stall
assign wb.stall = 0;

endmodule
