// Cross clock packet FIFO
// Works by pointer passing in both directions
// Could modify in the future to use grey code in the reverse direction for performance

module axis_packet_fifo_async
#(
	parameter AXIS_BYTES = 2,
	parameter AXIS_USER_BITS = 1,
	parameter LOG2_DEPTH = 15
) (
	input i_clk,
	input i_sresetn,

	input o_clk,
	input o_sresetn,

	output logic                      axis_i_tready,
	input  logic                      axis_i_tvalid,
	input  logic                      axis_i_tlast,
	input  logic [(AXIS_BYTES*8)-1:0] axis_i_tdata,
	input  logic [AXIS_USER_BITS-1:0] axis_i_tuser,
	input  logic                      axis_i_drop,

	input  logic                      axis_o_tready,
	output logic                      axis_o_tvalid,
	output logic                      axis_o_tlast,
	output logic [(AXIS_BYTES*8)-1:0] axis_o_tdata,
	output logic [AXIS_USER_BITS-1:0] axis_o_tuser
);
	// Data is tdata+tuser+tlast
	localparam DATA_WIDTH = 8*AXIS_BYTES+AXIS_USER_BITS+1;

	logic [DATA_WIDTH-1:0] mem [2**LOG2_DEPTH-1:0];

	// Extra bit allows us to detect full/empty
	// Alternatively we can make the fifo be 2**depth-1, but that's boring
	logic [LOG2_DEPTH:0] rdptr_iclk, wrptr_iclk, committed_wrptr_iclk, rdptr_oclk, wrptr_oclk;


	cdc_vector
	#(
		.WIDTH(LOG2_DEPTH+1)
	) wrptr_i_to_o (
		.iclk(i_clk),
		.oclk(o_clk),
		.i_tvalid(1'b1),
		.i(committed_wrptr_iclk),
		.o(wrptr_oclk)
	);

	cdc_vector
	#(
		.WIDTH(LOG2_DEPTH+1)
	) rdptr_o_to_i (
		.iclk(o_clk),
		.oclk(i_clk),
		.i_tvalid(1'b1),
		.i(rdptr_oclk),
		.o(rdptr_iclk)
	);


	// When the address part matches, but the top bit doesn't we are full
	assign axis_i_tready = !((rdptr_iclk[LOG2_DEPTH-1:0] == wrptr_iclk[LOG2_DEPTH-1:0]) && (rdptr_iclk[LOG2_DEPTH] != wrptr_iclk[LOG2_DEPTH]));

	always_ff @(posedge i_clk)
	begin
		if(!i_sresetn)
		begin
			committed_wrptr_iclk <= '0;
			wrptr_iclk <= '0;
		end else begin
			if(axis_i_tready && axis_i_tvalid)
			begin
				mem[wrptr_iclk[LOG2_DEPTH-1:0]] <= {axis_i_tlast, axis_i_tdata, axis_i_tuser};
				wrptr_iclk <= wrptr_iclk +1;

				if(axis_i_drop)
				begin
					// Reset to the beginning of the packet
					wrptr_iclk <= committed_wrptr_iclk;
				end else begin
					if(axis_i_tlast)
					begin
						// We have a whole packet, commit the pointer
						committed_wrptr_iclk <= wrptr_iclk;
					end
				end
			end
		end
	end

	always_ff @(posedge o_clk)
	begin
		if(!o_sresetn)
		begin
			rdptr_oclk <= '0;
		end else begin
			// If we read, invalidate the output data
			if(axis_o_tready)
			begin
				axis_o_tvalid <= 0;
			end

			// Read if the FIFO is not empty
			// And either the output word is invalid, or we are reading in this cycle
			if ((rdptr_oclk != wrptr_oclk) && ((!axis_o_tvalid) || axis_o_tready))
			begin
				{axis_o_tlast, axis_o_tdata, axis_o_tuser} <= mem[rdptr_oclk[LOG2_DEPTH-1:0]];
				axis_o_tvalid <= 1;
				rdptr_oclk <= rdptr_oclk + 1;
			end
		end
	end

endmodule
