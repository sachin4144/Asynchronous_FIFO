📌 Project Overview

This project implements a fully parameterized Asynchronous First-In First-Out (FIFO) buffer in Verilog HDL, designed to safely transfer data between two independent clock domains. The design leverages Gray code pointer synchronization and two-stage flip-flop synchronizers to handle the challenges of metastability that arise at clock domain boundaries.

The design is modular, simulation-verified, and structured to reflect industry-standard RTL design practices — suitable for use in SoC, FPGA, and ASIC design flows.


❓ Why Asynchronous FIFOs?

In modern digital systems — SoCs, ASICs, and FPGAs — different functional blocks often operate at different clock frequencies. Directly connecting signals across clock domains without proper synchronization leads to metastability, causing unpredictable and catastrophic system failures.

An Asynchronous FIFO solves this by:


Decoupling the write side (producer) and read side (consumer) into independent clock domains
Providing a safe buffering mechanism for inter-domain data transfer
Generating reliable full and empty status flags using Gray-code-synchronized pointers
Eliminating multi-bit synchronization hazards through Gray code encoding



Used extensively in interfaces like DDR memory controllers, PCIe bridges, AXI crossbars, video frame buffers, serial communication (USB, Ethernet), and multimedia pipelines.




✨ Key Features


🔧 Parameterized Data Width — configurable via DATA_WIDTH parameter
🔧 Parameterized FIFO Depth — configurable via FIFO_DEPTH parameter
🔢 Parameterized Pointer Width — automatically derived using $clog2() for clean scalability
🔄 Independent Read & Write Clocks — fully asynchronous clock domains
🩶 Binary-to-Gray Code Conversion — eliminates multi-bit transition hazards during pointer synchronization
🔀 Two Flip-Flop (2FF) Synchronizers — industry-standard metastability mitigation
🚦 Full Flag Generation — prevents write overflow
🚦 Empty Flag Generation — prevents read underflow
✅ Self-Checking Testbench — SystemVerilog scoreboard using a queue for automatic result verification
🧪 Simulation Verified — tested using ModelSim/QuestaSim and EDA Playground



🏗️ Block Diagram

Write Clock Domain                       Read Clock Domain
─────────────────────────────────────────────────────────────────────

  wclk ──┐                                              ┌── rclk
         │                                              │
  ┌──────▼──────┐    wptr (Gray)    ┌──────────────┐   │
  │             │──────────────────►│  2FF Sync    │   │
  │  wptr       │                   │  (wptr→rclk) │   │
  │  Handler    │◄── wfull          └──────┬───────┘   │
  │             │                          │            │
  └──────┬──────┘               rptr_sync  ▼            │
         │                    ┌──────────────────┐      │
    wptr │ (binary)           │   rptr Handler   │◄─────┘
         │                    │                  │
  ┌──────▼──────────────────┐ │  rempty          │
  │                         │ └──────┬───────────┘
  │       FIFO Memory       │        │ rptr (Gray)
  │   (Dual-Port SRAM)      │        │
  │                         │◄───────┘
  └─────────────────────────┘    ┌──────────────┐
                                 │  2FF Sync    │
         rptr (Gray) ────────────►  (rptr→wclk) │
                                 └──────┬───────┘
                                        │
                                  wptr_sync
                                  (used for wfull)

─────────────────────────────────────────────────────────────────────

📁 Repository Structure

asynchronous-fifo/
│
├── rtl/
│   ├── fifo_mem.v              # Dual-port synchronous FIFO memory (SRAM model)
│   ├── synchronizer.v          # Two flip-flop (2FF) Gray code synchronizer
│   ├── wptr_handler.v          # Write pointer logic + full flag generation
│   └── rptr_handler.v          # Read pointer logic + empty flag generation
│
├── tb/
│   └── async_fifo_TB.sv        # Self-checking SystemVerilog testbench
│
└── README.md


⚙️ Working Principle

The FIFO operates as a dual-port memory with separate read and write interfaces, each governed by its own clock domain.

Write Side (wclk domain)


On each rising edge of wclk, if winc is asserted and the FIFO is not full, data is written to mem[waddr] and the binary write pointer is incremented.
The binary write pointer is converted to Gray code (wptr) before being passed to the read clock domain via a 2FF synchronizer.


Read Side (rclk domain)


On each rising edge of rclk, if rinc is asserted and the FIFO is not empty, data is read from mem[raddr] and the binary read pointer is incremented.
The binary read pointer is converted to Gray code (rptr) before being passed to the write clock domain via a 2FF synchronizer.


Status Flag Generation


wfull is generated in the write clock domain by comparing the current wptr against the synchronized read pointer (rptr_sync).
rempty is generated in the read clock domain by comparing the current rptr against the synchronized write pointer (wptr_sync).



🩶 Gray Code Synchronization

The Multi-Bit Transition Problem

When a binary counter increments (e.g., 3 → 4, i.e., 011 → 100), all bits change simultaneously. If this multi-bit value is sampled by a different clock domain, each bit may be captured at a different phase — leading to an invalid intermediate value being read (e.g., 010 or 110), which causes incorrect full/empty flag assertions and potential data corruption.

