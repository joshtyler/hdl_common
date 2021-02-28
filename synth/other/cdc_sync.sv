// Register and re-register a single bit onto a different clock domain to avoid metastability
// Two ffs is enough for most designs

module cdc_sync
#(
	parameter integer STAGES = 2
) (
	input logic oclk,
	input logic i,
	output logic o
);

logic[STAGES-1:0] tmp = 0;

assign o = tmp[STAGES-1];

// Handle first ff
always_ff @(posedge oclk)
begin
	tmp[0] <= i;
end

// Handle other ffs
generate
	genvar iter;
	for(iter=1; iter<STAGES; iter++)
	begin
		always_ff @(posedge oclk)
		begin
			tmp[iter] <= tmp[iter-1];
		end
	end
endgenerate

endmodule
