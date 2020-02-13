// Simple wishbone interconnect
// One master to many slaves

module wb_interconnect
#(
	parameter NUM_SLAVES = 1,
	parameter MASTER_ADDR_BITS = 1,
	parameter [NUM_SLAVES*MASTER_ADDR_BITS-1:0] SLAVE_ADDRESSES = 0,
	parameter integer SLAVE_ADDRESS_BITS [NUM_SLAVES-1:0] = {0}
) (
	wishbone.master m_wb,
	wishbone.slave s_wb [NUM_SLAVES-1:0]
);

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



	genvar i;
 	for(i=0; i<NUM_SLAVES; i++)
	begin
		localparam [MASTER_ADDR_BITS-1:0] SLAVE_MASK = gen_mask(SLAVE_ADDRESS_BITS[i]);

		logic slave_active;
		assign slave_active = m_wb[i].addr & SLAVE_MASK;

		assign s_wb[i].addr = m_wb.addr[SLAVE_ADDRESS_BITS[i]-1:0];
		assign s_wb[i].dat_m2s = m_wb.dat_m2s;
		assign s_wb[i].we = m_wb.we;
		assign s_wb[i].sel = m_wb.sel;
		assign s_wb[i].stb = m_wb.stb && slave_active[i];
		assign s_wb[i].cyc = m_wb.cyc && slave_active[i];
	end

	always_comb
	begin
		m_wb.dat_s2m = '0;
		m_wb.stall = '1;
		m_wb.ack = '0;
		for(i=0; i<NUM_SLAVES; i++)
		begin
			if(s_wb[i].cyc)
			begin
				m_wb.dat_s2m = s_wb[i].dat_s2m;
				m_wb.stall = s_wb[i].stall;
			end
			// No dependancy on cyc as the master must wait for all acks before de-asserting cyc
			m_wb.ack = m_wb.ack || s_wb[i].ack;
		end
	end

endmodule
