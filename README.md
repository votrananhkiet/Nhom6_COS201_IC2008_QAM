### Block Diagram
<img width="2560" height="867" alt="BlockDiagram" src="https://github.com/user-attachments/assets/4e1bc5e9-d470-4226-8471-9052e7d34f2c" />

### Flowchart
<img width="779" height="2940" alt="QAMFlowchart" src="https://github.com/user-attachments/assets/79229d14-8ed2-4f5b-b39e-2477e62f5fd6" />

### 1. File `qam_lut_full_top.v`

| Tên Tín Hiệu | Hướng (Direction) | Độ rộng Bit | Định dạng số | Chức năng & Mô tả chi tiết |
| :--- | :---: | :---: | :---: | :--- |
| `clk` | Input | 1 bit | Wire | Xung nhịp đồng bộ toàn hệ thống (Global Clock). |
| `rst` | Input | 1 bit | Wire | Tín hiệu khởi tạo/đặt lại trạng thái hệ thống (Reset tích cực cao). |
| `bits_in` | Input | 4 bits | Wire (Unsigned) | Chuỗi 4 bit dữ liệu nhị phân đầu vào biểu diễn cho một Symbol 16-QAM. |
| `bits_show` | Output | 8 bits | Wire (Unsigned) | Cổng xuất 8-bit debug mở rộng (`{4'b0, bits_in}`) phục vụ quan sát dạng sóng. |
| `phase_show` | Output | 8 bits | Wire (Unsigned) | Cổng xuất 8-bit debug địa chỉ pha sóng mang hiện tại (`{4'b0, phase_cnt}`). |
| `up_count_show` | Output | 8 bits | Wire (Unsigned) | Cổng xuất 8-bit debug bộ đếm tăng mẫu nội suy (`{6'b0, up_count}`). |
| `I_sym` / `Q_sym` | Output | 8 bits | Wire (Signed) | Biên độ thành phần I/Q sau bộ ánh xạ Gray Code ($[-96, -32, +32, +96]$). |
| `I_up` / `Q_up` | Output | 8 bits | Reg (Signed) | Tín hiệu I/Q sau khối Upsampler $L=4$ (Chèn các điểm mẫu số 0). |
| `I_filt` / `Q_filt` | Output | 8 bits | Reg (Signed) | Tín hiệu I/Q sau bộ lọc định hình xung FIR 5-tap ($h_{int} = [16, 48, 64, 48, 16]$, Scale = 64, bão hòa 8-bit). |
| `cos_val` / `sin_val` | Output | 8 bits | Reg (Signed) | Biên độ sóng mang Sine/Cosine trích xuất từ bảng tra ROM LUT 16 entries (Scale = 127). |
| `qam_out` | Output | 16 bits | Reg (Signed) | Tín hiệu QAM số đầu ra: $qam\_out = \lfloor (I_{filt} \cdot cos_{val} - Q_{filt} \cdot sin_{val}) / 128 \rfloor$. |

---

### 2. File `qam_lut_full_top.sdc`

| Tham số / Ràng buộc | Đối tượng tác động | Chu kỳ / Tần số | Lệnh SDC Syntax | Chức năng & Mục đích thiết lập Timing Constraint |
| :--- | :---: | :---: | :---: | :--- |
| `clk` (Clock Name) | Port `{clk}` | $50\text{ MHz}$ ($20.000\text{ ns}$) | `create_clock -name clk -period 20.000 [get_ports {clk}]` | Khai báo xung nhịp chính cho hệ thống để Timing Analyzer tính toán timing slack và tần số hoạt động tối đa ($F_{max}$). |

---

### 3. File `quartus_cordic.v`

