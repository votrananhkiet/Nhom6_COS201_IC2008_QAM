### Block Diagram
<img width="2560" height="867" alt="BlockDiagram" src="https://github.com/user-attachments/assets/4e1bc5e9-d470-4226-8471-9052e7d34f2c" />

### Flowchart
<img width="779" height="2940" alt="QAMFlowchart" src="https://github.com/user-attachments/assets/79229d14-8ed2-4f5b-b39e-2477e62f5fd6" />

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
