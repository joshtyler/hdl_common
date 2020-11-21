// Copyright (C) 2020 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the
//  Open Hardware Description License, v. 1.0. If a copy
//  of the OHDL was not distributed with this file, You
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

`include "axis/axis.h"

module axis_packet_fifo
#(
	parameter AXIS_BYTES = 1,
	parameter AXIS_USER_BITS = 1,
	parameter LOG2_DEPTH = 8
) (
	input clk,
	input sresetn,

	`S_AXIS_PORT(axis_i, AXIS_BYTES, AXIS_USER_BITS),
	input  logic                      axis_i_drop,

	`M_AXIS_PORT(axis_o, AXIS_BYTES, AXIS_USER_BITS)
);
// Theory of operation:
// Similar to axis_fifo, but we we store the write pointer until we see last
// Only at this point do we commit it over the previous write pointer
// N.B. We currenly lock up if we fill up. This is different to the Xilinx core
// We also offer the ability to invalidate a packet, in this case we reset to the previous pointer

// Data is tdata+tuser+tlast
localparam DATA_WIDTH = 8*AXIS_BYTES+AXIS_USER_BITS+1;

logic [DATA_WIDTH-1:0] mem [2**LOG2_DEPTH-1:0];

// Extra bit allows us to detect full/empty
// Alternatively we can make the fifo be 2**depth-1, but that's boring
logic [LOG2_DEPTH:0] rd_ptr, wr_ptr, committed_wr_ptr;

// When the address part matches, but the top bit doesn't we are full
logic full;
assign full = (rd_ptr[LOG2_DEPTH-1:0] == wr_ptr[LOG2_DEPTH-1:0]) && (rd_ptr[LOG2_DEPTH] != wr_ptr[LOG2_DEPTH]);
assign axis_i_tready = (!full) || axis_i_drop;

logic drop;
always_ff @(posedge clk)
begin
	if(!sresetn)
	begin
		wr_ptr <= 0;
		rd_ptr <= 0;
		axis_o_tvalid <= 0;
		committed_wr_ptr <= 0;
		drop <= 0;
	end else begin
		// Write if we are able
		if (axis_i_tready && axis_i_tvalid)
		begin
			// Latch the drop flag
			drop <= axis_i_drop? 1'b1 : drop;

			// Only save data if we are not dicarding
			// Else reset to our last committed write pointer
			if(drop || axis_i_drop)
			begin
				wr_ptr <= committed_wr_ptr;
			end else begin
				mem[wr_ptr[LOG2_DEPTH-1:0]] <= {axis_i_tlast, axis_i_tdata, axis_i_tuser};
				wr_ptr <= wr_ptr + 1;

				if(axis_i_tlast)
				begin
					committed_wr_ptr <= wr_ptr + 1;
				end
			end

			// Clear the discard flag
			if(axis_i_tlast)
			begin
				drop <= 0;
			end
		end

		// If we read, invalidate the output data
		if(axis_o_tready)
		begin
			axis_o_tvalid <= 0;
		end

		// Read if the FIFO is not empty
		// And either the output word is invalid, or we are reading in this cycle
		if ((rd_ptr != committed_wr_ptr) && ((!axis_o_tvalid) || axis_o_tready))
		begin
			{axis_o_tlast, axis_o_tdata, axis_o_tuser} <= mem[rd_ptr[LOG2_DEPTH-1:0]];
			axis_o_tvalid <= 1;
			rd_ptr <= rd_ptr + 1;
		end
	end
end

endmodule
