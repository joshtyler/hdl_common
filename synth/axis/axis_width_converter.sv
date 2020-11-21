// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │
//  Open Hardware Description License, v. 1.0. If a copy                                                    │
//  of the OHDL was not distributed with this file, You                                                     │
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

// Unpack a wide AXIS stream into a narrow one
// Or pack a narrow stream into a wide one
// N.B. The wider stream must be an exact multiple of the width of the smaller stream
// (Guaranteed with standard axis widths)

`include "axis/axis.h"

module axis_width_converter
#(
	parameter AXIS_I_BYTES = 1,
	parameter AXIS_O_BYTES = 1,
	parameter MSB_FIRST = 0
) (
	input clk,
	input sresetn,

	`S_AXIS_PORT_NO_USER(axis_i, AXIS_I_BYTES),
	`M_AXIS_PORT_NO_USER(axis_o, AXIS_O_BYTES)
);
	generate
		if (AXIS_I_BYTES == AXIS_O_BYTES) begin
			// Simple pass through
			assign axis_i_tready = axis_o_tready;
			assign axis_o_tvalid = axis_i_tvalid;
			assign axis_o_tlast = axis_i_tlast;
			assign axis_o_tdata = axis_i_tdata;
		end else begin
			//assert property (@(posedge clk) AXIS_I_BYTES >= AXIS_O_BYTES);
			//assert property (@(posedge clk) AXIS_I_BYTES % AXIS_O_BYTES == 0);

			localparam integer AXIS_W_BYTES = AXIS_I_BYTES > AXIS_O_BYTES? AXIS_I_BYTES : AXIS_O_BYTES;
			localparam integer AXIS_N_BYTES = AXIS_I_BYTES > AXIS_O_BYTES? AXIS_O_BYTES : AXIS_I_BYTES;

			localparam integer CTR_MAX = (AXIS_W_BYTES / AXIS_N_BYTES);

			localparam integer CTR_WIDTH = CTR_MAX == 1? 1 : $clog2(CTR_MAX);
		/* verilator lint_off WIDTH */
			localparam CTR_HIGH = CTR_MAX-1;


			reg [1:0] state;
			localparam CAPTURE = 2'b00;
			localparam OUTPUT = 2'b01;

			reg [CTR_WIDTH-1:0] ctr;

			reg axis_i_tlast_latch;
			reg [(AXIS_W_BYTES*8)-1:0] axis_i_tdata_latch;

			assign axis_i_tready = (state == CAPTURE);
			assign axis_o_tvalid = (state == OUTPUT);
			assign axis_o_tlast = (ctr == CTR_HIGH) && axis_i_tlast_latch;


			if (AXIS_I_BYTES > AXIS_O_BYTES) begin
				// Unpacker
				if (MSB_FIRST) begin
					assign axis_o_tdata = axis_i_tdata_latch[((CTR_HIGH-ctr)+1)*(AXIS_O_BYTES*8)-1 -: (AXIS_O_BYTES*8)];
				end else begin
					assign axis_o_tdata = axis_i_tdata_latch[(ctr+1)*(AXIS_O_BYTES*8)-1 -: (AXIS_O_BYTES*8)];
				end

				always @(posedge clk)
				begin
					if (sresetn == 0)
					begin
						state <= CAPTURE;
					end else begin
						case(state)
							CAPTURE: begin
								if (axis_i_tvalid) begin
									state <= OUTPUT;
									ctr <= 0;
									axis_i_tdata_latch <= axis_i_tdata;
									axis_i_tlast_latch <= axis_i_tlast;
								end
							end
							OUTPUT: begin
								if (axis_o_tready) begin
									ctr <= ctr + 1;
									if(ctr == CTR_HIGH) begin
										state <= CAPTURE;
										axis_i_tlast_latch <= 0;
									end
								end
							end
						default : state <= CAPTURE;
						endcase;
					end
				end
			end else begin
				// Packer
				assign axis_o_tdata = axis_i_tdata_latch;

				always @(posedge clk)
				begin
					if (sresetn == 0)
					begin
						state <= CAPTURE;
						ctr <= 0;
						axis_i_tdata_latch <= 0;
					end else begin
						case(state)
							CAPTURE: begin
								if (axis_i_tvalid) begin
									if (ctr == CTR_HIGH) begin
										state <= OUTPUT;
									end else begin
										ctr <= ctr + 1;
									end
									if (MSB_FIRST) begin
										axis_i_tdata_latch[((CTR_HIGH-ctr)+1)*(AXIS_I_BYTES*8)-1 -: (AXIS_I_BYTES*8)] <= axis_i_tdata;
									end else begin
										axis_i_tdata_latch[(ctr+1)*(AXIS_I_BYTES*8)-1 -: (AXIS_I_BYTES*8)] <= axis_i_tdata;
									end
									// The special case is if we get tlast early
									// If this is the case, we go to output anyway, the upper bits will be zeroes
									// We need to set the counter to CTR_HIGH in order to make axis_o_tlast work correctly
									if (axis_i_tlast) begin
										axis_i_tlast_latch <= 1;
										ctr <= CTR_HIGH;
										state <= OUTPUT;
									end
								end
							end
							OUTPUT: begin
								if (axis_o_tready) begin
									ctr <= 0;
									state <= CAPTURE;
									axis_i_tdata_latch <= 0;
									axis_i_tlast_latch <= 0;
								end
							end
						default : state <= CAPTURE;
						endcase;
					end
				end
			end
		end
	endgenerate
endmodule
	/* verilator lint_on WIDTH */
