// UDP Checksum algorithm
// "Checksum is the 16-bit one's complement
// of the one's complement sum of a pseudo header of information from
// the IP header, the UDP header, and the data,
// padded with zero octets at the end (if necessary) to make a multiple of two octets"

// This module takes the data in two bytes at a time
// And data is output two bytes at a time

module udp_checksum(
	input clk,
	input sresetn,

	// Input
	output       axis_i_tready,
	input        axis_i_tvalid,
	input        axis_i_tlast,
	input [15:0] axis_i_tdata,

	// Output
	input         axis_o_tready,
	output        axis_o_tvalid,
	output        axis_o_tlast,
	output [15:0] axis_o_tdata
);

	// Accumulator, store the current checksum result. One bit wider for overflow bit
	logic [16:0] acc;

	logic [1:0] state;
	localparam SM_RESET = 2'b00;
	localparam SM_CALC = 2'b01;
	localparam SM_DONE = 2'b10;

	always @(posedge clk) begin
		if sresetn = 0 begin
			state <= SM_RESET;
			axis_o_tvalid <= 0;
		end else begin
			case(state):
				SM_RESET: begin
					// We can proceed if the current result has been accepted
					// Or unconditoinally if the result is not valid (we have been reset)
					if(axis_o_tvalid and axis_o_tready) or !axis_o_tvalid begin
						state <= SM_CALC;
						acc <= 0;
					end
				end
				SM_CALC : begin
					if(axis_i_tready and axis_i_tvalid) begin
						// Create 16 bit sum. Add on overflow bit from prevoius calculation
						acc <= axis_i_tdata + acc[15:0] + acc[16];
						if (axis_i_tlast) begin
							state <= SM_DONE;
						end
					end
				end
				SM_DONE : begin
					// Add on final overflow bit and signal that output is valid
					acc <= acc[15:0] + acc[16];
					state <= SM_RESET;
				end
			end
		end
	end

endmodule
