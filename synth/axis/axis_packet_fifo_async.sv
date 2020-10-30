// Cross clock packet FIFO
// Works by pointer passing in both directions
// Could modify in the future to use grey code in the reverse direction for performance

`include "axis.h"

module axis_packet_fifo_async
#(
	parameter AXIS_BYTES = 1,
	parameter AXIS_USER_BITS = 1,
	parameter LOG2_DEPTH = 8
) (
	input i_clk,
	input i_sresetn,

	input o_clk,
	input o_sresetn,

	`S_AXIS_PORT(axis_i, AXIS_BYTES, AXIS_USER_BITS),
	input  logic                      axis_i_drop,

	`M_AXIS_PORT(axis_o, AXIS_BYTES, AXIS_USER_BITS)
);
	// Data is tdata+tuser+tlast
	localparam DATA_WIDTH = 8*AXIS_BYTES+AXIS_USER_BITS+1;

	// Extra bit allows us to detect full/empty
	// Alternatively we can make the fifo be 2**depth-1, but that's boring
	logic [LOG2_DEPTH:0] rdptr_iclk, wrptr_iclk, committed_wrptr_iclk, rdptr_oclk, wrptr_oclk;


	cdc_vector
	#(
		.WIDTH(LOG2_DEPTH+1)
	) wrptr_i_to_o (
		.iclk(i_clk),
		.oclk(o_clk),
		.i_tready(),
		.i_tvalid(1'b1),
		.i(committed_wrptr_iclk),
		.o_strb(),
		.o(wrptr_oclk)
	);

	cdc_vector
	#(
		.WIDTH(LOG2_DEPTH+1)
	) rdptr_o_to_i (
		.iclk(o_clk),
		.oclk(i_clk),
		.i_tready(),
		.i_tvalid(1'b1),
		.i(rdptr_oclk),
		.o_strb(),
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
				wrptr_iclk <= wrptr_iclk +1;

				if(axis_i_drop)
				begin
					// Reset to the beginning of the packet
					wrptr_iclk <= committed_wrptr_iclk;
				end else begin
					if(axis_i_tlast)
					begin
						// We have a whole packet, commit the pointer
						// N.B. We commit the incremented verson of the pointer
						// This is because the write pointer is the next location to be written
						// NOT the last location that was written
						committed_wrptr_iclk <= wrptr_iclk +1;
					end
				end
			end
		end
	end

	logic read_from_ram;
	assign read_from_ram = (rdptr_oclk != wrptr_oclk) && ((!axis_o_tvalid) || axis_o_tready);
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
			if (read_from_ram)
			begin
				axis_o_tvalid <= 1;
				rdptr_oclk <= rdptr_oclk + 1;
			end
		end
	end

	// Currently we are using BRAM in a separate module because of intererence problems
	// Both in vivado and yosys(!). See git history for how this used to be
	// Could probably inline this in the future... Ideally we would fix inference in the inline version
	simple_dual_port_two_clocks
	#(
		.addr_width(LOG2_DEPTH),
		.data_width(DATA_WIDTH)
	) mem_inst (
		.clka(i_clk),
		.ena   (1'b1),
		.wea   (axis_i_tready && axis_i_tvalid),
		.addra (wrptr_iclk[LOG2_DEPTH-1:0]),
		.dia   ({axis_i_tlast, axis_i_tdata, axis_i_tuser}),

		.clkb(o_clk),
		.enb   (read_from_ram),
		.addrb (rdptr_oclk[LOG2_DEPTH-1:0]),
		.dob   ({axis_o_tlast, axis_o_tdata, axis_o_tuser})
	);

endmodule
