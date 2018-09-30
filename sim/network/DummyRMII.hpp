#ifndef DUMMY_RMII_HPP
#define DUMMY_RMII_HPP

// Pretend to be an RMII Phy
// For now, "transmit" (i.e data from fpga) only, and just log data to stdout


#include "ClockGen.hpp"
#include "Peripheral.hpp"
#include <vector>

struct DummyRMIIException : std::runtime_error
{
	using std::runtime_error::runtime_error;
};

class DummyRMII : public Peripheral
{
public:
	DummyRMII(ClockGen &clk,
		const vluint8_t &txdIn, const vluint8_t &tx_enIn, vluint8_t &rxd,
		vluint8_t &crs_dv, vluint8_t &rx_er )
		:clk(clk), txd(txdIn), tx_en(tx_enIn), rxd(rxd), crs_dv(crs_dv), rx_er(rx_er)
	{
		addInput(&txd);
		addInput(&tx_en);

		// No receive channel at the moment
		rxd = 0;
		crs_dv = 0;
		rx_er = 0;
	};
	// Data is returned as a vector of vectors
	// Each element in the base vector is a packet
	// Each element in the subvector is a word
	std::vector<std::vector<uint8_t>> getData(void) {return vec;};

	void eval(void) override
	{
		if((clk.getEvent() == ClockGen::Event::RISING))
		{
			static bool last_tx_en = false;
			static int count = 0;
			static std::vector<uint8_t> packet = {};
			if(tx_en)
			{
				static uint8_t word = 0;

				word |= txd << count*2;

				if(count == 3)
				{
					count = 0;
					packet.push_back(word);
					word = 0;
				} else {
					count++;
				}
			} else {
				if(last_tx_en)
				{
					vec.push_back(verifyPacket(packet));
				}
			}
			last_tx_en = tx_en;
		}
	}

private:
	ClockGen &clk;
	InputLatch <vluint8_t> txd;
	InputLatch <vluint8_t> tx_en;
	vluint8_t &rxd;
	vluint8_t &crs_dv;
	vluint8_t &rx_er;

	std::vector<std::vector<uint8_t>> vec;

	// Verify the packet contains correct preamble and SoF delimiter
	// Return packet with these stripped
	std::vector<uint8_t> verifyPacket(std::vector<uint8_t> packet)
	{
		int i;
		for(i=0;;i++)
		{
			if(packet.size() > 0)
			{
				uint8_t data = packet[0];
				packet.erase(packet.begin());
				if(data == 0xD5) // SoF delimiter
				{
					break;
				} else if(data != 0x55) { //Preamble
					//Invalid packet
					throw DummyRMIIException("Unexpected word in preamble: "+std::to_string(data));
				}
			} else {
				throw DummyRMIIException("Packet finished before SoF reached");
			}
		}
		if(i != 7)
		{
			throw DummyRMIIException("Incorrect number of SoF bits: "+std::to_string(i));
		}
		return packet;
	}
};

#endif
