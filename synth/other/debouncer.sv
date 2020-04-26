// Debounce an input
// Also includes synchronisation circuitry to avoid metastability

module debouncer
#(
	parameter CLK_RATE = 50_000_000,
	parameter SETTLING_TIME_us = 10_000
) (
	input  logic clk,
	// Having a reset means we don't have to wait for the whole settling time to get initial value
	// It is assumed that the reset period is at least long enough for the input to propagate through the syncer
	input logic sresetn,

	input  logic i,
	output logic o,
	output logic change
);

logic i_sync;
logic_cross_clock crosser (.clk(clk), .i(i), .o(i_sync));

/* verilator lint_off REALCVT */
localparam integer NUM_COUNTS = (SETTLING_TIME_us*(1.0e-6))/(1.0/CLK_RATE);
/* verilator lint_on REALCVT */

localparam CTR_WIDTH = $clog2(NUM_COUNTS);

logic [CTR_WIDTH-1:0] ctr;

logic last_i;

always_ff @(posedge clk)
begin
	change <= 0;
	last_i <= i_sync;
	if(!sresetn)
	begin
		ctr <= '0;
		o <= i_sync; // So that we don't get spurious events for the initial state
	end else begin
		/* verilator lint_off WIDTH */
		if(last_i != i || (ctr == NUM_COUNTS-1))
		/* verilator lint_on WIDTH */
		begin
			ctr <= '0;
		end else begin
			ctr <= ctr + 1;
		end

		/* verilator lint_off WIDTH */
		if((ctr == NUM_COUNTS-1) && (o != i_sync))
		/* verilator lint_on WIDTH */
		begin
			o <= i_sync;
			change <= 1;
		end

	end
end

endmodule
