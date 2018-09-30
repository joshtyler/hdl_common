#include <iostream>
#include <iomanip> //setw
#include "Vcrc.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include "ClockGen.hpp"
#include "AXISSink.hpp"
#include "AXISSource.hpp"
#include "VerilatedModel.hpp"
#include "ResetGen.hpp"

int main(int argc, char** argv)
{
	const bool recordVcd = true;

	VerilatedModel<Vcrc> uut(argc,argv,recordVcd);

	ClockGen clk(uut.getTime(), 1e-9, 100e6);
	AXISSink<vluint32_t> outAxis(clk, uut.uut->sresetn, uut.uut->out_axis_tready,
		uut.uut->out_axis_tvalid, uut.uut->out_axis_tlast, uut.uut->out_axis_tdata);

	std::vector<std::vector<vluint8_t>> inData = {{0x0,0x1,0x2,0x3}};
	//std::vector<std::vector<vluint8_t>> inData = {{0x01}};
	AXISSource<vluint8_t> inAxis(clk, uut.uut->sresetn, uut.uut->in_axis_tready,
		uut.uut->in_axis_tvalid, uut.uut->in_axis_tlast, uut.uut->in_axis_tdata,
		inData);

	ResetGen resetGen(clk,uut.uut->sresetn, false);

	uut.addPeripheral(&outAxis);
	uut.addPeripheral(&inAxis);
	uut.addPeripheral(&resetGen);
	ClockBind clkDriver(clk,uut.uut->clk);
	uut.addClock(&clkDriver);

	while(true)
	{
		if(uut.eval() == false)
		{
			break;
		}

		// Break if we have a whole packet
		if(outAxis.getTlastCount() == 1)
		{
			//break;
		}

		// Or after a timeout
		if(uut.getTime() == 10000)
		{
			std::cout << "Timed out" << std::endl;
			break;
		}
	}

	// Print first packet
	std::vector<std::vector<vluint32_t>> data = outAxis.getData();
	std::cout << "First packet:" << std::hex ;
	for(auto const & itm : data[0])
	{
		std::cout << std::setfill('0') << std::setw(2) << (int)itm << " ";
	}
	std::cout << std::dec << std::endl;



}
