//  Copyright (C) 2019 Joshua Tyler
//
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//  See the file LICENSE_LGPL included with this distribution for more
//  information.

#ifndef AXIS_SOURCE_HPP
#define AXIS_SOURCE_HPP

// Output an AXI Stream from a vector of vectors
// N.B. Currently this does not support any kind of reset

#include "../other/ClockGen.hpp"
#include "../verilator/Peripheral.hpp"
#include <vector>

template <class dataT, class keepT=dataT, class userT=dataT, unsigned int n_users=0>class AXISSource : public Peripheral
{
public:
	AXISSource(gsl::not_null<ClockGen *> clk_, const gsl::not_null<vluint8_t *> sresetn_, const AxisSignals<dataT, keepT, userT, n_users> &signals_, std::vector<std::vector<uint8_t>> vec_)
		:clk(clk_), sresetn(sresetn_), tready(signals_.tready), tvalid(signals_.tvalid), tlast(signals_.tlast), tkeep(signals_.tkeep), tdata(signals_.tdata), inputVec(vec_)
	{
        addInput(&sresetn);
		addInput(&tready);

		resetState();
	};
	// Returns true if we are done
	bool done(void) const {return (vec.size() == 0);};

	void eval(void) override
	{
		if((clk->getEvent() == ClockGen::Event::RISING))
		{
			if(sresetn == 0)
			{
                resetState();
            } else {
				if((tready && tvalid) || (!tvalid))
				{
                    setupNextData();
                }
			}
		}
	}

private:
	ClockGen *clk;
    InputLatch<vluint8_t> sresetn;
	InputLatch<vluint8_t> tready;
    OutputWrapper<vluint8_t> tvalid;
    OutputWrapper<vluint8_t> tlast;
    OutputWrapper<keepT> tkeep;
    OutputWrapper<dataT> tdata;

    // Do not be tempted to make this a vector
    // The location of each element needs to be fixed in memory since we register it as an input
    std::array<OutputWrapper<userT>, n_users> tusers;

	std::vector<std::vector<uint8_t>> inputVec, vec;

	void resetState(void)
	{
		// Setup vector
		vec = inputVec;

		//It is illegal to be valid in reset
		tvalid = 0;
	}

	//TODO: Add tuser support
	void setupNextData(void)
    {
	    // Setup no data
        tvalid = 0;

        // If we have data to give, present that
	    if(vec.size())
        {
	        // We shouldn't ever have null packets
	        assert(vec[0].size());

            int num_bytes = std::min(vec[0].size(), sizeof(dataT));

            tvalid = 1;
            tdata = 0;
            tkeep = 0;
            for(int i=0; i<num_bytes; i++)
            {
                tdata = tdata | (vec[0][0] << i*8);
                vec[0].erase(vec[0].begin());

                tkeep = tkeep | (1 << i);
            }

            tlast = (vec[0].size() == 0);
            if(tlast)
            {
                vec.erase(vec.begin());
            }
        }
    }
};

#endif
