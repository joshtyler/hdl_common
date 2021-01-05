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

struct AXISSourceConfig
{
    bool packed = true;
};

template <class dataT, class keepT=dataT, class userT=dataT, unsigned int n_users=0>class AXISSource : public Peripheral
{
public:
	AXISSource(gsl::not_null<ClockGen *> clk_, const gsl::not_null<vluint8_t *> sresetn_, const AxisSignals<dataT, keepT, userT, n_users> &signals_, std::vector<std::vector<uint8_t>> data_, AXISSourceConfig _config=AXISSourceConfig{})
		:clk(clk_), sresetn(sresetn_), tready(signals_.tready), tvalid(signals_.tvalid), tlast(signals_.tlast), tkeep(signals_.tkeep), tdata(signals_.tdata), output_packed(_config.packed), inputData(data_)
	{
        addInput(&sresetn);
		addInput(&tready);

		resetState();
	};
	// Returns true if we are done
	bool done(void) const {return (data.size() == 0);};

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

    bool output_packed;

private:

    // Do not be tempted to make this a vector
    // The location of each element needs to be fixed in memory since we register it as an input
    std::array<OutputWrapper<userT>, n_users> tusers;

	std::vector<std::vector<uint8_t>> inputData, data;

	void resetState(void)
	{
		// Setup vector
        data = inputData;

		//It is illegal to be valid in reset
		tvalid = 0;
	}

	//TODO: Add tuser support
	void setupNextData(void)
    {
	    // Setup no data
        tvalid = 0;

        // If we have data to give, present that
	    if(data.size())
        {
	        // We shouldn't ever have null packets
	        assert(data[0].size());

            int max_num_bytes = std::min(data[0].size(), sizeof(dataT));

            tvalid = 1;
            tdata = 0;
            tkeep = 0;
            for(int i=0; i<max_num_bytes; i++)
            {

                if(output_packed || (rand() > (RAND_MAX / 2)))
                {
                    tdata = tdata | (data[0][0] << i * 8);
                    data[0].erase(data[0].begin());
                    tkeep = tkeep | (1 << i);
                }
            }

            tlast = (data[0].size() == 0);
            if(tlast || tlast.is_null())
            {
                data.erase(data.begin());
            }
        }
    }
};

#endif
