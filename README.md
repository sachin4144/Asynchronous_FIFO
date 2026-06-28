# 🚀 Asynchronous FIFO using Gray Code Pointer Synchronization

![Verilog](https://img.shields.io/badge/Language-Verilog-blue)
![SystemVerilog](https://img.shields.io/badge/Testbench-SystemVerilog-orange)
![RTL Design](https://img.shields.io/badge/Domain-RTL%20Design-green)
![CDC](https://img.shields.io/badge/Clock%20Domain%20Crossing-CDC-red)
![License](https://img.shields.io/badge/License-MIT-yellow)

---

## 📌 Project Overview

This project implements a **parameterized Asynchronous FIFO** in **Verilog HDL** for reliable data transfer between two independent clock domains.

The design uses **Gray Code Pointer Synchronization** and **Two Flip-Flop (2FF) Synchronizers** to safely transfer pointer information across clock domains while minimizing the probability of metastability.

The project follows a modular RTL design approach and includes a **self-checking SystemVerilog testbench** for functional verification.

---

## ❓ Why Asynchronous FIFO?

In modern digital systems, different modules often operate on different clock frequencies.

Examples include:

- Processor ↔ Peripheral
- DDR Controller ↔ System Bus
- PCIe ↔ Internal Logic
- Camera ↔ Display Pipeline

Directly transferring multi-bit signals between unrelated clocks can lead to **metastability** and **data corruption**.

An **Asynchronous FIFO** solves this problem by:

- Buffering data between two clock domains
- Synchronizing only the control pointers
- Preserving data integrity
- Preventing overflow and underflow

---

# ✨ Features

- Parameterized FIFO Depth
- Parameterized Data Width
- Independent Read and Write Clock Domains
- Binary-to-Gray Code Conversion
- Two Flip-Flop Pointer Synchronization
- Full Flag Generation
- Empty Flag Generation
- Modular RTL Design
- Self-checking SystemVerilog Testbench
- Verified using ModelSim/QuestaSim and EDA Playground

---

# 🏗️ Architecture

```
                    +---------------------------+
                    |   asynchronous_fifo.v     |
                    +---------------------------+
                               |
        -------------------------------------------------
        |                |                |             |
        |                |                |             |
+---------------+ +---------------+ +-------------+ +--------------+
| wptr_handler  | | rptr_handler  | | synchronizer| | synchronizer |
+---------------+ +---------------+ +-------------+ +--------------+
                \                  /
                 \                /
                  \              /
                   +------------+
                   | fifo_mem.v |
                   +------------+
```

---

# 📂 Repository Structure

```
Asynchronous_FIFO/
│
├── asynchronous_fifo.v      # Top-level module
├── fifo_mem.v               # FIFO memory
├── synchronizer.v           # Two-FF synchronizer
├── wptr_handler.v           # Write pointer & Full flag
├── rptr_handler.v           # Read pointer & Empty flag
├── async_fifo_TB.sv         # Self-checking testbench
├── README.md

```

---

# ⚙️ Design Specifications

| Parameter | Description |
|-----------|-------------|
| Language | Verilog HDL |
| Testbench | SystemVerilog |
| FIFO Type | Asynchronous FIFO |
| Synchronization | Gray Code + 2FF Synchronizer |
| Memory | Dual-Port FIFO Memory |
| Read Clock | Independent |
| Write Clock | Independent |
| Verification | Self-checking Testbench |

---

# 🔑 Key Design Modules

### 1. synchronizer.v

Implements a **two-stage flip-flop synchronizer** to safely transfer Gray-coded pointers between asynchronous clock domains.

---

### 2. wptr_handler.v

Responsible for:

- Binary write pointer generation
- Gray code conversion
- Full flag generation

---

### 3. rptr_handler.v

Responsible for:

- Binary read pointer generation
- Gray code conversion
- Empty flag generation

---

### 4. fifo_mem.v

Implements the dual-port FIFO memory.

- Write operations occur in the write clock domain.
- Read operations occur in the read clock domain.

---

### 5. asynchronous_fifo.v

Top-level module integrating:

- FIFO memory
- Pointer handlers
- Synchronizers

Provides the complete FIFO interface to the external system.

---



# ⚙️ Working Principle

The asynchronous FIFO enables reliable data transfer between two independent clock domains by separating the write and read operations.

### Write Operation (`wclk` Domain)

- Data is written into the FIFO memory when:
  - `w_en = 1`
  - FIFO is **not full**
- The binary write pointer increments after every successful write.
- The binary pointer is converted into **Gray code**.
- The Gray-coded write pointer is synchronized into the read clock domain using a **2-Flip-Flop synchronizer**.

---

### Read Operation (`rclk` Domain)

- Data is read from the FIFO memory when:
  - `r_en = 1`
  - FIFO is **not empty**
- The binary read pointer increments after every successful read.
- The binary pointer is converted into **Gray code**.
- The Gray-coded read pointer is synchronized into the write clock domain using another **2-Flip-Flop synchronizer**.

---

### Pointer Synchronization

Only the **Gray-coded pointers** cross clock domains.

The actual FIFO memory **never crosses clock domains**, making the data path inherently safe.

```
Write Clock Domain                 Read Clock Domain

 Binary WPtr
      │
      ▼
 Gray WPtr
      │
      ▼
+----------------+
| 2FF Sync       |
+----------------+
      │
      ▼
Gray WPtr Sync ----------------------► Empty Logic


 Binary RPtr
      │
      ▼
 Gray RPtr
      │
      ▼
+----------------+
| 2FF Sync       |
+----------------+
      │
      ▼
Gray RPtr Sync ----------------------► Full Logic
```

---

# 🩶 Gray Code Synchronization

## Why Gray Code?

A binary counter may change multiple bits simultaneously.

Example:

| Decimal | Binary |
|---------:|:------:|
| 3 | 011 |
| 4 | 100 |

Three bits change together.

If another clock samples this transition, it may capture an invalid intermediate value.

Gray code solves this issue because **only one bit changes between consecutive values.**

| Decimal | Binary | Gray |
|---------:|:------:|:----:|
| 0 | 000 | 000 |
| 1 | 001 | 001 |
| 2 | 010 | 011 |
| 3 | 011 | 010 |
| 4 | 100 | 110 |
| 5 | 101 | 111 |

Only a single bit changes during each increment, making it suitable for clock domain crossing.

### Binary to Gray Conversion

```verilog
gray = binary ^ (binary >> 1);
```

---

# 🔄 Two Flip-Flop Synchronizer

Each Gray-coded pointer passes through a **two-stage synchronizer** before entering the destination clock domain.

```
Gray Pointer
      │
      ▼
+------------+
| Flip-Flop1 |
+------------+
      │
      ▼
+------------+
| Flip-Flop2 |
+------------+
      │
      ▼
Synchronized Pointer
```

### Purpose

- Reduces the probability of metastability.
- Allows the first flip-flop sufficient time to resolve any metastable state.
- Provides a stable synchronized pointer for flag generation.

This is one of the most widely used CDC techniques in digital ASIC and FPGA designs.

---

# ⚠️ Metastability

Metastability occurs when a flip-flop samples a signal that changes very close to its setup or hold time.

Possible effects include:

- Unknown logic levels
- Incorrect flag generation
- Data corruption
- System failure

The asynchronous FIFO mitigates this risk by:

- Synchronizing only the Gray-coded pointers.
- Using two-stage synchronizers.
- Keeping the data path independent of CDC synchronization.

---

# 🚦 Full and Empty Flag Generation

## Empty Flag

The FIFO is **empty** when the synchronized write pointer equals the current read pointer.

```verilog
empty = (g_wptr_sync == g_rptr_next);
```

This comparison is performed in the **read clock domain**.

---

## Full Flag

The FIFO is **full** when the next Gray-coded write pointer becomes one complete wrap ahead of the synchronized read pointer.

```verilog
full =
(g_wptr_next ==
 {~g_rptr_sync[PTR_WIDTH:PTR_WIDTH-1],
   g_rptr_sync[PTR_WIDTH-2:0]});
```

This comparison is performed in the **write clock domain**.

The inversion of the two most significant bits enables detection of the pointer wrap-around condition.

---

# 🔀 Clock Domain Crossing (CDC)

This project demonstrates several important CDC concepts commonly used in RTL design.

| CDC Feature | Implementation |
|-------------|----------------|
| Independent Clocks | ✔ |
| Gray Code Pointer Synchronization | ✔ |
| Two Flip-Flop Synchronizers | ✔ |
| Safe Pointer Transfer | ✔ |
| Full/Empty Generation | ✔ |
| Metastability Mitigation | ✔ |
| Modular CDC Design | ✔ |

The FIFO transfers **only control information (pointers)** across clock domains.

The **data itself remains inside the dual-port memory**, avoiding unnecessary synchronization and improving reliability.

---

# 💡 Design Highlights

- Parameterized architecture for easy scalability.
- Clean modular RTL design.
- Separate read and write clock domains.
- Gray code synchronization for reliable CDC.
- Two-stage synchronizers for metastability mitigation.
- Independent full and empty flag generation.
- Industry-standard asynchronous FIFO architecture.



# 🧪 Verification

The design is verified using a **self-checking SystemVerilog testbench**.

### Verification Features

- Independent write and read clocks
- Randomized write/read transactions
- Queue-based scoreboard
- Automatic PASS/FAIL reporting
- Full and Empty flag verification
- Functional verification using ModelSim/QuestaSim and EDA Playground

---

# 📊 Simulation Results

The simulation verifies that:

- ✔ Data is written correctly into the FIFO.
- ✔ Data is read in the correct FIFO order.
- ✔ Full flag asserts when the FIFO is full.
- ✔ Empty flag asserts when the FIFO is empty.
- ✔ No data corruption occurs during clock domain crossing.
- ✔ Data integrity is maintained for asynchronous clocks.

Example simulation output:

```
PASS Expected=03 Received=03
PASS Expected=60 Received=60
PASS Expected=6E Received=6E
PASS Expected=3F Received=3F
PASS Expected=D9 Received=D9
PASS Expected=DD Received=DD

========== Simulation Finished ==========


# 🚀 Running the Project

## ModelSim / QuestaSim

### Compile

```tcl
vlib work

vlog synchronizer.v
vlog wptr_handler.v
vlog rptr_handler.v
vlog fifo_mem.v
vlog asynchronous_fifo.v
vlog -sv async_fifo_TB.sv
```

### Simulate

```tcl
vsim work.async_fifo_TB

add wave *

run -all
```

---

## EDA Playground

1. Open https://www.edaplayground.com
2. Select **SystemVerilog**
3. Choose **ModelSim** or **QuestaSim**
4. Paste the RTL files and testbench
5. Run the simulation
6. Open EPWave to view waveforms

---

# 🛠️ Tools Used

| Tool | Purpose |
|------|---------|
| Verilog HDL | RTL Design |
| SystemVerilog | Testbench |
| ModelSim / QuestaSim | Functional Simulation |
| EDA Playground | Online Simulation |
| Git & GitHub | Version Control |

---

# 📚 Concepts Covered

This project demonstrates:

- RTL Design
- Clock Domain Crossing (CDC)
- Gray Code
- Binary-to-Gray Conversion
- Two Flip-Flop Synchronizer
- Metastability Mitigation
- FIFO Design
- Parameterized Verilog
- Functional Verification
- Self-checking Testbench
- Scoreboard-based Verification

---

# 🌍 Applications

Asynchronous FIFOs are widely used in:

- SoC Interconnects
- AXI/AHB Bus Bridges
- DDR Memory Controllers
- PCIe Interfaces
- USB Controllers
- Ethernet MACs
- Camera Interfaces
- Video Processing Pipelines
- Audio DSP Systems
- FPGA Designs

---

# 🔮 Future Improvements

Possible enhancements include:

- Almost Full / Almost Empty flags
- Configurable Synchronizer Stages (2FF/3FF)
- First Word Fall Through (FWFT)
- SystemVerilog Assertions (SVA)
- Functional Coverage
- UVM-based Verification Environment
- Formal Verification
- Synthesis and Timing Reports

---

# 📂 Project Highlights

- Parameterized FIFO Architecture
- Modular RTL Design
- Safe Clock Domain Crossing
- Gray Code Pointer Synchronization
- Two Flip-Flop Synchronizers
- Full & Empty Flag Logic
- Self-checking Verification Environment

---

# 👨‍💻 Author

**Sachin Kumar Mishra**

- 🎓 Motilal Nehru National Institute of Technology (MNNIT), Prayagraj
- 💼 LinkedIn: https://www.linkedin.com/in/sachin-kumar-mishra-334485280/
- 🐙 GitHub: https://github.com/sachin4144
- 📧 Email: mishra1692006@gmail.com

---

# 📜 License

This project is licensed under the MIT License.

Feel free to use, modify, and distribute this project for educational and research purposes.

---

## ⭐ If you found this project helpful, consider giving it a star!
