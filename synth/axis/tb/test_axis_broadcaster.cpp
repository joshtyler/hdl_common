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

	BitMuxOut<vluint8_t,vluint8_t> sinkReadyMux(uut.uut->axis_o_tready);
	std::vector<std::unique_ptr<BitMuxIn<vluint8_t,vluint8_t>>> sinkValidMux;
	std::vector<std::unique_ptr<BitMuxIn<vluint8_t,vluint8_t>>> sinkLastMux;
	std::vector<std::unique_ptr<BitMuxIn<vluint8_t,vluint8_t>>> sinkDataMux;

	std::vector<std::unique_ptr<AXISSink<vluint8_t>>> sinkArr;

	for(size_t i=0; i<numStreams; i++)
	{
		sinkValidMux.push_back(std::make_unique<BitMuxIn<vluint8_t,vluint8_t>>(uut.uut->axis_o_tvalid,i,i));
		sinkLastMux.push_back(std::make_unique<BitMuxIn<vluint8_t,vluint8_t>>(uut.uut->axis_o_tlast,i,i));
		sinkDataMux.push_back(std::make_unique<BitMuxIn<vluint8_t,vluint8_t>>(uut.uut->axis_o_tdata ,i*8,(i+1)*8-1));

		sinkArr.push_back(
			std::make_unique<AXISSink<vluint8_t>> (
			clk,
			uut.uut->sresetn,
			sinkReadyMux.registerWriter(i,i),
			*sinkValidMux.back(),
			*sinkLastMux.back(),
			*sinkDataMux.back()
		));
	};


	AXISSource<vluint8_t> inAxis(clk, uut.uut->sresetn, uut.uut->axis_i_tready,
		uut.uut->axis_i_tvalid, uut.uut->axis_i_tlast, uut.uut->axis_i_tdata,
		inData);

	ResetGen resetGen(clk,uut.uut->sresetn, false);

	for(auto& it : sinkArr)
		uut.addPeripheral(it.get());
	uut.addPeripheral(&sinkReadyMux); // This must be after sinkArr
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
	std::array<std::vector<std::vector<vluint8_t>>, numStreams> outArr;
	for(size_t i=0; i< outArr.size(); i++)
		outArr[i] = sinkArr[i]->getData();
	return outArr;
}

TEST_CASE("Test all re-broadcasted streams are correct", "[axis_broadcaster]")
{
	std::vector<std::vector<vluint8_t>> testData = {{0x0,0x1,0x2,0x3}};
	std::array<std::vector<std::vector<vluint8_t>>,2> outData = {testData, testData};
	REQUIRE(testBroadcaster<2>(testData) == outData);
}
