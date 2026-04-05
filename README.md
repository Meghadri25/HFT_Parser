# HFT-FPGA

Low-latency packet parsing and framing modules in SystemVerilog for FPGA workflows.

## Repository Layout

- `rtl/` : synthesizable modules
  - `tcp_receive_parser.sv`
  - `tcp_send_framer.sv`
  - `udp_receive_parser.sv`
  - `async_fifo.sv`
  - `cdc_level_sync.sv`
  - `cdc_pulse_sync.sv`
  - `tcp_receive_parser_cdc.sv`
  - `tcp_send_framer_cdc.sv`
  - `udp_receive_parser_cdc.sv`
- `tb/` : testbenches for each module
  - `tcp_receive_parser_tb.sv`
  - `tcp_send_framer_tb.sv`
  - `udp_receive_parser_tb.sv`
  - `async_fifo_tb.sv`
  - `cdc_level_sync_tb.sv`
  - `cdc_pulse_sync_tb.sv`
  - `tcp_receive_parser_cdc_tb.sv`
  - `tcp_send_framer_cdc_tb.sv`
  - `udp_receive_parser_cdc_tb.sv`

## Current Modules

- `tcp_receive_parser` : extracts relevant fields/payload from incoming TCP streams.
- `tcp_send_framer` : frames outgoing TCP payloads/metadata for transmission.
- `udp_receive_parser` : parses UDP packets for downstream logic.
- CDC-capable wrappers are provided for each protocol module, along with reusable async FIFO and synchronizer primitives.

## Getting Started

1. Clone the repository.
2. Use your preferred simulator (e.g., Questa, Xcelium, VCS, Icarus with SV support).
3. Compile files from `rtl/` and matching testbenches from `tb/`.
4. Run simulation and inspect waveforms/logs.

## Notes

- Keep protocol constants and interfaces aligned between RTL and testbenches.
- Add module-level docs as interfaces evolve.
- Keep cross-domain stream paths behind the shared CDC primitives so the wrappers stay small and consistent.
