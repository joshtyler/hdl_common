// Copyright (C) 2021 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the
//  Open Hardware Description License, v. 1.0. If a copy
//  of the OHDL was not distributed with this file, You
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

// Send data over a GMII Interface
// Data is presented in synchrnous clock domain
// Pads if necessary
// Adds on CRC
// And enforces IPG

`include "axis/axis.h"
`include "axis/utility.h"

module gmii_tx_mac
#(
	parameter integer AXIS_BYTES = 1
)
(
	// This is the clock that the data will be transmitted on
	// AXIS is synchronous to this
	input logic clk,
	input logic sresetn,

	// This port must not de-assert valid for a whole packet
	// (E.g. be the output from the packet FIFO)
	// Must also be packed
	`S_AXIS_PORT_NO_USER(axis_i, AXIS_BYTES),

	output logic [7:0] eth_txd,
	output logic       eth_txen,
	output logic       eth_txer
);

function [31:0] crc32;
	input [31:0] crc;
	input [7:0] data;
	begin
	// BEGIN CRC CODE ADAPTED FROM OutputLogic.com. N.B. license header

	//-----------------------------------------------------------------------------
	// Copyright (C) 2009 OutputLogic.com
	// This source file may be used and distributed without restriction
	// provided that this copyright statement is not removed from the file
	// and that any derivative work contains the original copyright notice
	// and the associated disclaimer.
	//
	// THIS SOURCE FILE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS
	// OR IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
	// WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
	//-----------------------------------------------------------------------------
	// CRC module for data[7:0] ,   crc[31:0]=1+x^1+x^2+x^4+x^5+x^7+x^8+x^10+x^11+x^12+x^16+x^22+x^23+x^26+x^32;
	//-----------------------------------------------------------------------------

		crc32[0] = crc[24] ^ crc[30] ^ data[0] ^ data[6];
		crc32[1] = crc[24] ^ crc[25] ^ crc[30] ^ crc[31] ^ data[0] ^ data[1] ^ data[6] ^ data[7];
		crc32[2] = crc[24] ^ crc[25] ^ crc[26] ^ crc[30] ^ crc[31] ^ data[0] ^ data[1] ^ data[2] ^ data[6] ^ data[7];
		crc32[3] = crc[25] ^ crc[26] ^ crc[27] ^ crc[31] ^ data[1] ^ data[2] ^ data[3] ^ data[7];
		crc32[4] = crc[24] ^ crc[26] ^ crc[27] ^ crc[28] ^ crc[30] ^ data[0] ^ data[2] ^ data[3] ^ data[4] ^ data[6];
		crc32[5] = crc[24] ^ crc[25] ^ crc[27] ^ crc[28] ^ crc[29] ^ crc[30] ^ crc[31] ^ data[0] ^ data[1] ^ data[3] ^ data[4] ^ data[5] ^ data[6] ^ data[7];
		crc32[6] = crc[25] ^ crc[26] ^ crc[28] ^ crc[29] ^ crc[30] ^ crc[31] ^ data[1] ^ data[2] ^ data[4] ^ data[5] ^ data[6] ^ data[7];
		crc32[7] = crc[24] ^ crc[26] ^ crc[27] ^ crc[29] ^ crc[31] ^ data[0] ^ data[2] ^ data[3] ^ data[5] ^ data[7];
		crc32[8] = crc[0] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[28] ^ data[0] ^ data[1] ^ data[3] ^ data[4];
		crc32[9] = crc[1] ^ crc[25] ^ crc[26] ^ crc[28] ^ crc[29] ^ data[1] ^ data[2] ^ data[4] ^ data[5];
		crc32[10] = crc[2] ^ crc[24] ^ crc[26] ^ crc[27] ^ crc[29] ^ data[0] ^ data[2] ^ data[3] ^ data[5];
		crc32[11] = crc[3] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[28] ^ data[0] ^ data[1] ^ data[3] ^ data[4];
		crc32[12] = crc[4] ^ crc[24] ^ crc[25] ^ crc[26] ^ crc[28] ^ crc[29] ^ crc[30] ^ data[0] ^ data[1] ^ data[2] ^ data[4] ^ data[5] ^ data[6];
		crc32[13] = crc[5] ^ crc[25] ^ crc[26] ^ crc[27] ^ crc[29] ^ crc[30] ^ crc[31] ^ data[1] ^ data[2] ^ data[3] ^ data[5] ^ data[6] ^ data[7];
		crc32[14] = crc[6] ^ crc[26] ^ crc[27] ^ crc[28] ^ crc[30] ^ crc[31] ^ data[2] ^ data[3] ^ data[4] ^ data[6] ^ data[7];
		crc32[15] = crc[7] ^ crc[27] ^ crc[28] ^ crc[29] ^ crc[31] ^ data[3] ^ data[4] ^ data[5] ^ data[7];
		crc32[16] = crc[8] ^ crc[24] ^ crc[28] ^ crc[29] ^ data[0] ^ data[4] ^ data[5];
		crc32[17] = crc[9] ^ crc[25] ^ crc[29] ^ crc[30] ^ data[1] ^ data[5] ^ data[6];
		crc32[18] = crc[10] ^ crc[26] ^ crc[30] ^ crc[31] ^ data[2] ^ data[6] ^ data[7];
		crc32[19] = crc[11] ^ crc[27] ^ crc[31] ^ data[3] ^ data[7];
		crc32[20] = crc[12] ^ crc[28] ^ data[4];
		crc32[21] = crc[13] ^ crc[29] ^ data[5];
		crc32[22] = crc[14] ^ crc[24] ^ data[0];
		crc32[23] = crc[15] ^ crc[24] ^ crc[25] ^ crc[30] ^ data[0] ^ data[1] ^ data[6];
		crc32[24] = crc[16] ^ crc[25] ^ crc[26] ^ crc[31] ^ data[1] ^ data[2] ^ data[7];
		crc32[25] = crc[17] ^ crc[26] ^ crc[27] ^ data[2] ^ data[3];
		crc32[26] = crc[18] ^ crc[24] ^ crc[27] ^ crc[28] ^ crc[30] ^ data[0] ^ data[3] ^ data[4] ^ data[6];
		crc32[27] = crc[19] ^ crc[25] ^ crc[28] ^ crc[29] ^ crc[31] ^ data[1] ^ data[4] ^ data[5] ^ data[7];
		crc32[28] = crc[20] ^ crc[26] ^ crc[29] ^ crc[30] ^ data[2] ^ data[5] ^ data[6];
		crc32[29] = crc[21] ^ crc[27] ^ crc[30] ^ crc[31] ^ data[3] ^ data[6] ^ data[7];
		crc32[30] = crc[22] ^ crc[28] ^ crc[31] ^ data[4] ^ data[7];
		crc32[31] = crc[23] ^ crc[29] ^ data[5];
	// END CRC CODE ADAPTED FROM OutputLogic.com (and end applicability of license header)
	end
endfunction

	assign eth_txer = 0;

	logic [2:0] state, next_state;
	localparam [2:0] SM_WAIT_VALID = 3'b000;
	localparam [2:0] SM_PREAMBLE   = 3'b001;
	localparam [2:0] SM_SFD        = 3'b010;
	localparam [2:0] SM_DATA       = 3'b011;
	localparam [2:0] SM_CRC        = 3'b100;
	localparam [2:0] SM_IPG        = 3'b101;


	// We can share for multiple things
	// The highest that it needs to count is up to 63 to check we have sent enough data bytes and don't have to pad
	// clog2(64) == 6
	logic [5:0] ctr;

//	`STATIC_ASSERT(AXIS_BYTES <= 2**6) // Otherwise counter won't fit. No point making generic because this is outrageously wide!
//	`STATIC_ASSERT(AXIS_BYTES % 2 ==0) // Otherwise our counter slicing trick does not work

	// Flags, see state machine
	logic length_ok;
	logic last_byte_sent;

	logic [31:0] crc;
	// TODO: Can we modify the poly to do away with this silly bit reversal and inversion?
	logic [31:0] crc_inv_rev;
	`BIT_REVERSE_FUNCTION(bit_reverse_32, 32)
	assign crc_inv_rev = ~bit_reverse_32(crc);


	// Width convert separately and register output. It makes the timing better than handling inline
	// We know these blocks are 100% throughput capable, so they won't insert wait cycles into the stream
	`AXIS_INST_NO_USER(axis_narrow, 1);
	axis_width_converter
	#(
		.AXIS_I_BYTES(AXIS_BYTES),
		.AXIS_O_BYTES(1)
	) width_converter (
		.clk(clk),
		.sresetn(sresetn),

		`AXIS_MAP_NO_USER(axis_i, axis_i),
		`AXIS_MAP_NO_USER(axis_o, axis_narrow)
	);
	`AXIS_INST_NO_USER(axis_narrow_reg, 1);
	axis_register
	#(
		.AXIS_BYTES(1)
	) width_conv_register (
		.clk(clk),
		.sresetn(sresetn),

		`AXIS_MAP_NULL_USER(axis_i, axis_narrow),
		`AXIS_MAP_IGNORE_USER(axis_o, axis_narrow_reg)
	);

	logic [7:0] axis_narrow_reg_tdata_rev;
	`BIT_REVERSE_FUNCTION(bit_reverse_8, 8)
	assign axis_narrow_reg_tdata_rev = bit_reverse_8(axis_narrow_reg_tdata);

	assign axis_narrow_reg_tready = (state == SM_DATA);

	// I wouldn't normally use a two block state machine, but in this case it is handy to reset the counter to zero on state transition
	always @(posedge clk)
	begin
		state <= next_state;
		eth_txen <= 0;

		// Reset the counter on state transition, otherwise increment unconditoinally
		if(next_state != state)
		begin
			ctr <= 0;
		end else begin
			ctr <= ctr+1;
		end

		// Check if we have transmitted enough data to avoid padding
		// No need to hide this in the block for the state becuase the previous counters don't count nearly this high
		// 64 bytes is the minimum, but we transmit on zero, and length_ok needs to be high on the last beat
		// Therefore check against 62
		if(ctr[5:1] == '1)
		begin
			length_ok <= 1;
		end

		// Latch when the last byte has been sent
		// This means we can send data and pad in the same state
		if(axis_i_tready && axis_i_tlast)
		begin
			last_byte_sent <= 1;
		end

		case(state)
			// Wait for a packet to be ready to be sent
			// Reset our flags in this state
			SM_WAIT_VALID:
			begin
				length_ok <= 0;
				last_byte_sent <= 0;
				crc <= '1;
			end
			// Send preamble bytes
			SM_PREAMBLE:
			begin
				eth_txen <= 1;
				eth_txd <= 8'h55;
			end
			// Send SFD
			SM_SFD:
			begin
				eth_txen <= 1;
				eth_txd <= 8'hD5;
			end
			// Send data bytes (or garbage padding)
			SM_DATA:
			begin
				eth_txen <= 1;
				eth_txd <= axis_narrow_reg_tdata;
				crc <= crc32(crc, axis_narrow_reg_tdata_rev);
			end
			// Send the CRC
			SM_CRC:
			begin
				eth_txen <= 1;
				// verilator lint_off WIDTH
				eth_txd <= crc_inv_rev[(ctr[1:0]+1)*8-1 -: 8];
				// verilator lint_on WIDTH
			end
			// SM_IPG is here and waits for the IPG before going back around the loop
			default: eth_txen <= 0; // Do nothing, but empty default is illegal
		endcase

		if (sresetn == 0)
		begin
			state <= SM_WAIT_VALID;
		end
	end

	always_comb
	begin
		next_state = state;
		case(state)
			SM_WAIT_VALID: if(axis_i_tvalid) next_state = SM_PREAMBLE;
			// There are 7 bytes of preamble, but we send 1 on zero, so count up to 6
			SM_PREAMBLE: if(ctr[2:0] == 6) next_state = SM_SFD;
			SM_SFD: next_state = SM_DATA;
			// Progress to CRC when we have sent at least the minimum number of bytes and either:
				// We previously send the last byte (we are currently padding)
				// This is currently the last byte (no padding needed)
			SM_DATA: if(length_ok && (last_byte_sent || (axis_i_tready && axis_i_tlast))) next_state = SM_CRC;
			SM_CRC: if(ctr[1:0] == '1) next_state = SM_IPG;
			// The standard IPG is 96 bit times == 12 clock periods (since we are synchronous to the phy at one byte wide)
			// We check against 10 because we have a zero indexed counter and we will wait for one more clock cycle in SM_WAIT_VALID
			SM_IPG:	if(ctr[3:0] == 10) next_state = SM_WAIT_VALID;
			// Unreachable
			default: next_state = SM_WAIT_VALID;
		endcase
	end

endmodule
