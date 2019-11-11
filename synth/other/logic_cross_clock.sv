// Register and re-register a single bit onto a different clock domain
// Avoid metastability

module logic_cross_clock
#(
	parameter integer STAGES = 2
) (
	input logic clk,
	input logic i,
	output logic o
);

logic[STAGES-1:0] tmp;

always_comb
begin
	o = tmp[STAGES-1];
end

// Handle first ff
always_ff @(posedge clk)
begin
	tmp[0] <= i;
end

// Handle other ffs
generate
	genvar iter;
	for(iter=1; iter<STAGES; iter++)
	begin
		always_ff @(posedge clk)
		begin
			tmp[iter] <= tmp[iter-1];
		end
	end
endgenerate

endmodule
