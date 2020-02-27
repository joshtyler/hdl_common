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
	input  logic [ADDR_BITS-1:0] s_wb_addr,
	input  logic [BYTES*8-1:0]   s_wb_dat_m2s,
	output logic [BYTES*8-1:0]   s_wb_dat_s2m,
	input  logic                 s_wb_we,
	input  logic [SEL_WIDTH-1:0] s_wb_sel,
	input  logic                 s_wb_stb,
	input  logic                 s_wb_cyc,
	output logic                 s_wb_ack,
	output logic                 s_wb_stall,

	output logic [NUM_MASTERS*ADDR_BITS-1:0] m_wb_addr,
	output logic [NUM_MASTERS*BYTES*8-1:0]   m_wb_dat_m2s,
	input  logic [NUM_MASTERS*BYTES*8-1:0]   m_wb_dat_s2m,
	output logic [NUM_MASTERS-1:0]           m_wb_we,
	output logic [NUM_MASTERS*SEL_WIDTH-1:0] m_wb_sel,
	output logic [NUM_MASTERS-1:0]           m_wb_stb,
	output logic [NUM_MASTERS-1:0]           m_wb_cyc,
	input  logic [NUM_MASTERS-1:0]           m_wb_ack,
	input  logic [NUM_MASTERS-1:0]           m_wb_stall
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
		assign active = (s_wb_addr & MASK) == ADDR;

		assign m_wb_addr[(i+1)*ADDR_BITS-1 -: ADDR_BITS] = s_wb_addr & (~MASK);
		assign m_wb_dat_m2s[(i+1)*BYTES*8-1 -: BYTES*8]  = s_wb_dat_m2s;
		assign m_wb_we[i]   = s_wb_we;
		assign m_wb_sel[(i+1)*SEL_WIDTH-1 -: SEL_WIDTH]     = s_wb_sel;
		assign m_wb_stb[i]     = s_wb_stb && active;
		assign m_wb_cyc[i]     = s_wb_cyc && active;
	end

	integer j;
	always_comb
	begin
		s_wb_dat_s2m = '0;
		s_wb_stall = 0;
		s_wb_ack = 0;
		for(j=0; j<NUM_MASTERS; j++)
		begin
			if(m_wb_cyc[j])
			begin
				s_wb_dat_s2m = m_wb_dat_s2m[(j+1)*BYTES*8-1 -: BYTES*8] ;
				s_wb_stall   = m_wb_stall[j];
			end
			// No dependancy on cyc as the master must wait for all acks before de-asserting cyc
			s_wb_ack = s_wb_ack || m_wb_ack[j];
		end
	end

endmodule
