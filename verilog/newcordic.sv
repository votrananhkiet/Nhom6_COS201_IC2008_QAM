`timescale 1ns/1ps

// qam_cordic_full.v
// CORDIC-based 16-QAM Modulator
// Flow: Mapper -> Upsampler L=4 -> FIR 5-tap -> CORDIC NCO -> Mixer

// =====================================================
// 16-QAM Mapper
// bits_in[3:2] -> I
// bits_in[1:0] -> Q
//
// Gray mapping:
// 00 -> -3
// 01 -> -1
// 11 -> +1
// 10 -> +3
//
// Scale:
// -3 -> -96
// -1 -> -32
// +1 -> +32
// +3 -> +96
// =====================================================
module qam_mapper (
    input  [3:0] bits_in,
    output reg signed [7:0] I_map,
    output reg signed [7:0] Q_map
);

    always @(*) begin
        case (bits_in[3:2])
            2'b00: I_map = -8'sd96;
            2'b01: I_map = -8'sd32;
            2'b11: I_map =  8'sd32;
            2'b10: I_map =  8'sd96;
            default: I_map = 8'sd0;
        endcase

        case (bits_in[1:0])
            2'b00: Q_map = -8'sd96;
            2'b01: Q_map = -8'sd32;
            2'b11: Q_map =  8'sd32;
            2'b10: Q_map =  8'sd96;
            default: Q_map = 8'sd0;
        endcase
    end

endmodule


// =====================================================
// CORDIC NCO
// phase_addr: 4 bit -> 16 phase points per period
// 1 circle = 1024 angle units
// sin/cos scale = 127
//
// This is a simple 8-iteration CORDIC model for RTL simulation.
// =====================================================
module cordic_sincos (
  input  [9:0] phase_addr,
    output reg signed [7:0] cos_val,
    output reg signed [7:0] sin_val
);

    reg signed [15:0] x;
    reg signed [15:0] y;
    reg signed [15:0] z;

    reg signed [15:0] x_new;
    reg signed [15:0] y_new;

    reg signed [15:0] phase_full;
    reg signed [15:0] cos_temp;
    reg signed [15:0] sin_temp;

    reg sign_change;
    integer i;

    // arctan(2^-i), scale theo 1024 unit / 360 do
    function signed [15:0] atan_value;
        input integer index;
        begin
            case (index)
                0: atan_value = 16'sd128;
                1: atan_value = 16'sd76;
                2: atan_value = 16'sd40;
                3: atan_value = 16'sd20;
                4: atan_value = 16'sd10;
                5: atan_value = 16'sd5;
                6: atan_value = 16'sd3;
                7: atan_value = 16'sd1;
                default: atan_value = 16'sd0;
            endcase
        end
    endfunction

    // gioi han ve 8 bit signed
    function signed [7:0] sat8_small;
        input signed [15:0] value;
        begin
            if (value > 16'sd127)
                sat8_small = 8'sd127;
            else if (value < -16'sd127)
                sat8_small = -8'sd127;
            else
                sat8_small = value[7:0];
        end
    endfunction

    always @(*) begin
        // phase_addr 0..15 doi sang 0..960
        // moi buoc = 1024 / 16 = 64
      phase_full = {6'd0, phase_addr};

        // Dua goc ve khoang -90 do den +90 do
        // De CORDIC tinh de hon, sau do doi dau lai theo quadrant
        if (phase_full <= 16'sd256) begin
            z = phase_full;
            sign_change = 1'b0;
        end
        else if (phase_full < 16'sd512) begin
            z = phase_full - 16'sd512;
            sign_change = 1'b1;
        end
        else if (phase_full <= 16'sd768) begin
            z = phase_full - 16'sd512;
            sign_change = 1'b1;
        end
        else begin
            z = phase_full - 16'sd1024;
            sign_change = 1'b0;
        end

        // x ban dau da nhan he so K cua CORDIC
        // 127 * 0.607 gan bang 77
        x = 16'sd77;
        y = 16'sd0;

        // CORDIC 8 iterations
        for (i = 0; i < 8; i = i + 1) begin
            if (z >= 0) begin
                x_new = x - (y >>> i);
                y_new = y + (x >>> i);
                z = z - atan_value(i);
            end
            else begin
                x_new = x + (y >>> i);
                y_new = y - (x >>> i);
                z = z + atan_value(i);
            end

            x = x_new;
            y = y_new;
        end

        // Neu goc nam o quadrant II hoac III thi doi dau ca cos va sin
        if (sign_change) begin
            cos_temp = -x;
            sin_temp = -y;
        end
        else begin
            cos_temp = x;
            sin_temp = y;
        end

        cos_val = sat8_small(cos_temp);
        sin_val = sat8_small(sin_temp);
    end

endmodule


// =====================================================
// Main CORDIC-based QAM Modulator
// =====================================================
module qam_cordic_full_top (
    input clk,
    input rst,
    input [3:0] bits_in,

    output [7:0] bits_show,
    output [7:0] phase_show,
    output [7:0] up_count_show,

    output reg signed [7:0] I_sym,
    output reg signed [7:0] Q_sym,

    output reg signed [7:0] I_up,
    output reg signed [7:0] Q_up,

    output reg signed [7:0] I_filt,
    output reg signed [7:0] Q_filt,

    output reg signed [7:0] cos_val,
    output reg signed [7:0] sin_val,

    output reg signed [15:0] qam_out
);

    // counter cho upsampler L = 4
    reg [1:0] up_count;

    // counter phase cho CORDIC
  reg [9:0] phase_cnt;

    // debug signals de waveform de nhin hon
    reg [3:0] bits_used;
  reg [9:0] phase_used;
    reg [1:0] up_count_used;

    assign bits_show     = {4'b0000, bits_used};
    assign phase_show    = {4'b0000, phase_used};
    assign up_count_show = {6'b000000, up_count_used};

    // mapper output
    wire signed [7:0] I_map;
    wire signed [7:0] Q_map;

    qam_mapper u_mapper (
        .bits_in(bits_in),
        .I_map(I_map),
        .Q_map(Q_map)
    );

    // CORDIC carrier output
    wire signed [7:0] cos_wire;
    wire signed [7:0] sin_wire;

    cordic_sincos u_cordic (
        .phase_addr(phase_cnt),
        .cos_val(cos_wire),
        .sin_val(sin_wire)
    );

    // =================================================
    // Upsampler L = 4
    // up_count = 0: lay symbol that
    // up_count = 1,2,3: chen 0
    // =================================================
    wire signed [7:0] I_up_next;
    wire signed [7:0] Q_up_next;

    assign I_up_next = (up_count == 2'd0) ? I_map : 8'sd0;
    assign Q_up_next = (up_count == 2'd0) ? Q_map : 8'sd0;

    // delay line cho FIR
    reg signed [7:0] I_d1, I_d2, I_d3, I_d4;
    reg signed [7:0] Q_d1, Q_d2, Q_d3, Q_d4;

    // =================================================
    // FIR 5-tap
    //
    // h = [0.25, 0.75, 1.0, 0.75, 0.25]
    //
    // doi sang fixed-point bang cach nhan 64:
    // h_int = [16, 48, 64, 48, 16]
    //
    // sau khi cong xong chia lai cho 64 bang >>> 6
    // =================================================
    wire signed [19:0] I_fir_sum;
    wire signed [19:0] Q_fir_sum;

    assign I_fir_sum =
        (I_up_next * 8'sd16) +
        (I_d1      * 8'sd48) +
        (I_d2      * 8'sd64) +
        (I_d3      * 8'sd48) +
        (I_d4      * 8'sd16);

    assign Q_fir_sum =
        (Q_up_next * 8'sd16) +
        (Q_d1      * 8'sd48) +
        (Q_d2      * 8'sd64) +
        (Q_d3      * 8'sd48) +
        (Q_d4      * 8'sd16);

    wire signed [19:0] I_fir_scaled;
    wire signed [19:0] Q_fir_scaled;

    assign I_fir_scaled = I_fir_sum >>> 6;
    assign Q_fir_scaled = Q_fir_sum >>> 6;

    // saturation ve 8 bit signed
    function signed [7:0] sat8;
        input signed [19:0] x;
        begin
            if (x > 20'sd127)
                sat8 = 8'sd127;
            else if (x < -20'sd128)
                sat8 = -8'sd128;
            else
                sat8 = x[7:0];
        end
    endfunction

    wire signed [7:0] I_filt_next;
    wire signed [7:0] Q_filt_next;

    assign I_filt_next = sat8(I_fir_scaled);
    assign Q_filt_next = sat8(Q_fir_scaled);

    // =================================================
    // Mixer QAM
    // cong thuc: s = I*cos - Q*sin
    //
    // sin/cos scale = 127 nen chia lai gan 128 bang >>> 7
    // =================================================
    wire signed [15:0] I_cos;
    wire signed [15:0] Q_sin;
    wire signed [16:0] mix_temp;
    wire signed [15:0] qam_next;

    assign I_cos = I_filt_next * cos_wire;
    assign Q_sin = Q_filt_next * sin_wire;

    assign mix_temp = {I_cos[15], I_cos} - {Q_sin[15], Q_sin};
    assign qam_next = mix_temp >>> 7;

    // =================================================
    // Phan sequential
    // =================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            up_count <= 2'd0;
            phase_cnt <= 4'd0;

            bits_used <= 4'd0;
            phase_used <= 4'd0;
            up_count_used <= 2'd0;

            I_sym <= 8'sd0;
            Q_sym <= 8'sd0;

            I_up <= 8'sd0;
            Q_up <= 8'sd0;

            I_d1 <= 8'sd0;
            I_d2 <= 8'sd0;
            I_d3 <= 8'sd0;
            I_d4 <= 8'sd0;

            Q_d1 <= 8'sd0;
            Q_d2 <= 8'sd0;
            Q_d3 <= 8'sd0;
            Q_d4 <= 8'sd0;

            I_filt <= 8'sd0;
            Q_filt <= 8'sd0;

            cos_val <= 8'sd0;
            sin_val <= 8'sd0;

            qam_out <= 16'sd0;
        end
        else begin
            // luu gia tri debug dung voi chu ky hien tai
            bits_used <= bits_in;
            phase_used <= phase_cnt;
            up_count_used <= up_count;

            // output mapper
            I_sym <= I_map;
            Q_sym <= Q_map;

            // output upsampler
            I_up <= I_up_next;
            Q_up <= Q_up_next;

            // shift register FIR
            I_d4 <= I_d3;
            I_d3 <= I_d2;
            I_d2 <= I_d1;
            I_d1 <= I_up_next;

            Q_d4 <= Q_d3;
            Q_d3 <= Q_d2;
            Q_d2 <= Q_d1;
            Q_d1 <= Q_up_next;

            // output sau FIR
            I_filt <= I_filt_next;
            Q_filt <= Q_filt_next;

            // output CORDIC
            cos_val <= cos_wire;
            sin_val <= sin_wire;

            // output QAM
            qam_out <= qam_next;

            // cap nhat counter
            up_count <= up_count + 2'd1;
            phase_cnt <= phase_cnt + 10'd1;
        end
    end

endmodule