#ifndef PACKETSOURCE_HPP
#define PACKETSOURCE_HPP

#include <vector>
#include <optional>
#include <span>

template <class DataT> class PacketSource
{
public:
    virtual ~PacketSource()=default;

    // Try and get a packet from a packet source
    virtual std::optional<std::vector<DataT>> receive() = 0;
};

template <class DataT> class PacketSink
{
public:
    virtual ~PacketSink()=default;

    // Send a packet to the sink
    virtual void send(std::span<DataT>) = 0;
};


// Simple implementations

// Take a fixed vector of vectors and send out one at a time
template <class T> class SimplePacketSource : public PacketSource<T>
{
public:
    SimplePacketSource(std::vector<std::vector<uint8_t>> data_) : data(data_){};

    std::optional<std::vector<T>> receive() override
    {
        std::optional<std::vector<T>> ret;
        if(iter != data.end())
        {
            ret = *(iter++);
        }
        return ret;
    };

private:
    std::vector<std::vector<T>> data;
    typename std::vector<std::vector<T>>::const_iterator iter = data.begin();
};

// Store packets into a vector of vectors
template <class T> class SimplePacketSink : public PacketSink<T>
{
public:
    void send(std::span<T> data) override
    {
        stored.push_back(std::vector(data.begin(), data.end()));
    };

    const std::vector<std::vector<T>>& getData() const {return stored;};
    size_t getNumPackets() const {return stored.size();};

private:
    std::vector<std::vector<T>> stored;
};
#endif
