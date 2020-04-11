// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the
//  Open Hardware Description License, v. 1.0. If a copy
//  of the OHDL was not distributed with this file, You
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt


// Only mode 0 for now

module axis_spi_bridge
#(
	parameter AXIS_BYTES = 1
) (
	input logic clk,
	input logic sresetn,

	// Input
	output logic                      axis_i_tready,
	input  logic                      axis_i_tvalid,
	input  logic [(AXIS_BYTES*8)-1:0] axis_i_tdata,
	input  logic [0:0]                axis_i_tuser, // If 1 discard the result, if 0 return the result

	// Output
	input  logic                      axis_o_tready,
	output logic                      axis_o_tvalid,
	output logic [(AXIS_BYTES*8)-1:0] axis_o_tdata,

	output logic sck,
	input  logic miso,
	output logic mosi
);

logic [1:0] state;
localparam SETUP    = 2'b00;
localparam TRANSFER = 2'b01;
localparam WAIT     = 2'b10;

localparam integer CTR_WIDTH = $clog2(AXIS_BYTES*8);
/* verilator lint_off WIDTH */
localparam [CTR_WIDTH-1:0]CTR_HIGH = AXIS_BYTES*8-1;
/* verilator lint_on WIDTH */
logic [CTR_WIDTH-1:0] ctr;

logic discard_result;

// Only ack when we are done with the data
//assign axis_i_tready = (state == TRANSFER) && (ctr == CTR_HIGH);

assign mosi = axis_i_tdata[CTR_HIGH-ctr]; // MSB first

assign axis_o_tvalid = (state == WAIT) && (!discard_result);

// The state machine adds two dead cycles, but keeps the logic simple
// And we're not really concerned about performance for this
always_ff @(posedge clk)
begin
	if (sresetn == 0)
	begin
		state <= SETUP;
		sck <= 0;
		ctr <= 0;
	end else begin
		axis_i_tready <= 0;
		case(state)
			SETUP : begin
				if (axis_i_tvalid) begin
					state <= TRANSFER;
					discard_result <= axis_i_tuser[0];
				end
			end
			TRANSFER: begin
				sck <= !sck; // Becomes clk/2. We could use a DDR IO block for twice throughput

				if(sck) begin
					ctr <= ctr + 1;
				end else begin
					axis_o_tdata[CTR_HIGH-ctr] <= miso; // MSB first
					if(ctr == CTR_HIGH) begin
						state <= WAIT;
						axis_i_tready <= 1;
					end
				end
			end
			WAIT: begin
				sck <= 0;
				ctr <= 0;
				if ((axis_o_tready && axis_o_tvalid) || discard_result) begin
					state <= SETUP;
				end
			end
			default:
				state <= SETUP; // Should never happen
		endcase;
	end
end


endmodule
