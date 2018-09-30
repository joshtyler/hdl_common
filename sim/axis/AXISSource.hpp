#ifndef AXIS_SOURCE_HPP
#define AXIS_SOURCE_HPP

// Output an AXI Stream from a vector of vectors
// N.B. Currently this does not support any kind of reset

#include "ClockGen.hpp"
#include "Peripheral.hpp"
#include <vector>

template <class dataT> class AXISSource : public Peripheral
{
public:
	AXISSource(ClockGen &clk, const vluint8_t &sresetn,
		const vluint8_t &readyIn, vluint8_t & valid, vluint8_t &last,
		dataT &data, std::vector<std::vector<dataT>> vec)
		:clk(clk), sresetn(sresetn), ready(readyIn), valid(valid), last(last),
		 data(data), vec(vec)
	{
		addInput(&ready);

		//Initiailise outputs
		valid = 1;
		assert(vec[0].size() > 0);
		data = vec[0][0];
		last = (vec[0].size() == 1);
	};
	// Returns true if we are done
	bool done(void) const {return (vec.size() == 0);};

	void eval(void) override
	{
		#warning "Doesn't currently handle reset in the middle of sim"
		if((clk.getEvent() == ClockGen::Event::RISING) and (sresetn == 1))
		{
			if(ready && valid)
			{
				last = 0; // Reset last flag
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
						valid = 0;
						return;
					} else {
					// It is illegal for the newly popped packet to be empty
					assert(vec[0].size() != 0);
					}
				}

				//Setup outputs
				data = vec[0][0];
				last = (vec[0].size() == 1);
			}
		}
	}

private:
	ClockGen &clk;
	const vluint8_t &sresetn;
	InputLatch<vluint8_t> ready;
	vluint8_t &valid;
	vluint8_t &last;
	dataT &data;

	std::vector<std::vector<dataT>> vec;
};

#endif