The Gray Code Solution

Gray code is a binary numeral system in which only one bit changes between any two consecutive values:

DecimalBinaryGray Code00000001001001201001130110104100110510111161101017111100

Since only one bit transitions per count, even if the receiving clock domain samples the pointer slightly late or early, it will either see the old valid value or the new valid value — never an invalid intermediate.

Binary to Gray Code Conversion (Verilog)

verilog// Binary to Gray: G[n] = B[n] ^ B[n-1]
assign gray = (binary >> 1) ^ binary;

Two Flip-Flop (2FF) Synchronizer

The Gray-coded pointer is passed through two cascaded flip-flops clocked by the destination domain. This gives any metastable signal a full clock period to resolve before being used in logic — a well-established, MTBF-proven CDC technique.

verilogalways_ff @(posedge dest_clk or negedge rst_n) begin
    if (!rst_n) begin
        sync_stage1 <= '0;
        sync_stage2 <= '0;
    end else begin
        sync_stage1 <= gray_in;   // First FF: may go metastable
        sync_stage2 <= sync_stage1; // Second FF: resolved output
    end
end


Industry Note: The 2FF synchronizer is the foundational CDC technique used at Qualcomm, NVIDIA, AMD, Intel, and Synopsys-verified designs. A 3FF synchronizer is used in ultra-high frequency or safety-critical designs where additional resolution time is needed.




🚦 Full and Empty Flag Generation

The full/empty flag comparison is done in Gray code space. This is possible because consecutive Gray code values have a predictable pattern.

Empty Flag

The FIFO is empty when the write pointer and read pointer point to the same location. Since both pointers are in the same (read) clock domain after synchronization, a simple equality check suffices:

verilogassign rempty = (wptr_sync == rptr);

Full Flag

The FIFO is full when the write pointer has lapped the read pointer — i.e., it is exactly one "wrap" ahead. In Gray code, a full condition is detected when:


The MSB of wptr differs from the MSB of rptr_sync
The second MSB of wptr differs from the second MSB of rptr_sync
All remaining lower bits of wptr are equal to rptr_sync


This leverages the property that in an n-bit Gray counter, the MSBs invert at the wrap point while lower bits mirror.

verilogassign wfull = (wptr == {~rptr_sync[PTR_WIDTH:PTR_WIDTH-1], rptr_sync[PTR_WIDTH-2:0]});


Why not compare binary pointers? Binary pointers involve multi-bit transitions that are unsafe to compare across clock domains. Gray code pointers are the only correct approach for CDC full/empty flag generation.




🔀 Clock Domain Crossing (CDC)

CDC AspectImplementation in This DesignSynchronization PrimitiveTwo Flip-Flop (2FF) synchronizerPointer EncodingGray code (single-bit-change per increment)Number of Sync Stages2 (configurable to 3 for high-frequency designs)Pointer Width$clog2(FIFO_DEPTH) + 1 bits (extra MSB for wrap detection)Data PathDual-port SRAM — no synchronization needed on data pathFlag Domainswfull resolved in wclk domain; rempty resolved in rclk domainCDC Lint Tool CompatibilityStructure compatible with Synopsys SpyGlass CDC and Cadence JasperGold CDC


Key Insight: The FIFO memory (data path) does not cross clock domains. Only the pointers (control path) cross domains, and they are safely encoded in Gray code. This is why a FIFO is the preferred CDC data-transfer architecture over a simple 2FF synchronizer, which can only safely transfer single-bit signals.




🧪 Simulation Methodology

The testbench (async_fifo_TB.sv) is a self-checking SystemVerilog testbench that:


Generates independent clocks — wclk and rclk with different frequencies to stress-test CDC behavior
Drives randomized write and read operations — including back-to-back writes, burst reads, and mixed transactions
Uses a SystemVerilog queue (logic [DATA_WIDTH-1:0] scoreboard[$]) as a reference model — data written to the FIFO is pushed into the queue; data read from the FIFO is compared against the queue front
Checks full and empty flags — verifies no write occurs when full, no read occurs when empty
Reports pass/fail — automatic $display messages indicate mismatches and final test status


Testbench Architecture

                    ┌───────────────────────────────┐
                    │    async_fifo_TB.sv            │
                    │                                │
  Write Driver ────►│  DUT: asynchronous_fifo.v     │
  (wclk domain)    │                                │
                   │                                │◄── Scoreboard
  Read Monitor ◄───│                                │    (SV queue)
  (rclk domain)    │                                │
                    └───────────────────────────────┘


📊 Expected Simulation Results

A passing simulation in ModelSim/QuestaSim should show:

