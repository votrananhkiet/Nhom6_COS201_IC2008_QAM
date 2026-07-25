// qam_cordic_full.v
// CORDIC-based 16-QAM Modulator
// Mapper -> Upsampler L=4 -> FIR 5-tap
// -> 8-stage pipelined CORDIC -> Mixer

// =====================================================
// 16-QAM Mapper
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
// 8-stage Pipelined CORDIC
//
// phase_addr:
// 0  -> 0 degree
// 4  -> 90 degrees
// 8  -> 180 degrees
// 12 -> 270 degrees
//
// Full circle is represented by 16-bit phase:
// 65536 = 360 degrees
// =====================================================
module cordic_sincos (
    input clk,
    input rst,
    input [3:0] phase_addr,

    output signed [7:0] cos_out,
    output signed [7:0] sin_out
);

    localparam integer N = 8;
    localparam signed [17:0] K_INIT = 18'sd19899;

    wire [15:0] phase_full;

    assign phase_full = {phase_addr, 12'b0};

    reg signed [17:0] x_init;
    reg signed [17:0] y_init;
    reg signed [15:0] z_init;

    // Chuyen phase ve khoang -90 den +90 do
    always @(*) begin
        y_init = 18'sd0;

        case (phase_addr[3:2])
            // 0 -> 90 degrees
            2'b00: begin
                x_init = K_INIT;
                z_init = $signed(phase_full);
            end

            // 90 -> 180 degrees
            2'b01: begin
                x_init = -K_INIT;
                z_init = $signed(phase_full - 16'h8000);
            end

            // 180 -> 270 degrees
            2'b10: begin
                x_init = -K_INIT;
                z_init = $signed(phase_full - 16'h8000);
            end

            // 270 -> 360 degrees
            default: begin
                x_init = K_INIT;
                z_init = $signed(phase_full);
            end
        endcase
    end

    // Moi phan tu mang la mot pipeline stage
    reg signed [17:0] x_pipe [0:N];
    reg signed [17:0] y_pipe [0:N];
    reg signed [15:0] z_pipe [0:N];

    integer i;

    // CORDIC angle constants
    // atan(2^-i), full circle scale = 65536
    function signed [15:0] atan_const;
        input integer index;
        begin
            case (index)
                0: atan_const = 16'sd8192;
                1: atan_const = 16'sd4836;
                2: atan_const = 16'sd2555;
                3: atan_const = 16'sd1297;
                4: atan_const = 16'sd651;
                5: atan_const = 16'sd326;
                6: atan_const = 16'sd163;
                7: atan_const = 16'sd81;
                default: atan_const = 16'sd0;
            endcase
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i <= N; i = i + 1) begin
                x_pipe[i] <= 18'sd0;
                y_pipe[i] <= 18'sd0;
                z_pipe[i] <= 16'sd0;
            end
        end
        else begin
            // Nap du lieu vao stage dau
            x_pipe[0] <= x_init;
            y_pipe[0] <= y_init;
            z_pipe[0] <= z_init;

            // Moi iteration co mot thanh ghi rieng
            for (i = 0; i < N; i = i + 1) begin
                if (z_pipe[i] >= 0) begin
                    x_pipe[i+1] <=
                        x_pipe[i] - (y_pipe[i] >>> i);

                    y_pipe[i+1] <=
                        y_pipe[i] + (x_pipe[i] >>> i);

                    z_pipe[i+1] <=
                        z_pipe[i] - atan_const(i);
                end
                else begin
                    x_pipe[i+1] <=
                        x_pipe[i] + (y_pipe[i] >>> i);

                    y_pipe[i+1] <=
                        y_pipe[i] - (x_pipe[i] >>> i);

                    z_pipe[i+1] <=
                        z_pipe[i] + atan_const(i);
                end
            end
        end
    end

    // Chuyen tu thang Q1.15 ve signed 8-bit
    function signed [7:0] cordic_to_s8;
        input signed [17:0] value;

        reg signed [17:0] magnitude;
        reg signed [17:0] scaled;

        begin
            if (value >= 0) begin
                scaled = value >>> 8;

                if (scaled > 18'sd127)
                    cordic_to_s8 = 8'sd127;
                else
                    cordic_to_s8 = scaled[7:0];
            end
            else begin
                magnitude = -value;
                scaled = magnitude >>> 8;

                if (scaled > 18'sd127)
                    cordic_to_s8 = -8'sd127;
                else
                    cordic_to_s8 = -$signed(scaled[7:0]);
            end
        end
    endfunction

    assign cos_out = cordic_to_s8(x_pipe[N]);
    assign sin_out = cordic_to_s8(y_pipe[N]);

endmodule


// =====================================================
// Main CORDIC-based 16-QAM Modulator
// =====================================================
module qam_cordic_full_top (
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

    localparam integer CORDIC_LATENCY = 8;

    reg [1:0] up_count;
    reg [3:0] phase_cnt;

    assign bits_show     = {4'b0000, bits_in};
    assign phase_show    = {4'b0000, phase_cnt};
    assign up_count_show = {6'b000000, up_count};

    // =================================================
    // Mapper
    // =================================================
    qam_mapper u_mapper (
        .bits_in(bits_in),
        .I_sym(I_sym),
        .Q_sym(Q_sym)
    );

    // =================================================
    // CORDIC carrier
    // =================================================
    wire signed [7:0] cos_wire;
    wire signed [7:0] sin_wire;

    cordic_sincos u_cordic (
        .clk(clk),
        .rst(rst),
        .phase_addr(phase_cnt),
        .cos_out(cos_wire),
        .sin_out(sin_wire)
    );

    // =================================================
    // Upsampler L = 4
    // =================================================
    wire signed [7:0] I_up_next;
    wire signed [7:0] Q_up_next;

    assign I_up_next =
        (up_count == 2'd0) ? I_sym : 8'sd0;

    assign Q_up_next =
        (up_count == 2'd0) ? Q_sym : 8'sd0;

    // =================================================
    // FIR delay registers
    // =================================================
    reg signed [7:0] I_d1;
    reg signed [7:0] I_d2;
    reg signed [7:0] I_d3;
    reg signed [7:0] I_d4;

    reg signed [7:0] Q_d1;
    reg signed [7:0] Q_d2;
    reg signed [7:0] Q_d3;
    reg signed [7:0] Q_d4;

    // =================================================
    // FIR 5-tap
    // h_int = [16, 48, 64, 48, 16]
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

    // =================================================
    // Saturation 8-bit
    // =================================================
    function signed [7:0] sat8;
        input signed [19:0] x;

        begin
            if (x > 20'sd127)
                sat8 = 8'sd127;
            else if (x < -20'sd128)
                sat8 = 8'sh80;
            else
                sat8 = x[7:0];
        end
    endfunction

    wire signed [7:0] I_filt_next;
    wire signed [7:0] Q_filt_next;

    assign I_filt_next = sat8(I_fir_scaled);
    assign Q_filt_next = sat8(Q_fir_scaled);

    // =================================================
    // Delay I/Q de dong bo voi CORDIC 8 stages
    // =================================================
    reg signed [7:0] I_align [0:CORDIC_LATENCY];
    reg signed [7:0] Q_align [0:CORDIC_LATENCY];

    integer j;

    // =================================================
    // Mixer
    // s = I*cos - Q*sin
    // =================================================
    wire signed [15:0] I_cos;
    wire signed [15:0] Q_sin;
    wire signed [16:0] mix_temp;
    wire signed [15:0] qam_next;

    assign I_cos =
        I_align[CORDIC_LATENCY] * cos_wire;

    assign Q_sin =
        Q_align[CORDIC_LATENCY] * sin_wire;

    assign mix_temp =
        {I_cos[15], I_cos} -
        {Q_sin[15], Q_sin};

    assign qam_next = mix_temp >>> 7;

    // =================================================
    // Sequential block
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

            for (j = 0; j <= CORDIC_LATENCY; j = j + 1) begin
                I_align[j] <= 8'sd0;
                Q_align[j] <= 8'sd0;
            end
        end
        else begin
            // Upsampler
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

            // Delay I/Q de khop voi carrier
            I_align[0] <= I_filt_next;
            Q_align[0] <= Q_filt_next;

            for (j = 0; j < CORDIC_LATENCY; j = j + 1) begin
                I_align[j+1] <= I_align[j];
                Q_align[j+1] <= Q_align[j];
            end

            // Carrier output
            cos_val <= cos_wire;
            sin_val <= sin_wire;

            // QAM output
            qam_out <= qam_next;

            // Counters
            up_count <= up_count + 2'd1;
            phase_cnt <= phase_cnt + 4'd1;
        end
    end

endmodule