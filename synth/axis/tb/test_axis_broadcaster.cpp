#include <catch2/catch.hpp>
#include <iostream>
#include <verilated.h>
#include "Vaxis_register.h"

#include "../../../sim/verilator/VerilatedModel.hpp"
#include "../../../sim/other/ResetGen.hpp"
#include "../../../sim/other/ClockGen.hpp"
#include "../../../sim/axis/AXISSink.hpp"
#include "../../../sim/axis/AXISSource.hpp"
#include "../../../sim/other/BitMux.hpp"

template <size_t numStreams> auto testBroadcaster(std::vector<std::vector<vluint8_t>> inData)
{
	VerilatedModel<Vaxis_register> uut;

	ClockGen clk(uut.getTime(), 1e-9, 100e6);

	typedef BitMux<vluint8_t, vluint8_t> MuxT;
	typedef AXISSink<MuxT,MuxT,vluint8_t> AxisSinkT;

	std::vector<std::unique_ptr<AxisSinkT>> sinkArr;
	std::vector<std::unique_ptr<MuxT>> sinkReady, sinkValid, sinkLast, sinkData;

	for(size_t i=0; i<numStreams; i++)
	{
		sinkReady.push_back(std::make_unique<MuxT>(uut.uut->axis_o_tready,i,i));
		sinkValid.push_back(std::make_unique<MuxT>(uut.uut->axis_o_tvalid,i,i));
		sinkLast .push_back(std::make_unique<MuxT>(uut.uut->axis_o_tlast,i,i));
		sinkData .push_back(std::make_unique<MuxT>(uut.uut->axis_o_tdata,i*8,(i+1)*8-1));

		sinkArr.push_back(
			std::make_unique<AxisSinkT> (
			clk,
			uut.uut->sresetn,
			*sinkReady.back(),
			*sinkValid.back(),
			*sinkLast.back(),
			*sinkData.back()
		));
	};


	AXISSource<vluint8_t> inAxis(clk, uut.uut->sresetn, uut.uut->axis_i_tready,
		uut.uut->axis_i_tvalid, uut.uut->axis_i_tlast, uut.uut->axis_i_tdata,
		inData);

	ResetGen resetGen(clk,uut.uut->sresetn, false);

	for(auto& it : sinkArr)
		uut.addPeripheral(it.get());
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
		// Break after a timeout
		if(uut.getTime() == 10000)
		{
			break;
		}
	}
	//return outAxis.getData();
	std::array<std::vector<std::vector<BitMux<vluint8_t, vluint8_t>>>, numStreams> outArr;
	for(size_t i=0; i< outArr.size(); i++)
		outArr[i] = sinkArr[i]->getData();
	return outArr;
}

TEST_CASE("Test all re-broadcasted streams are correct", "[axis_broadcaster]")
{
	std::vector<std::vector<vluint8_t>> testData = {{0x0,0x1,0x2,0x3}};
	std::array<std::vector<std::vector<vluint8_t>>,2> outData = {testData, testData};
	testBroadcaster<2>(testData);
	REQUIRE( outData == outData);
}
