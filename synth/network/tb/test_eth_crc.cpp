//  Copyright (C) 2019 Joshua Tyler
//
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//  See the file LICENSE_LGPL included with this distribution for more
//  information.

#include <iostream>
#include <iomanip> //setw
#include "Veth_crc.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include "../../../sim/other/ClockGen.hpp"
#include "../../../sim/axis/AXISSink.hpp"
#include "../../../sim/axis/AXISSource.hpp"
#include "../../../sim/verilator/VerilatedModel.hpp"
#include "../../../sim/other/ResetGen.hpp"

int main(int argc, char** argv)
{
	const bool recordVcd = true;

	VerilatedModel<Veth_crc> uut(argc,argv,recordVcd);

	ClockGen clk(uut.getTime(), 1e-9, 100e6);
	AXISSink<vluint32_t, vluint8_t> outAxis(&uut, clk, uut.uut->sresetn, uut.uut->axis_o_tready,
		uut.uut->axis_o_tvalid, uut.uut->axis_o_tlast, uut.uut->axis_o_tdata);

	std::vector<std::vector<vluint8_t>> inData = {{0x0,0x1,0x2,0x3}};
	//std::vector<std::vector<vluint8_t>> inData = {{0x01}};
	AXISSource<vluint8_t> inAxis(&uut, clk, uut.uut->sresetn, uut.uut->axis_i_tready,
		uut.uut->axis_i_tvalid, uut.uut->axis_i_tlast, uut.uut->axis_i_tdata,
		inData);

	ResetGen resetGen(&uut, &clk, &uut.uut->sresetn, false);

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
