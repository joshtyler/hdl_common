// Repeatedly output a byte vector as an AXI stream

module vector_to_axis
#(
	parameter VEC_BYTES = 1,
	parameter AXIS_BYTES = 1,
	parameter MSB_FIRST = 0
) (
	input clk,
	input sresetn,

	input [(VEC_BYTES*8)-1:0] vec,

	// Output
	input axis_tready,
	output axis_tvalid,
	output axis_tlast,
	output [(AXIS_BYTES*8)-1:0] axis_tdata
);

// The vector must be a multiple of AXIS_BYTES
//assert VEC_BYTES % AXIS_BYTES = 0;

localparam integer CTR_MAX = (VEC_BYTES/AXIS_BYTES) -1;

localparam integer CTR_WIDTH = CTR_MAX == 0? 1 : $clog2(CTR_MAX +1);

reg [CTR_WIDTH-1 : 0] ctr;

always @(posedge clk)
begin
	if (sresetn == 0)
	begin
		ctr <= 0;
	end else begin
		if (axis_tready == 1)
		begin
			if (ctr == CTR_MAX[CTR_WIDTH-1:0])
			begin
				ctr <= 0;
			end else begin
				ctr <= ctr + 1;
			end
		end
	end
end

assign axis_tvalid = sresetn; // Valid whenver not in reset
assign axis_tlast = (ctr == CTR_MAX[CTR_WIDTH-1:0]);

/* verilator lint_off WIDTH */
generate
	if (MSB_FIRST)
	begin
		always @(*)
			axis_tdata = vec[ (((CTR_MAX[CTR_WIDTH-1:0]-ctr)+1)*AXIS_BYTES*8)-1 -: AXIS_BYTES*8];
	end else begin
		always @(*)
			axis_tdata = vec[ ((ctr+1)*AXIS_BYTES*8)-1 -: AXIS_BYTES*8];
	end
endgenerate
/* verilator lint_on WIDTH */

endmodule
