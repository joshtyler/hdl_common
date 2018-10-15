#ifndef BITMUX_HPP
#define BITMUX_HPP

#include "../verilator/Peripheral.hpp"

// Often it is useful in Verilog to pack data outupts
	// E.g. Pack the ready signals of 4 AXI busses into a 4 bit vector
// This is silghtly awkward to handle in C++, because we see that as one variable, and need to send different bits to different classes
// These are helper classes.
 	// BitMuxIn takes a const reference to a variable, and returns only the bits we care about to the upstream application
 	// BitMuxOut takes a variable from the upstream application, and updates the variable

template <class Ti, class To> class BitMuxIn
{
public:
	BitMuxIn(const Ti& ref, unsigned int lowBit,unsigned int highBit) :ref(ref), lowBit(lowBit), highBit(highBit) {};
	operator To() const
	{
		Ti temp = ref;
		// Shift low bit to LSB
		temp >>= lowBit;
		// Mask off any bits higher than MSB
		temp &= 2^(highBit - lowBit + 1)-1;
		To ret = (To) temp;
		assert(ret == temp);
		return ret;
	};
private:
	const Ti &ref;
	unsigned int lowBit, highBit;
};

// Bit mux out is slightly more complex than BitMuxIn
// Because the application can update the variable as it pleases, there is no way to magically have BitMuxOut update the real value
// Therefore we need to inherit from peripheral and call eval, but AFTER all the references have been updated
namespace // Make only visible in this file
{
	template <class Ti, class To> class Writer
	{
	public:
		Writer(unsigned int lowBit,unsigned int highBit) :lowBit(lowBit), highBit(highBit) {}
		To getValue(void)
		{
			return (To) value; // Temp
		}
		Ti& getRef(void) {return value;};

	private:
		Ti value;
		unsigned int lowBit, highBit;
	};
}
template <class Ti, class To> class BitMuxOut : public Peripheral
{
public:
	BitMuxOut(To& ref) :ref(ref) {};
	~BitMuxOut()
	{
		for(auto it : writers)
			delete it;
	}

	Ti & registerWriter(int lowBit, int highBit)
	{
		writers.push_back(new Writer<Ti,To> (lowBit, highBit));
		return writers.back()->getRef();
	};

	void eval(void) override
	{
		ref = 0;
		for(auto it : writers)
		{
			ref |= it->getValue();
		}
	}
private:
	std::vector<Writer<Ti,To> *> writers;
	To &ref;

};

#endif
