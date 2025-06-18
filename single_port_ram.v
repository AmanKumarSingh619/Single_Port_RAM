`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.06.2025 12:03:14
// Design Name: 
// Module Name: single_port_ram
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module single_port_ram #(
    parameter DATA_WIDTH = 8,                // Width of each memory location
    parameter DEPTH = 16,                    // Number of memory locations
    parameter INIT_VALUE = 0,                // Default initialization value
    parameter INIT_FILE = ""                 // Optional initialization file
)(
    input wire clk,                          // Clock signal
    input wire rst,                          // Reset signal
    input wire enable,                       // RAM enable signal
    input wire [$clog2(DEPTH)-1:0] addr,     // Address bus
    input wire [DATA_WIDTH-1:0] data_in,     // Data input
    input wire [DATA_WIDTH-1:0] write_mask,  // Write mask input
    input wire we,                           // Write enable
    input wire write_protect,                // Write protection enable
    input wire test_mode,                    // Test mode signal
    output reg [DATA_WIDTH-1:0] data_out,    // Data output
    output reg busy,                         // Busy signal
    output reg [$clog2(DEPTH)-1:0] current_address, // Current address
    output reg [1:0] last_operation          // Last operation (0: Idle, 1: Read, 2: Write)
);

    // Memory array
    (* ram_style = "block" *) reg [DATA_WIDTH:0] ram [DEPTH-1:0]; // Extra bit for parity/ECC
    integer i;

    // Initialization
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, ram); // Load from file
        end else begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                ram[i] = INIT_VALUE;
            end
        end
    end

    // Internal variables
    reg [DATA_WIDTH-1:0] ecc_code;           // ECC code for error detection
    reg [DATA_WIDTH-1:0] expected_ecc;      // Expected ECC for validation
    reg [$clog2(DEPTH)-1:0] burst_counter;  // Burst counter for burst mode

    // ECC Calculation Module
    function [DATA_WIDTH-1:0] calculate_ecc(input [DATA_WIDTH-1:0] data);
        // Example: Simple parity calculation (can be replaced with Hamming code)
        integer j;
        begin
            calculate_ecc = 0;
            for (j = 0; j < DATA_WIDTH; j = j + 1) begin
                calculate_ecc = calculate_ecc ^ data[j];
            end
        end
    endfunction

    // Clock-Controlled Logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset all memory locations to INIT_VALUE or file content
            for (i = 0; i < DEPTH; i = i + 1) begin
                ram[i] <= INIT_VALUE;
            end
            data_out <= 0;
            busy <= 0;
            current_address <= 0;
            last_operation <= 0;
            burst_counter <= 0;
        end else if (!enable) begin
            // Low-power mode
            busy <= 0;
        end else if (test_mode) begin
            // Test mode: Perform a pattern check or memory validation
            for (i = 0; i < DEPTH; i = i + 1) begin
                ecc_code = calculate_ecc(ram[i]);
                expected_ecc = calculate_ecc(INIT_VALUE); // Compare with expected pattern
                if (ecc_code !== expected_ecc) begin
                    $display("ECC Mismatch at Address %d", i);
                end
            end
        end else begin
            // Normal operation
            if (we && !write_protect) begin
                // Write operation with masking
                ram[addr] <= (ram[addr] & ~write_mask) | (data_in & write_mask);
                data_out <= data_in; // Immediate RAW handling
                current_address <= addr;
                busy <= 1;
                last_operation <= 2; // Write
            end else begin
                // Read operation
                data_out <= ram[addr];
                current_address <= addr;
                busy <= 1;
                last_operation <= 1; // Read
            end
        end
    end

endmodule