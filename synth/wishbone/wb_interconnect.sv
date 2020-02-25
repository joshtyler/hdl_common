// Simple wishbone interconnect
// One master to many slaves

module wb_interconnect
#(
	parameter NUM_MASTERS = 1,
	parameter ADDR_BITS = 1,
	parameter BYTES = 1,
	parameter SEL_WIDTH = 1,
	parameter [NUM_MASTERS*ADDR_BITS-1:0] MASTER_ADDRESSES = 0,
	parameter [NUM_MASTERS*ADDR_BITS-1:0] MASTER_ADDRESS_MASKS = 0
) (
	wishbone.slave s_wb,

	output logic [NUM_MASTERS*ADDR_BITS-1:0] m_addr,
	output logic [NUM_MASTERS*BYTES*8-1:0] m_dat_m2s,
	input  logic [NUM_MASTERS*BYTES*8-1:0] m_dat_s2m,
	output logic [NUM_MASTERS-1:0] m_we,
	output logic [NUM_MASTERS*SEL_WIDTH-1:0] m_sel,
	output logic [NUM_MASTERS-1:0] m_stb,
	output logic [NUM_MASTERS-1:0] m_cyc,
	input  logic [NUM_MASTERS-1:0] m_ack,
	input  logic [NUM_MASTERS-1:0] m_stall
);

/*
	function logic [MASTER_ADDR_BITS-1:0] gen_mask();
		input integer bits;
		integer i;
	begin
		gen_mask = '1;
		for(i=0; i<bits; i++)
		begin
			gen_mask[i] = 0;
		end
	end
	endfunction
*/


	genvar i;
 	for(i=0; i<NUM_MASTERS; i++)
	begin
		localparam [ADDR_BITS-1:0] MASK = MASTER_ADDRESS_MASKS[(i+1)*ADDR_BITS-1 -: ADDR_BITS];
		localparam [ADDR_BITS-1:0] ADDR = MASTER_ADDRESSES    [(i+1)*ADDR_BITS-1 -: ADDR_BITS];

		logic active;
		assign active = (s_wb.addr & MASK) == ADDR;

		assign m_addr[(i+1)*ADDR_BITS-1 -: ADDR_BITS] = s_wb.addr & (~MASK);
		assign m_dat_m2s[(i+1)*BYTES*8-1 -: BYTES*8]  = s_wb.dat_m2s;
		assign m_we[i]   = s_wb.we;
		assign m_sel[(i+1)*SEL_WIDTH-1 -: SEL_WIDTH]     = s_wb.sel;
		assign m_stb[i]     = s_wb.stb && active;
		assign m_cyc[i]     = s_wb.cyc && active;
	end

	int j;
	always_comb
	begin
		s_wb.dat_s2m = '0;
		s_wb.stall = 0;
		s_wb.ack = 0;
		for(j=0; j<NUM_MASTERS; j++)
		begin
			if(m_cyc[j])
			begin
				s_wb.dat_s2m = m_dat_s2m[(j+1)*BYTES*8-1 -: BYTES*8] ;
				s_wb.stall   = m_stall[j];
			end
			// No dependancy on cyc as the master must wait for all acks before de-asserting cyc
			s_wb.ack = s_wb.ack || m_ack[j];
		end
	end

endmodule
