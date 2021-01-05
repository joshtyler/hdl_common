// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │
//  Open Hardware Description License, v. 1.0. If a copy                                                    │
//  of the OHDL was not distributed with this file, You                                                     │
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

// Receive data over a GMII Interface
// Present to the user in a different clock domain
// Strips preamble from input

// At the moment this block assumes that the phy has been correctly configured for, and has negotiated gigabit speeds
// Could add in the MDIO bus to check/configure this in the future

`include "axis/axis.h"
`include "axis/utility.h"

module gmii_rx_mac_async
#(
	parameter integer AXIS_BYTES = 1
	parameter integer MTU_SIZE = 1522 // Used to size FIFO
)
(
	input logic eth_clk,
	input logic eth_sresetn,

	input  logic [7:0] eth_rxd,
	input  logic       eth_rxdv,
	input  logic       eth_rxer,

	input logic axis_clk,
	input logic axis_sresetn,

	`M_AXIS_PORT_NO_USER(axis_o, AXIS_BYTES)
);

	// Delay data and valid by one cycle
	// This lets us use the negation of valid as a last signal as a last
	logic [7:0] rx_data;
	logic rx_valid;
	logic rx_error;
	logic rx_last;
	always_ff @ (posedge eth_rxclk)
	begin
		rx_data  <= eth_rxd;
		rx_valid <= eth_rxdv;
		rx_error <= eth_rxer;
	end
	assign rx_last = !eth_rxdv;


	// Detect and strip the preamble
	// Pack the remaining data into the width requested by the user
	// We can't use the axis_width converter here because we need to handle the error signal
	// But since there is no flow control, packing is quite easy
	logic [1:0] state;
	localparam [1:0] SM_WAIT_INVALID = 2'b00;
	localparam [1:0] SM_PREAMBLE     = 2'b01;
	localparam [1:0] SM_SFD          = 2'b10;
	localparam [1:0] SM_OUTPUT       = 2'b11;

	localparam REG_CTR_WIDTH = (AXIS_BYTES == 1)? 1: $clog2(AXIS_BYTES);
	localparam [REG_CTR_WIDTH-1:0] REG_CTR_MAX;
	logic [REG_CTR_WIDTH-1:0] ctr;

	logic fifo_in_valid;
	logic fifo_in_last;
	logic [(8*AXIS_BYTES)-1 : 0] fifo_in_data;
	logic [AXIS_BYTES-1 : 0] fifo_in_keep;
	logic fifo_in_error;

	always @(posedge eth_clk)
	begin
		if (eth_sresetn == 0)
		begin
			state <= SM_WAIT_INVALID;
		end else begin
				axis_fifo_tvalid <= 0;

			case(state)
				// Wait until input is invalid (i.e the next valid word will be preamble for a new packet)
				SM_WAIT_INVALID:
				begin
					ctr <= 0;
					if(!rx_valid)
					begin
						state <= SM_PREAMBLE
					end
				end

				// Waits for a packet to begin, and enforces that the first word is preamble
				SM_PREAMBLE:
				begin
					if(rx_valid)
					begin
						if(rx_data = 8'bAA)
						begin
							state <= SM_SFD
						end else begin
							// We didn't get what we were expecting, reset
							state <= SM_WAIT_INVALID;
						end
					end
				end

				// Enforces that every beat is valid and is preamble
				// Waits for the start of frame delimiter
				SM_SFD:
				begin
					if(rx_valid && (rx_data = 8'bAB))
					begin
						state <= SM_OUTPUT
					end else if((!rx_valid) || (rx_data != 8'bAA)) begin
						// We didn't get what we were expecting, reset
						state <= SM_WAIT_INVALID;
					end
				end

				// Outputs data (packed into the user requested size)
				SM_OUTPUT:
				begin
					fifo_in_last  <= rx_last;
					fifo_in_data[(ctr+1)*8-1 -: 8]  <= rx_data;
					fifo_in_error <= rx_error;
					fifo_in_valid <= rx_last || rx_error || (ctr == REG_CTR_MAX);

					// On a new word, clear out the whole keep, otherwise just set the appropriate bit
					if ctr == 0 begin
						fifo_in_keep <= 1;
					end else begin
						fifo_in_keep[ctr] <= 1'b1;
					end

					// The (!rx_valid) shouldn't be needed
					// We have it just in case last was asserted during SM_SFD
					if(rx_last || (!rx_valid) || rx_error) begin
					begin
						// It is the end of a packet, go and wait for the next preamble
						state <= SM_PREAMBLE;
					end

					if(ctr == REG_CTR_MAX)
					begin
						ctr <= 0;
					end
				end
			endcase
		end
	end

	// TODO: Check CRC

	axis_error_filter_async
	#(
		.AXIS_BYTES(1),
		.LOG2_DEPTH($clog2(MTU_SIZE))
	) fifo (
		.i_clk(eth_clk),
		.i_sresetn(eth_sresetn),

		.o_clk(axis_clk),
		.o_sresetn(axis_sresetn),

		.i_valid(fifo_in_valid),
		.i_last(fifo_in_last),
		.i_keep(fifo_in_keep),
		.i_data(fifo_in_data),
		.i_user(1'b1),
		.i_error(fifo_in_error),

		`AXIS_MAP_IGNORE_USER(axis_o, axis_o)
	);


endmodule