| Tên Tín Hiệu | Hướng (Direction) | Độ rộng Bit | Định dạng số | Chức năng & Mô tả chi tiết |
| :--- | :---: | :---: | :---: | :--- |
| `clk` | Input | 1 bit | Wire | Xung nhịp đồng bộ hệ thống và điều khiển chuỗi 8 tầng đường ống (Pipeline Clock). |
| `rst` | Input | 1 bit | Wire | Tín hiệu Reset hệ thống, xóa mảng thanh ghi pipeline CORDIC và thanh ghi căn chỉnh trễ. |
| `bits_in` | Input | 4 bits | Wire (Unsigned) | Chuỗi 4 bit dữ liệu nhị phân đầu vào cho một Symbol 16-QAM. |
| `bits_show` / `phase_show` / `up_count_show` | Output | 8 bits mỗi cổng | Wire (Unsigned) | Các cổng xuất tín hiệu mở rộng 8-bit phục vụ hiển thị dạng sóng debug. |
| `I_sym` / `Q_sym` | Output | 8 bits | Wire (Signed) | Biên độ I/Q sau khối 16-QAM Mapper Gray coding ($[-96, -32, +32, +96]$). |
| `I_up` / `Q_up` | Output | 8 bits | Reg (Signed) | Tín hiệu I/Q sau bộ tăng mẫu Upsampler nội suy $L=4$. |
| `I_filt` / `Q_filt` | Output | 8 bits | Reg (Signed) | Tín hiệu I/Q sau lọc định hình xung FIR 5-tap ($h_{int} = [16, 48, 64, 48, 16]$, Scale = 64). |
| `cos_val` / `sin_val` | Output | 8 bits | Reg (Signed) | Biên độ sóng mang Sine/Cosine sinh ra từ lõi 8-stage Pipelined CORDIC (Scale = 127). |
| `I_align` / `Q_align` | Internal | 8 bits (Mảng 9 tầng) | Reg (Signed) | Mảng thanh ghi hoãn trễ 8 chu kỳ clock nhằm đồng bộ thời gian giữa đường dữ liệu I/Q và CORDIC Carrier. |
| `qam_out` | Output | 16 bits | Reg (Signed) | Tín hiệu QAM số đầu ra: $qam\_out = \lfloor (I_{align} \cdot cos_{val} - Q_{align} \cdot sin_{val}) / 128 \rfloor$. |

---

### 4. File `quartus_cordic.v.bak`

| Tên Tín Hiệu / Thành phần | Phân loại | Độ rộng Bit | Định dạng số | Chức năng & Mô tả chi tiết |
| :--- | :---: | :---: | :---: | :--- |
| `bits_in` | Input | 4 bits | Wire (Unsigned) | Chuỗi bit dữ liệu kiểm thử đầu vào của bản thiết kế CORDIC sơ khai. |
| `I_map` / `Q_map` | Internal | 8 bits | Reg (Signed) | Mức biên độ phân giải I/Q sau khối `qam_mapper` Gray coding. |
| `phase_cnt` | Internal | 10 bits | Reg (Unsigned) | Địa chỉ pha nạp vào lõi CORDIC tổ hợp (1024 góc đơn vị / chu kỳ, bước tăng 64). |
| `cos_val` / `sin_val` | Output | 8 bits | Reg (Signed) | Biên độ sóng mang Sine/Cosine tính toán bằng vòng lặp CORDIC tổ hợp (Non-pipelined). |
| `qam_out` | Output | 16 bits | Reg (Signed) | Tín hiệu QAM số đầu ra điều chế trực tiếp. |
| `Ghi chú phiên bản` | File Backup | - | - | Bản lưu trữ cấu trúc CORDIC cũ trước khi tối ưu nâng cấp lên Pipelined 8 tầng. |

---

### 5. File `qam_cordic_full_top.sdc`

| Tham số / Ràng buộc | Đối tượng tác động | Chu kỳ / Tần số | Lệnh SDC Syntax | Chức năng & Mục đích thiết lập Timing Constraint |
| :--- | :---: | :---: | :---: | :--- |
| `clk` (Clock Name) | Port `{clk}` | $50\text{ MHz}$ ($20.000\text{ ns}$) | `create_clock -name clk -period 20.000 [get_ports {clk}]` | Khai báo xung nhịp đồng bộ cho mạch CORDIC 8 tầng Pipelined trên Quartus Prime. |
