interface wishbone #(parameter BYTES = 1, parameter SEL_WIDTH = 1, parameter ADDR_BITS = 8);
	/* verilator lint_off LITENDIAN */
	logic [ADDR_BITS-1 : 0] addr;
	/* verilator lint_on LITENDIAN */
	logic [(8*BYTES)-1:0] dat_m2s, dat_s2m;
	logic we, stb, ack, cyc, stall;
	logic [SEL_WIDTH-1:0] sel;

	modport master
	(
		output addr,
		output dat_m2s,
		input  dat_s2m,
		output we,
		output sel,
		output stb,
		output cyc,
		input  ack,
		input  stall

	);

	modport slave
	(
		input  addr,
		input  dat_m2s,
		output dat_s2m,
		input  we,
		input  sel,
		input  stb,
		input  cyc,
		output ack,
		output stall
	);
endinterface
