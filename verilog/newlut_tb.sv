`timescale 1ns/1ps

// Testbench for LUT-based 16-QAM Modulator
// Flow:
// Mapper -> Upsampler L=4 -> FIR -> LUT NCO -> Mixer

module tb_qam_lut_full;

    reg clk;
    reg rst;
    reg [3:0] bits_in;

    wire [7:0] bits_show;
    wire [7:0] phase_show;
    wire [7:0] up_count_show;

    wire signed [7:0] I_sym;
    wire signed [7:0] Q_sym;

    wire signed [7:0] I_up;
    wire signed [7:0] Q_up;

    wire signed [7:0] I_filt;
    wire signed [7:0] Q_filt;

    wire signed [7:0] cos_val;
    wire signed [7:0] sin_val;

    wire signed [15:0] qam_out;

    integer i;

    qam_lut_full_top dut (
        .clk(clk),
        .rst(rst),
        .bits_in(bits_in),

        .bits_show(bits_show),
        .phase_show(phase_show),
        .up_count_show(up_count_show),

        .I_sym(I_sym),
        .Q_sym(Q_sym),

        .I_up(I_up),
        .Q_up(Q_up),

        .I_filt(I_filt),
        .Q_filt(Q_filt),

        .cos_val(cos_val),
        .sin_val(sin_val),

        .qam_out(qam_out)
    );

    // Clock period = 10 ns
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Dump waveform
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_qam_lut_full);
    end

    initial begin
        $display("time | bits | up | phase | I_sym Q_sym | I_up Q_up | I_filt Q_filt | cos sin | qam_out");

        $monitor("%4t | %d | %d | %d | %d %d | %d %d | %d %d | %d %d | %d",
                 $time, bits_show, up_count_show, phase_show,
                 I_sym, Q_sym,
                 I_up, Q_up,
                 I_filt, Q_filt,
                 cos_val, sin_val,
                 qam_out);

        // Reset
        rst = 1'b1;
        bits_in = 4'd0;
        #25;

        rst = 1'b0;

        // Give input symbols.
        // Each symbol is held for 4 clock cycles because L = 4.
        for (i = 0; i < 16; i = i + 1) begin
            @(negedge clk);
            bits_in = i[3:0];

            repeat (4) @(negedge clk);
        end

        // Wait for FIR tail
        repeat (8) @(negedge clk);

        $finish;
    end

endmodule