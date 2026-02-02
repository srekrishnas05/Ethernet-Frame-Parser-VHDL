# Ethernet Frame Parser + CRC32 + Byte Generator (VHDL) 

A VHDL project to simulate RX of ethernet. Generates Ethernet-like byte streams, parses L2 headers (DST/SRC/VLAN/Ethertype), streams payload, and verifies Frame Check Sequence (FCS) using CRC32.

Structure
- `rx_source` acts as a transmitter to produce frames and correct FCS
- `frame_parser` is the DUT
- `crc32` is the receiver-side checker (recomputes crc and compares to recieved FCS)
- `payload_sink` is a monitor/sink

## Features
- Byte-stream interface with `in_valid`, `in_sof`, `in_eof`, `in_err`
- Parses:
  - Destination MAC (48-bit)
  - Source MAC (48-bit)
  - Optional VLAN TPID 0x8100 + TCI (4 bytes total Q-tag)
  - Ethertype (16-bit)
- Payload streaming (`payload_byte`, `payload_valid`)
- CRC32 (Ethernet reflected polynomial 0xEDB88320) with FCS comparison
- Simulation-first testbench (`tb_top`) with waveform inspection

  ## How to run (Vivado but ideally the code will work in any simulating environment)
  1) Create a new vivado project (no board needed)
  2) Create the four design sources with the same name and copy paste the content (`rx_source`, `frame_parser`, `crc32`, `payload_sink`)
  3) Bring in the `top.vhd` module (same step as last) and set as top if not compiled automatically
  4) Run behavioral simulation
 
  ## Notes
  - This is a simulation/verification project so XDC isn't needed but if you do, you need a constraint file with pins for the clock (to the onboard clock pin) along with a real MAC/PHY interface
  - rx_source is a "stress testing" device that can run frames back to back
 
  
