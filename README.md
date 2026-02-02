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
  - This is mainly for simulation at the moment, HOWEVER, it can be run on an FPGA (with an ethernet port) with a few modifications. Find your master xdc file and create an xdc for clock and your ethernet port. You won't need rx_source but you do need an actual MAC/PHY device that can send real bytes. I couldn't put together a real MAC source to send bytes to my FPGA so I opted to post this the way I did, however you will need to make a few changes. The modules rely on rx_source so you'd need to change that to your input from your constraint which you set in your top module as an 8 bit vector in (ethernet) and you'd need to ensure your clock is at least tied to the clock pin on FPGA. If Nexys A7, it's a 100MHz oscillating clock but you could change that within clock wizard to 125Mhz to replicate 1Gigabit ethernet (a bit unrelated but you'd need a cat5 cable for these speeds).
  - rx_source is a "stress testing" device that can run frames back to back in this iteration, but the project, once again, can be used as a real ethernet parser. 
 
  
