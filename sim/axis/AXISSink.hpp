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

template <class dataT, class keepT=dataT, class userT=dataT, unsigned int n_users=0> class AXISSink : public Peripheral
{
public:
	AXISSink(gsl::not_null<ClockGen *> clk_, const gsl::not_null<vluint8_t *> sresetn_, const AxisSignals<dataT, keepT, userT, n_users> &signals_)
		:clk(clk_), sresetn(sresetn_), tready(signals_.tready), tvalid(signals_.tvalid), tlast(signals_.tlast), tkeep(signals_.tkeep), tdata(signals_.tdata)
	{
        addInput(&sresetn);
		addInput(&tvalid);
		addInput(&tlast);
		addInput(&tdata);
		addInput(&tkeep);
		for(size_t i=0; i<tusers.size(); i++)
        {
		    tusers[i] = InputLatch<userT>(signals_.tusers.at(i));
            addInput(&tusers[i]);

        }
		resetState();
	};
	// Data is returned as a vector of vectors
	// Each element in the base vector is a packet
	// Each element in the subvector is a word
    auto getData(void){return datas;};
    auto getUsers(void){return users;};

	//Return number of times tlast has been received
	unsigned int getTlastCount(void) const {return datas.size() - 1;};

	void eval(void) override
	{
		if(clk->getEvent() == ClockGen::Event::RISING)
		{
			if (sresetn == 1)
			{
				//std::cout << "Got clk rising edge, ready:" << (int)ready << " valid:" << (int)valid << std::endl;
				if(tready && tvalid)
				{
					if(!tdata.is_null()) {
                        cur_data_natural_width.push_back(tdata);
                        keepT keep = tkeep.is_null()? (~keepT{}) : tkeep;
                        dataT data = tdata;
                        for(size_t i=0; i<sizeof(dataT); i++)
                        {
                            if(keep & 1)
                            {
                                cur_data.push_back(data & 0xFF);
                            }
                            keep >>= 1;
                            data >>= 8;
                        }
                    }

                    for(auto i=0u; i<tusers.size(); i++)
                    {
                        curUsers[i].push_back(tusers[i]);
                    }

					if(tlast.is_null() || tlast)
					{
                        datas_natural_width.push_back(cur_data_natural_width);
                        datas.push_back(cur_data);
                        users.push_back(curUsers);
                        resetPacket();
					}
				}
			} else {
				resetState();
			}
		}
	}

private:
    ClockGen *clk;
    InputLatch<vluint8_t> sresetn;
    OutputWrapper<vluint8_t> tready;
	InputLatch <vluint8_t> tvalid;
	InputLatch <vluint8_t> tlast;
    InputLatch <keepT> tkeep;
	InputLatch <dataT> tdata;
    // Do not be tempted to make this a vector
    // The location of each element needs to be fixed in memory since we register it as an input
    std::array<InputLatch<userT>, n_users> tusers;

	std::vector<std::vector<dataT>> datas_natural_width;
    std::vector<std::vector<uint8_t>> datas;
    std::vector<std::array<std::vector<userT>, n_users>> users;

	std::vector<dataT> cur_data_natural_width;
    std::vector<uint8_t> cur_data;
    std::array<std::vector<userT>, n_users> curUsers;

	void resetState(void)
	{
		// Reset vectors
		datas = {};
        users = {};
        resetPacket();

		//Always be ready
		tready = 1;
	}

	void resetPacket(void)
    {
        cur_data = {};
        cur_data_natural_width = {};
        curUsers = {};
    }
};

#endif
