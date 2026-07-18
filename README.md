## Project Details

* **Group**: Group 6
* **Course**: COS201 - IC2008
* **Topic**: FPGA-based QAM Modulator Accelerator

## Overview
This project focuses on the research, design, and hardware optimization of a **16-QAM Modulator** implemented on an FPGA platform. The system evaluates and compares two primary carrier generation techniques: **Look-Up Table (LUT)** and the **CORDIC algorithm**, analyzing the trade-offs between memory utilization, logic resource consumption, and signal accuracy.

## Repository Structure
```text
Nhom6_COS201_IC2008_QAM/
├── colab/          # Google Colab notebooks (.ipynb) for algorithm simulation & EVM/BER analysis
├── verilog/        # RTL source files (.sv) and SystemVerilog testbenches
├── figures/        # Waveform captures, block diagrams, and performance plots
├── report/         # Final written report (.pdf)
└── README.md       # Project documentation and guidelines

```

## System Specifications

* **Modulation Scheme**: 16-QAM
* **Symbol Mapping**: [-96, -32, +32, +96] (Fixed-point scaling)
* **Pulse Shaping Filter**: 5-tap FIR Filter with coefficients $h_{int} = [16, 48, 64, 48, 16]$ (Scale factor = 64)
* **Design Configurations**:
* **LUT-based**: `phase_bits = 4` (16 entries)
* **CORDIC-based**: `iterations = 8`



## Key Performance Metrics

* **Signal Quality (EVM)**: Comparative noise analysis between LUT-based generation (higher noise floor due to phase quantization) and CORDIC-based generation (higher precision, higher latency).
* **Hardware Efficiency**: Comprehensive resource utilization metrics (LUTs, Flip-Flops, DSP blocks) and latency evaluation across both hardware architectures.

## Getting Started

1. **Algorithm Simulation**: Run the notebooks in `colab/` to verify mathematical models and fixed-point precision.
2. **RTL Verification**: Load the SystemVerilog files in `verilog/` into Vivado, ModelSim, or EDA Playground. Compare simulated output waveforms against reference figures in `figures/` (Radix set to Signed Decimal).
3. **Documentation**: Refer to `report/QAM_Final_Report.pdf` for full theoretical derivations and design methodologies.

```

```
