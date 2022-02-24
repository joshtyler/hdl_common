# Common HDL Components

This is a library of common HDL components intended for reuse across different components.

Most components have a verilator testbench, which is tested using the Catch2 unit testing framework.

To run all tests:
```bash
cmake -B build
cmake --build build -j $(nproc)
./build/all_test_exec
```

N.B. There is also a Makefile to build the unit tests, but this is deprected (it is also currently not building). It will be removed in the future

This library has been primarily made for my own use, and I regularly develop and commit directly to trunk. At the current time no API stability is guaranteed, and many blocks are under development.

## Licensing
Software is licensed under LGPL 2.1 (or later)
HDL is licensed under OHDL V1.0
See LICENSE_LGPL and LICENSE_OHDL
