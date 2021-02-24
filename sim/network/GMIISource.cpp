#include "GMIISource.hpp"

#include <boost/endian/conversion.hpp>
#include <zlib.h>

void GMIISource::eval(void)
{
    if((clk->getEvent() == ClockGen::Event::RISING))
    {
        // Setup no data
        eth_rxdv = 0;
        eth_rxer = 0;

        // If we have run out of data, try and get more
        if (iter == current_packet.end())
        {
            auto maybe_new_packet = data_source->receive();
            if (maybe_new_packet)
            {
                current_packet = *maybe_new_packet;

                // Pad if less than minimum size
                if (current_packet.size() < 60)
                {
                    // Pad with zeros, even though actual value does not matter
                    current_packet.resize(60, 0);
                }

                // Add the ethernet CRC to the front
                uint32_t crc = crc32(0, current_packet.data(), current_packet.size());
                boost::endian::native_to_big_inplace(crc);
                auto crc_u8_ptr = reinterpret_cast<uint8_t *>(&crc);
                std::copy(crc_u8_ptr, crc_u8_ptr + 4, std::back_inserter(current_packet));

                // Put preamble on the front
                current_packet.insert(current_packet.begin(), preamble.begin(), preamble.end());

                iter = current_packet.begin();
            }
        }

        // Enforce the inter-packet gap if we just finished a packet
        if (ipg_counter)
        {
            ipg_counter--;
        } else {
            // If we have data to give, present that
            if (iter != current_packet.end())
            {
                eth_rxdv = 1;
                eth_rxd = *(iter++);

                if (iter == current_packet.end())
                {
                    ipg_counter = 12;
                }
            }
        }
    }
}

