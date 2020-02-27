#ifndef SPI_HPP
#define SPI_HPP

#include <bitset>

#include "SpiDeviceInterface.hpp"
#include "../verilator/Peripheral.hpp"

template <class dataT,class devDataT> class SpiSlave : public Peripheral
{
	public:
		SpiSlave(const dataT & sckIn, const dataT &mosiIn, dataT &misoIn, const dataT &ssIn, SpiDeviceInterface<devDataT>* devIn)
			:sck(sckIn), mosi(mosiIn), miso(misoIn), ss(ssIn), dev(devIn), prev_sck(0), prev_ss(1), ctr(CTR_HIGH)
		{
			addInput(&sck);
			addInput(&mosi);
			addInput(&ss);
		}

		void eval(void) override
		{
			if(prev_ss != ss)
			{
				if(ss)
				{
					assert(ctr == CTR_HIGH);
					dev->ss_rise();
					ctr = 0;
				} else {
					current_tx_dat = dev->ss_fall();
					ctr = CTR_HIGH;
					miso = current_tx_dat[ctr];
				}
			}

			if(sck == 1 && prev_sck == 0) // Rising edge
			{
				current_rx_dat[ctr] = mosi;
			} else if(sck == 0 && prev_sck == 1) { // Falling edge
				if(ctr == 0)
				{
					ctr = CTR_HIGH;
					current_tx_dat = dev->transfer(current_rx_dat.to_ulong());
					//std::cout << "New transmit data " << current_tx_dat << std::endl;
					current_rx_dat = 0;
				} else {
					ctr--;
				}
				miso = current_tx_dat[ctr];
				//std::cout << "Setting MISO to " << miso << std::endl;
			}

			prev_sck = sck;
			prev_ss = ss;
		}

	private:
		InputLatch<dataT> sck;
		InputLatch<dataT> mosi;
		dataT &miso;
		InputLatch<dataT> ss;
		SpiDeviceInterface<devDataT> *dev;
		dataT prev_sck;
		dataT prev_ss;
		int ctr;
		static constexpr unsigned int CTR_HIGH = sizeof(devDataT)*8-1;
		std::bitset<sizeof(devDataT)*8> current_tx_dat;
		std::bitset<sizeof(devDataT)*8> current_rx_dat;

};

#endif
