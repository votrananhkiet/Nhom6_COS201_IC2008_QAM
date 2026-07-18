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

### 1. File `qam_lut_design.sv`

| Tên Tín Hiệu | Hướng (Direction) | Độ rộng Bit | Định dạng số | Chức năng & Mô tả chi tiết |
| :--- | :---: | :---: | :---: | :--- |
| `clk` | Input | 1 bit | Wire | Xung nhịp đồng bộ toàn hệ thống (Global Clock). |
| `rst` | Input | 1 bit | Wire | Tín hiệu khởi tạo/đặt lại trạng thái hệ thống (Reset). |
| `bits_show` | Input | 4 bits | Wire (Unsigned) | Chuỗi 4 bit dữ liệu nhị phân đầu vào cho một Symbol. |
| `qam_out` | Output | 16 bits | Wire (Signed) | Tín hiệu QAM số đầu ra: $qam\_out = I_{filt} \cdot cos_{val} - Q_{filt} \cdot sin_{val}$. |
| `I_sym` / `Q_sym` | Internal | 8 bits | Reg (Signed) | Biên độ thành phần I/Q sau mã hóa Gray ($[-96, -32, +32, +96]$). |
| `I_up` / `Q_up` | Internal | 8 bits | Wire (Signed) | Tín hiệu sau bộ tăng mẫu nội suy (Chèn các điểm số 0 - Zero-stuffing). |
| `I_filt` / `Q_filt`| Internal | 16 bits | Reg (Signed) | Tín hiệu dòng I/Q sau bộ lọc định hình xung FIR 5-tap (Scale = 64). |
| `cos_val` / `sin_val`| Internal | 8 bits | Wire (Signed) | Biên độ sóng mang Sine/Cosine trích xuất từ bảng tra ROM 16 entries (Scale = 127). |

---

### 2. File `qam_cordic_design.sv`

| Tên Tín Hiệu | Hướng (Direction) | Độ rộng Bit | Định dạng số | Chức năng & Mô tả chi tiết |
| :--- | :---: | :---: | :---: | :--- |
| `clk` | Input | 1 bit | Wire | Xung nhịp đồng bộ toàn hệ thống (Global Clock). |
| `rst` | Input | 1 bit | Wire | Tín hiệu khởi tạo/đặt lại trạng thái hệ thống (Reset). |
| `bits_show` | Input | 4 bits | Wire (Unsigned) | Chuỗi 4 bit dữ liệu nhị phân đầu vào cho một Symbol. |
| `qam_out` | Output | 16 bits | Wire (Signed) | Tín hiệu QAM số đầu ra tổng hợp từ lõi trộn CORDIC. |
| `I_sym` / `Q_sym` | Internal | 8 bits | Reg (Signed) | Biên độ thành phần I/Q sau mã hóa Gray ($[-96, -32, +32, +96]$). |
| `I_filt` / `Q_filt`| Internal | 16 bits | Reg (Signed) | Tín hiệu dòng I/Q sau bộ lọc định hình xung FIR 5-tap (Scale = 64). |
| `cos_val` / `sin_val`| Internal | 8 bits | Wire (Signed) | Biên độ sóng mang Sine/Cosine sinh ra từ chuỗi xoay tọa độ số CORDIC qua 8 stages (Scale = 127). |

---

### 3. File `qam_lut_tb.sv`

| Tên Tín Hiệu / Biến | Phân loại | Độ rộng Bit | Kiểu dữ liệu | Chức năng & Kịch bản tạo kích thích (Stimulus) |
| :--- | :---: | :---: | :---: | :--- |
| `clk` | Kích thích | 1 bit | reg | Tự động đảo trạng thái sau mỗi 5ns nhằm tạo xung nhịp chu kỳ 10ns. |
| `rst` | Kích thích | 1 bit | reg | Khởi tạo mức 1 để Reset hệ thống, chuyển về mức 0 sau 20ns để mạch chạy. |
| `bits_show` | Kích thích | 4 bits | reg | Phát chuỗi bit kiểm thử thay đổi liên tục theo từng chu kỳ Symbol mẫu. |
| `qam_out` | Giám sát | 16 bits | wire (Signed) | Đường dây hứng tín hiệu điều chế từ module UUT gửi sang bộ hiển thị EPWave. |

---

### 4. File `qam_cordic_tb.sv`

| Tên Tín Hiệu / Biến | Phân loại | Độ rộng Bit | Kiểu dữ liệu | Chức năng & Kịch bản tạo kích thích (Stimulus) |
| :--- | :---: | :---: | :---: | :--- |
| `clk` | Kích thích | 1 bit | reg | Tự động đảo trạng thái tạo xung nhịp chu kỳ ổn định cho mô phỏng phần cứng. |
| `rst` | Kích thích | 1 bit | reg | Kích hoạt chu kỳ Reset mềm ban đầu để thiết lập các thanh ghi dịch CORDIC. |
| `bits_show` | Kích thích | 4 bits | reg | Nạp các Symbol dữ liệu đầu vào phục vụ đo đạc latency đường ống của thuật toán. |
| `qam_out` | Giám sát | 16 bits | wire (Signed) | Hứng dòng dữ liệu đầu ra để kiểm tra biên độ dạng sóng điều chế mịn (EVM tối ưu). |

```
