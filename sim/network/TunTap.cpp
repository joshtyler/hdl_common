#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/if.h>
#include <linux/if_tun.h>
#include <cstring>
#include <fcntl.h>
#include <unistd.h>

#include "TunTap.hpp"

TunTapInterface::TunTapInterface(Type t, const char *dev_name)
{
    const char *clonedev = "/dev/net/tun";
    fd = open(clonedev, O_RDWR);
    if(fd < 0)
    {
        throw TunTapException("Could not open clonedev");
    }

    struct ifreq ifr = {};

    ifr.ifr_flags = (t == Type::TUN)? IFF_TUN : IFF_TAP;
    // Don't prepend optional protocol header
    ifr.ifr_flags |= IFF_NO_PI;

    if(dev_name)
    {
        strncpy(ifr.ifr_name, dev_name, IFNAMSIZ);
    }

    // Create device
    int err = ioctl(fd, TUNSETIFF, reinterpret_cast<void *>(&ifr));

    if(err < 0)
    {
        close(fd);
        throw TunTapException("Could not create device");
    }

    mtu = ifr.ifr_mtu;
    name = std::string(ifr.ifr_name);
}

void TunTapInterface::send(std::span<uint8_t> data)
{
    write(fd, data.data(), data.size());
}

std::optional<std::vector<uint8_t>> TunTapInterface::receive()
{
    std::vector<uint8_t> ret(mtu);
    ssize_t n_read = read(fd, ret.data(), ret.size());
    if(n_read < 0)
    {
        throw TunTapException("Read returned error");
    }
    ret.resize(n_read);

    return ret.size()? std::optional<std::vector<uint8_t>>(ret) : std::nullopt;
}