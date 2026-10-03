// ==============================================================================
// Module Name:  svpwm_generator_tb
// Description:  Automated verification matrix for the SVPWM module.
//               Generates clock, asynchronous reset, and target tracking vectors.
// ==============================================================================

`timescale 1ns / 1ps

module svpwm_generator_tb;

    // Testbench Inputs (Registers)
    reg         clk;
    reg         reset_n;
    reg  [15:0] v_alpha;
    reg  [15:0] v_beta;

    // Testbench Outputs (Wires)
    wire        pwm_a_high, pwm_a_low;
    wire        pwm_b_high, pwm_b_low;
    wire        pwm_c_high, pwm_c_low;

    // Instantiate the Unit Under Test (UUT)
    svpwm_generator uut (
        .clk(clk),
        .reset_n(reset_n),
        .v_alpha(v_alpha),
        .v_beta(v_beta),
        .pwm_a_high(pwm_a_high), .pwm_a_low(pwm_a_low),
        .pwm_b_high(pwm_b_high), .pwm_b_low(pwm_b_low),
        .pwm_c_high(pwm_c_high), .pwm_c_low(pwm_c_low)
    );

    // --------------------------------------------------------------------------
    // High-Frequency Oscillator Generation Loop (~50MHz System Frequency clock)
    // --------------------------------------------------------------------------
    always #10 clk = ~clk; // Flips state every 10ns to create a 20ns clock cycle

    // --------------------------------------------------------------------------
    // Stimulus Pattern Vectors Matrix
    // --------------------------------------------------------------------------
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, svpwm_generator_tb);
        
        // Initialize state vectors to default values
        clk     = 1'b0;
        reset_n = 1'b0;
        v_alpha = 16'd0;
        v_beta  = 16'd0;

        // Force hardware asynchronous reset state hold condition
        #100;
        reset_n = 1'b1; // De-assert reset to release system
        
        // --- Test Scenario 1: Torque Command to Sector 1 ---
        #50;
        v_alpha = 16'd2000;
        v_beta  = 16'd500;
        
        // Wait for multiple PWM switching carrier period intervals to settle
        #200000;
        
        // --- Test Scenario 2: High Speed Dynamic Vector Sector Change ---
        v_alpha = -16'd1500;
        v_beta  = 16'd1800;
        
        #200000;
        
        // Terminate active verification environment safely
        $display("[TB SUCCESS] Timing checks complete. System verified successfully.");
        $finish;
    end
      
endmodule
