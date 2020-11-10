//  Copyright (C) 2019 Joshua Tyler
//
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//  See the file LICENSE_LGPL included with this distribution for more
//  information.

#ifndef AXIS_SINK_HPP
#define AXIS_SINK_HPP

// Receive an AXIS stream and save it to a std::vector

#include "AXIS.h"
#include "../other/ClockGen.hpp"
#include "../verilator/Peripheral.hpp"
#include <gsl/pointers>
#include <vector>

template <class dataT, class keepT=dataT, class userT=dataT> class AXISSink : public Peripheral
{
public:
	AXISSink(gsl::not_null<ClockGen *> clk, const gsl::not_null<vluint8_t *> sresetn, const AxisSignals<dataT, keepT, userT> &signals)
		:clk(clk), sresetn(sresetn), tready(signals.tready), tvalid(signals.tvalid), tlast(signals.tlast), tkeep(signals.tkeep), tdata(signals.tdata)
	{
		addInput(&tvalid);
		addInput(&tlast);
		addInput(&tdata);
		addInput(&tkeep);
		for(const auto &tuser : signals.tusers)
        {
		    tusers.push_back(tuser);
            addInput(&tusers.back());

        }
		resetState();
	};
	// Data is returned as a vector of vectors
	// Each element in the base vector is a packet
	// Each element in the subvector is a word
	std::vector<std::vector<dataT>> getData(void){return vec;};

	//Return number of times tlast has been received
	unsigned int getTlastCount(void) const {return vec.size()-1;};

	void eval(void) override
	{
		if(clk->getEvent() == ClockGen::Event::RISING)
		{
			if (*sresetn == 1)
			{
				//std::cout << "Got clk rising edge, ready:" << (int)ready << " valid:" << (int)valid << std::endl;
				if(*tready && *tvalid)
				{
					if(!tdata.is_null()) {
                        curData.push_back(*tdata);
                    }
					if(*tlast)
					{
						vec.push_back(curData);
						curData = {};
					}
				}
			} else {
				resetState();
			}
		}
	}

private:
    ClockGen *clk;
	const vluint8_t *sresetn;
    vluint8_t *tready;
	InputLatch <vluint8_t> tvalid;
	InputLatch <vluint8_t> tlast;
    InputLatch <keepT> tkeep;
	InputLatch <dataT> tdata;
    std::vector<InputLatch <userT>> tusers;

	std::vector<std::vector<dataT>> vec;

	std::vector<dataT> curData;

	void resetState(void)
	{
		// Reset vectors
		vec = {};
		curData = {};

		//Always be ready
		*tready = 1;
	}
};

#endif
