#ifndef FLASH_SPI_DEVICE_HPP
#define FLASH_SPI_DEVICE_HPP

#include "SpiDeviceInterface.hpp"

// Based on W25Q128JV

class FlashSpiDevice : public SpiDeviceInterface<uint8_t>
{
	public:
		FlashSpiDevice()
			:rx_state(RxState::INSTRUCTION)
		{

		}

		virtual uint8_t ss_fall() override
		{
			std::cout << "SS fell" << std::endl;
			rx_state = RxState::INSTRUCTION;
			return 0;
		}


		// This needs a serious refactor!
		virtual uint8_t transfer(uint8_t rx) override
		{
			std::cout << "Got data! : " << (int) rx << std::endl;
			uint8_t ret;
			switch(rx_state)
			{
				case RxState::INSTRUCTION:
					instruction = rx;
					ret = 0;
					switch(instruction)
					{
						case 0x05:
							std::cout << "Returning status register" << std::endl;
							ret = 0x0;
							break;
						case 0xAB:
							std::cout << "Returning device ID" << std::endl;
							ret = 0x0;
							break;
						case 0x9F:
							std::cout << "Returning JEDEC ID" << std::endl;
							ret = 0xEF;
							break;
						case 0x03:
							std::cout << "Read data. Warning, not implemented" << std::endl;
							ret = 0x0;
							break;
						default:
							assert(false); // Unknown ID
							break;
					}
					rx_state = RxState::BYTE_2;
					break;
				case RxState::BYTE_2:
					ret = 0;
					switch(instruction)
					{
						case 0x9F:
							ret = 0x40;
							break;
						case 0x03:
							std::cout << "Read data. Warning, not implemented" << std::endl;
							ret = 0x0;
							break;
						default:
							break;
					}
					rx_state = RxState::BYTE_3;
					break;
				case RxState::BYTE_3:
					ret = 0;
					switch(instruction)
					{
						case 0x9F:
							ret = 0x18;
							break;
						case 0x03:
							std::cout << "Read data. Warning, not implemented" << std::endl;
							ret = 0x0;
							break;
						default:
							break;
					}
					rx_state = RxState::BYTE_4;
					break;
				case RxState::BYTE_4:
					ret = 0;
					switch(instruction)
					{
						case 0xAB:
							ret = 0x17;
							break;
						case 0x9F:
							ret = 0x00;
							break;
						case 0x03:
							std::cout << "Read data. Warning, not implemented" << std::endl;
							ret = 0x0;
							break;
						default:
							break;
					}
					rx_state = RxState::DUMMY;
					break;
				case RxState::DUMMY:
					std::cout << "Returning dummy data" << std::endl;
					ret = 0;
					break;
			}

			return ret;
		}

		virtual void ss_rise() override
		{
			std::cout << "SS rose" << std::endl;
		}

	private:
		enum class RxState
		{
			INSTRUCTION,
			BYTE_2,
			BYTE_3,
			BYTE_4,
			DUMMY
		};
		RxState rx_state;

		uint8_t instruction;
};

#endif
