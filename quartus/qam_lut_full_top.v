// qam_lut_full.v
// LUT-based 16-QAM Modulator
// Flow:
// Mapper -> Upsampler L=4 -> FIR 5-tap -> LUT NCO -> Mixer

// =====================================================
// 16-QAM Mapper
// 4 bit input:
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
    output reg signed [7:0] I_sym,
    output reg signed [7:0] Q_sym
);

    always @(*) begin
        case (bits_in[3:2])
            2'b00: I_sym = -8'sd96;
            2'b01: I_sym = -8'sd32;
            2'b11: I_sym =  8'sd32;
            2'b10: I_sym =  8'sd96;
            default: I_sym = 8'sd0;
        endcase

        case (bits_in[1:0])
            2'b00: Q_sym = -8'sd96;
            2'b01: Q_sym = -8'sd32;
            2'b11: Q_sym =  8'sd32;
            2'b10: Q_sym =  8'sd96;
            default: Q_sym = 8'sd0;
        endcase
    end

endmodule


// =====================================================
// LUT NCO
// 4-bit phase address -> 16 samples per period
// sin/cos scale: 127
// =====================================================
module nco_lut (
    input  [3:0] phase_addr,
    output reg signed [7:0] cos_val,
    output reg signed [7:0] sin_val
);

    always @(*) begin
        case (phase_addr)
            4'd0:  begin cos_val =  8'sd127; sin_val =   8'sd0;   end
            4'd1:  begin cos_val =  8'sd117; sin_val =   8'sd49;  end
            4'd2:  begin cos_val =   8'sd90; sin_val =   8'sd90;  end
            4'd3:  begin cos_val =   8'sd49; sin_val =  8'sd117;  end

            4'd4:  begin cos_val =    8'sd0; sin_val =  8'sd127;  end
            4'd5:  begin cos_val = -8'sd49;  sin_val =  8'sd117;  end
            4'd6:  begin cos_val = -8'sd90;  sin_val =   8'sd90;  end
            4'd7:  begin cos_val = -8'sd117; sin_val =   8'sd49;  end

            4'd8:  begin cos_val = -8'sd127; sin_val =   8'sd0;   end
            4'd9:  begin cos_val = -8'sd117; sin_val = -8'sd49;   end
            4'd10: begin cos_val = -8'sd90;  sin_val = -8'sd90;   end
            4'd11: begin cos_val = -8'sd49;  sin_val = -8'sd117;  end

            4'd12: begin cos_val =   8'sd0;  sin_val = -8'sd127;  end
            4'd13: begin cos_val =  8'sd49;  sin_val = -8'sd117;  end
            4'd14: begin cos_val =  8'sd90;  sin_val = -8'sd90;   end
            4'd15: begin cos_val =  8'sd117; sin_val = -8'sd49;   end

            default: begin
                cos_val = 8'sd0;
                sin_val = 8'sd0;
            end
        endcase
    end

endmodule


// =====================================================
// Main LUT-based QAM Modulator
// =====================================================
module qam_lut_full_top (
    input clk,
    input rst,
    input [3:0] bits_in,

    output [7:0] bits_show,
    output [7:0] phase_show,
    output [7:0] up_count_show,

    output signed [7:0] I_sym,
    output signed [7:0] Q_sym,

    output reg signed [7:0] I_up,
    output reg signed [7:0] Q_up,

    output reg signed [7:0] I_filt,
    output reg signed [7:0] Q_filt,

    output reg signed [7:0] cos_val,
    output reg signed [7:0] sin_val,

    output reg signed [15:0] qam_out
);

    // Counter for L = 4 upsampling
    reg [1:0] up_count;

    // Phase counter for LUT carrier
    reg [3:0] phase_cnt;

    assign bits_show     = {4'b0000, bits_in};
    assign phase_show    = {4'b0000, phase_cnt};
    assign up_count_show = {6'b000000, up_count};

    // Mapper
    qam_mapper u_mapper (
        .bits_in(bits_in),
        .I_sym(I_sym),
        .Q_sym(Q_sym)
    );

    // LUT carrier
    wire signed [7:0] cos_wire;
    wire signed [7:0] sin_wire;

    nco_lut u_nco (
        .phase_addr(phase_cnt),
        .cos_val(cos_wire),
        .sin_val(sin_wire)
    );

    // =================================================
    // Upsampler L = 4
    // up_count = 0: pass real symbol
    // up_count = 1,2,3: insert zero
    // =================================================
    wire signed [7:0] I_up_next;
    wire signed [7:0] Q_up_next;

    assign I_up_next = (up_count == 2'd0) ? I_sym : 8'sd0;
    assign Q_up_next = (up_count == 2'd0) ? Q_sym : 8'sd0;

    // FIR delay registers
    reg signed [7:0] I_d1, I_d2, I_d3, I_d4;
    reg signed [7:0] Q_d1, Q_d2, Q_d3, Q_d4;

    // =================================================
    // FIR 5-tap
    //
    // h = [0.25, 0.75, 1.0, 0.75, 0.25]
    //
    // Convert to fixed-point by multiplying 64:
    // h_int = [16, 48, 64, 48, 16]
    //
    // After accumulation, divide by 64 using >>> 6.
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

    // Saturation to 8-bit signed range
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
    // Mixer
    // QAM formula:
    // s = I*cos - Q*sin
    //
    // sin/cos scale = 127, so divide by 128 using >>> 7.
    // =================================================
    wire signed [15:0] I_cos;
    wire signed [15:0] Q_sin;
    wire signed [16:0] mix_temp;
    wire signed [15:0] qam_next;

    assign I_cos   = I_filt_next * cos_wire;
    assign Q_sin   = Q_filt_next * sin_wire;
    assign mix_temp = I_cos - Q_sin;
    assign qam_next = mix_temp >>> 7;

    // =================================================
    // Sequential part
    // =================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            up_count <= 2'd0;
            phase_cnt <= 4'd0;

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
            // Upsampler output
            I_up <= I_up_next;
            Q_up <= Q_up_next;

            // FIR delay line
            I_d4 <= I_d3;
            I_d3 <= I_d2;
            I_d2 <= I_d1;
            I_d1 <= I_up_next;

            Q_d4 <= Q_d3;
            Q_d3 <= Q_d2;
            Q_d2 <= Q_d1;
            Q_d1 <= Q_up_next;

            // FIR output
            I_filt <= I_filt_next;
            Q_filt <= Q_filt_next;

            // Carrier output
            cos_val <= cos_wire;
            sin_val <= sin_wire;

            // QAM output
            qam_out <= qam_next;

            // Update counters
            up_count <= up_count + 2'd1;
            phase_cnt <= phase_cnt + 4'd1;
        end
    end

endmodule