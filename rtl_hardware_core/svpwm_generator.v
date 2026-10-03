// ==============================================================================
// Module Name:  svpwm_generator
// Description:  Space Vector Pulse Width Modulation (SVPWM) with Dead-Time
//               Designed for EV Powertrain Inverter Control.
// Target Focus: Synthesizable RTL for FPGA offloading.
// ==============================================================================

`timescale 1ns / 1ps

module svpwm_generator (
    input  wire        clk,          // High-frequency system clock (e.g., 50MHz)
    input  wire        reset_n,      // Active-low asynchronous reset
    input  wire [15:0] v_alpha,      // Stationary alpha-axis voltage reference (Q15 format)
    input  wire [15:0] v_beta,       // Stationary beta-axis voltage reference (Q15 format)
    output reg         pwm_a_high,   // Phase A Phase Leg - Top Switch Gate Signal
    output reg         pwm_a_low,    // Phase A Phase Leg - Bottom Switch Gate Signal (Complementary)
    output reg         pwm_b_high,   // Phase B Phase Leg - Top Switch Gate Signal
    output reg         pwm_b_low,    // Phase B Phase Leg - Bottom Switch Gate Signal (Complementary)
    output reg         pwm_c_high,   // Phase C Phase Leg - Top Switch Gate Signal
    output reg         pwm_c_low     // Phase C Phase Leg - Bottom Switch Gate Signal (Complementary)
);

    // --------------------------------------------------------------------------
    // Architecture Constants & Parameter Settings
    // --------------------------------------------------------------------------
    parameter CARRIER_MAX = 16'd2500;  // Defines PWM frequency (e.g., 50MHz / (2 * 2500) = 10kHz Switching)
    parameter DEAD_TIME   = 16'd50;    // 50 clock cycles of dead-time protection (~1 microsecond at 50MHz)

    // Internal Registers for Triangular Carrier Wave Generation
    reg [15:0] carrier_cnt;
    reg        count_dir; // 1 = Counting Up, 0 = Counting Down

    // Internal Duty Cycle Compare Registers
    reg [15:0] duty_a;
    reg [15:0] duty_b;
    reg [15:0] duty_c;

    // --------------------------------------------------------------------------
    // 1. Symmetric Triangular Carrier Wave Generator (Center-Aligned PWM)
    // --------------------------------------------------------------------------
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            carrier_cnt <= 16'd0;
            count_dir   <= 1'b1;
        end else begin
            if (count_dir) begin
                if (carrier_cnt >= CARRIER_MAX - 1'b1)
                    count_dir <= 1'b0; // Switch direction to Down
                else
                    carrier_cnt <= carrier_cnt + 1'b1;
            end else begin
                if (carrier_cnt <= 16'd1)
                    count_dir <= 1'b1; // Switch direction to Up
                else
                    carrier_cnt <= carrier_cnt - 1'b1;
            end
        end
    end

    // --------------------------------------------------------------------------
    // 2. Simplified Sector Determination & Duty Cycle Mapping
    // --------------------------------------------------------------------------
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            duty_a <= 16'd0;
            duty_b <= 16'd0;
            duty_c <= 16'd0;
        end else begin
            // Architectural Note: Real implementations execute inverse Park transforms here.
            // For structural demonstration, we map basic ratios from stationary reference vectors.
            duty_a <= (CARRIER_MAX >> 1) + (v_alpha >> 2);
            duty_b <= (CARRIER_MAX >> 1) - (v_alpha >> 3) + (v_beta >> 2);
            duty_c <= (CARRIER_MAX >> 1) - (v_alpha >> 3) - (v_beta >> 2);
        end
    end

    // --------------------------------------------------------------------------
    // 3. Digital Comparator Logic with Hardware Dead-Time Insertion
    //    Prevents shoot-through currents in the inverter bridge legs.
    // --------------------------------------------------------------------------
    
    // Phase A Pipeline Generation
    reg raw_pwm_a;
    always @(*) raw_pwm_a = (carrier_cnt < duty_a) ? 1'b1 : 1'b0;

    reg [15:0] dt_cnt_a_high, dt_cnt_a_low;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pwm_a_high    <= 1'b0;
            dt_cnt_a_high <= 16'd0;
        end else if (raw_pwm_a) begin
            dt_cnt_a_low <= 16'd0;
            if (dt_cnt_a_high < DEAD_TIME) begin
                dt_cnt_a_high <= dt_cnt_a_high + 1'b1;
                pwm_a_high    <= 1'b0; // Hold low during the dead-time window
            end else begin
                pwm_a_high    <= 1'b1; // Safely assert high
            end
        end else begin
            pwm_a_high    <= 1'b0;
            dt_cnt_a_high <= 16'd0;
        end
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pwm_a_low    <= 1'b0;
            dt_cnt_a_low <= 16'd0;
        end else if (!raw_pwm_a) begin
            dt_cnt_a_high <= 16'd0;
            if (dt_cnt_a_low < DEAD_TIME) begin
                dt_cnt_a_low <= dt_cnt_a_low + 1'b1;
                pwm_a_low    <= 1'b0; // Hold low during the dead-time window
            end else begin
                pwm_a_low    <= 1'b1; // Safely assert complementary high
            end
        end else begin
            pwm_a_low    <= 1'b0;
            dt_cnt_a_low <= 16'd0;
        end
    end

    // Phase B Pipeline Generation
    reg raw_pwm_b;
    always @(*) raw_pwm_b = (carrier_cnt < duty_b) ? 1'b1 : 1'b0;

    reg [15:0] dt_cnt_b_high, dt_cnt_b_low;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pwm_b_high    <= 1'b0;
            dt_cnt_b_high <= 16'd0;
        end else if (raw_pwm_b) begin
            dt_cnt_b_low <= 16'd0;
            if (dt_cnt_b_high < DEAD_TIME) begin
                dt_cnt_b_high <= dt_cnt_b_high + 1'b1;
                pwm_b_high    <= 1'b0;
            end else begin
                pwm_b_high    <= 1'b1;
            end
        end else begin
            pwm_b_high    <= 1'b0;
            dt_cnt_b_high <= 16'd0;
        end
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pwm_b_low    <= 1'b0;
            dt_cnt_b_low <= 16'd0;
        end else if (!raw_pwm_b) begin
            dt_cnt_b_high <= 16'd0;
            if (dt_cnt_b_low < DEAD_TIME) begin
                dt_cnt_b_low <= dt_cnt_b_low + 1'b1;
                pwm_b_low    <= 1'b0;
            end else begin
                pwm_b_low    <= 1'b1;
            end
        end else begin
            pwm_b_low    <= 1'b0;
            dt_cnt_b_low <= 16'd0;
        end
    end

    // Phase C Pipeline Generation
    reg raw_pwm_c;
    always @(*) raw_pwm_c = (carrier_cnt < duty_c) ? 1'b1 : 1'b0;

    reg [15:0] dt_cnt_c_high, dt_cnt_c_low;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pwm_c_high    <= 1'b0;
            dt_cnt_c_high <= 16'd0;
        end else if (raw_pwm_c) begin
            dt_cnt_c_low <= 16'd0;
            if (dt_cnt_c_high < DEAD_TIME) begin
                dt_cnt_c_high <= dt_cnt_c_high + 1'b1;
                pwm_c_high    <= 1'b0;
            end else begin
                pwm_c_high    <= 1'b1;
            end
        end else begin
            pwm_c_high    <= 1'b0;
            dt_cnt_c_high <= 16'd0;
        end
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pwm_c_low    <= 1'b0;
            dt_cnt_c_low <= 16'd0;
        end else if (!raw_pwm_c) begin
            dt_cnt_c_high <= 16'd0;
            if (dt_cnt_c_low < DEAD_TIME) begin
                dt_cnt_c_low <= dt_cnt_c_low + 1'b1;
                pwm_c_low    <= 1'b0;
            end else begin
                pwm_c_low    <= 1'b1;
            end
        end else begin
            pwm_c_low    <= 1'b0;
            dt_cnt_c_low <= 16'd0;
        end
    end

endmodule
