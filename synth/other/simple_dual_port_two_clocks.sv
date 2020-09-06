// Simple dual port dual clock block RAM
// Based on Xilinx instantiation template
// Used to for inference of BRAM

module simple_dual_port_two_clocks (clka,clkb,ena,enb,wea,addra,addrb,dia,dob);

parameter addr_width = 10;
parameter data_width = 16;

input clka,clkb,ena,enb,wea;
input [addr_width-1:0] addra,addrb;
input [data_width-1:0] dia;
output [data_width-1:0] dob;
reg[data_width-1:0] ram [2**addr_width-1:0];
reg[data_width-1:0] dob;

always @(posedge clka)
begin
	if (ena)
	begin
		if (wea)
			ram[addra] <= dia;
	end
end

always @(posedge clkb)
begin
	if (enb)
	begin
		dob <= ram[addrb];
	end
end

endmodule
