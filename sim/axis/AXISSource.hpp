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

template <class dataT, class keepT=dataT, class userT=dataT>class AXISSource : public Peripheral
{
public:
	AXISSource(gsl::not_null<ClockGen *> clk, const gsl::not_null<vluint8_t *> sresetn, const AxisSignals<dataT, keepT, userT> &signals, std::vector<std::vector<dataT>> vec)
		:clk(clk), sresetn(sresetn), tready(signals.tready), tvalid(signals.tvalid), tlast(signals.tlast), tkeep(signals.tkeep), tdata(signals.tdata), inputVec(vec)
	{
		addInput(&tready);

		resetState();
	};
	// Returns true if we are done
	bool done(void) const {return (vec.size() == 0);};

	void eval(void) override
	{
		if((clk->getEvent() == ClockGen::Event::RISING) and (*sresetn == 1))
		{
			if(*sresetn == 1)
			{
				if(*tready && *tvalid)
				{
                    *tlast = 0; // Reset last flag
					assert(vec[0].size() != 0);
					vec[0].erase(vec[0].begin()); //Get rid of the word we output

					// Get next word onto front
					if(vec[0].size() == 0)
					{
						// If that was the end of a packet, pop it off
						vec.erase(vec.begin());
						if(vec.size() == 0)
						{
							// That was the last packet. We are done
                            *tvalid = 0;
							return;
						} else {
						// It is illegal for the newly popped packet to be empty
						assert(vec[0].size() != 0);
						}
					}

					//Setup outputs
					*tdata = vec[0][0];
                    *tlast = (vec[0].size() == 1);
				}
			} else {
				resetState();
			}
		}
	}

private:
	ClockGen *clk;
    const vluint8_t *sresetn;
	InputLatch<vluint8_t> tready;
    vluint8_t *tvalid;
    vluint8_t *tlast;
    keepT *tkeep;
	dataT *tdata;
    std::vector<userT*> tusers;

	std::vector<std::vector<dataT>> inputVec, vec;

	void resetState(void)
	{
		// Setup vector
		vec = inputVec;

		//Initiailise outputs
		*tvalid = 1;
		assert(vec[0].size() > 0);
		*tdata = vec[0][0];
		*tlast = (vec[0].size() == 1);
	}
};

#endif