# INFO: Writing data: 8'hA3 | wptr = 001 | wfull = 0
# INFO: Writing data: 8'hF0 | wptr = 011 | wfull = 0
# INFO: Writing data: 8'h5C | wptr = 010 | wfull = 0
# ...
# INFO: FIFO FULL — Write suspended
# INFO: Reading data: 8'hA3 | rptr = 001 | rempty = 0
# INFO: Reading data: 8'hF0 | rptr = 011 | rempty = 0
# INFO: Reading data: 8'h5C | rptr = 010 | rempty = 0
# ...
# INFO: FIFO EMPTY — Read suspended
# ============================================
# TESTBENCH PASSED: All read data matched write data
# ============================================

Key observations to verify:


Write pointer increments in Gray code sequence
Read pointer increments in Gray code sequence
wfull asserts exactly when the FIFO is filled to capacity
rempty asserts when all written data has been read
No data mismatch reported by the scoreboard



🚀 How to Run — ModelSim / QuestaSim

Step 1: Clone the Repository

bashgit clone https://github.com/<your-username>/asynchronous-fifo.git
cd asynchronous-fifo

Step 2: Launch ModelSim and Compile

tcl# Create a work library
vlib work

# Compile RTL files
vlog rtl/fifo_mem.v
vlog rtl/synchronizer.v
vlog rtl/wptr_handler.v
vlog rtl/rptr_handler.v


# Compile SystemVerilog testbench
vlog -sv tb/async_fifo_TB.sv

Step 3: Simulate

tcl# Load the testbench top
vsim work.async_fifo_TB

# Add all signals to wave window
add wave -r /*

# Run simulation
run -all

Step 4: View Waveforms

Open the Wave window in ModelSim and observe:


wclk, rclk — independent clocks
winc, rinc — write/read enable signals
wdata, rdata — data signals
wptr, rptr — Gray-coded pointers
wfull, rempty — status flags



🌐 How to Run — EDA Playground


Navigate to https://www.edaplayground.com and create a free account.
Select Aldec Riviera-PRO or Synopsys VCS as the simulator.
Set the language to Verilog/SystemVerilog.
Paste the RTL files into the Design panel and the testbench into the Testbench panel.
Enable the "Open EPWave after run" checkbox to view waveforms.
Click Run and inspect the simulation log and waveform viewer.



🛠️ Tools Used

ToolPurposeVerilog HDL (IEEE 1364-2001)RTL design of FIFO and submodulesSystemVerilog (IEEE 1800-2012)Self-checking testbench developmentModelSim / QuestaSimFunctional simulation and waveform analysisEDA PlaygroundCloud-based simulation and sharingSynopsys SpyGlass CDC (compatible)CDC lint and metastability analysisGit / GitHubVersion control and project hosting


💼 Skills Demonstrated

This project showcases a range of skills directly relevant to RTL and digital design engineering roles:

Skill AreaDetailsRTL DesignParameterized, modular Verilog design with clean hierarchyClock Domain Crossing (CDC)Gray code synchronization, 2FF synchronizers, metastability mitigationDigital Design FundamentalsPointer arithmetic, wrap-around detection, flag generationSystemVerilog VerificationSelf-checking testbench, scoreboard queue, assertion-driven checkingSimulation & DebugWaveform analysis, functional verification with ModelSim/QuestaSimCode QualityParameterized design, $clog2() for scalability, clean module interfacesIndustry AwarenessCDC techniques consistent with Synopsys SpyGlass and Cadence JasperGold methodologies


🌍 Applications of Asynchronous FIFOs

Asynchronous FIFOs are a core building block across the semiconductor industry:


SoC Interconnects — AXI/AHB crossbar clock domain bridges
Memory Controllers — DDR4/LPDDR5 command and data buffering
High-Speed Serial Links — PCIe, USB 3.x, SATA data elastic buffers
Network-on-Chip (NoC) — Packet buffering between clock partitions
Video/Image Processing — Frame buffer management between capture and display clocks
Audio DSP Pipelines — Sample rate conversion and buffering
Wireless Baseband — Data transfer between modem and application processors
FPGA Design — Cross-clock domain communication in Xilinx/Intel FPGA fabrics



🔭 Future Improvements


 Add reset synchronization — Implement asynchronous assert, synchronous de-assert reset for both clock domains
 Almost-Full / Almost-Empty flags — Programmable threshold flags for flow control
 Formal Verification — SVA (SystemVerilog Assertions) and formal proofs using Cadence JasperGold or Synopsys VC Formal
 3FF Synchronizer option — Parameterizable sync stages for ultra-high-frequency designs
 FWFT (First Word Fall Through) mode — Output registered vs. FWFT mode select
 Error Injection Testing — Testbench coverage for boundary conditions (single-slot FIFO, power-of-2 and non-power-of-2 depths)
 Synthesis Reports — Add timing and area reports from Synopsys Design Compiler or Cadence Genus
 UVM Testbench — Migrate to a UVM-based verification environment for coverage-driven verification



👤 Author

[Sachin Kumar Mishra]


🎓 [MNNIT Allahabad,up]
💼 [[LinkedIn Profile URL](https://www.linkedin.com/in/sachin-kumar-mishra-334485280/)]
🐙 [https://github.com/sachin4144]



📄 License

This project is licensed under the MIT License.

MIT License

Copyright (c) 2024 [Your Name]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
