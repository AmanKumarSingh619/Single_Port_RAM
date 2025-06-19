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
    parameter DATA_WIDTH = 8,          // Width of each memory location
    parameter DEPTH = 16,             // Number of memory locations
    parameter INIT_VALUE = 0,         // Default initialization value
    parameter INIT_FILE = ""          // Optional initialization file
)(
    input wire clk,                          // Clock signal
    input wire rst,                          // Reset signal
    input wire enable,                       // RAM enable signal
    input wire [$clog2(DEPTH)-1:0] addr,     // Address bus
    input wire [DATA_WIDTH-1:0] data_in,     // Data input
    input wire [DATA_WIDTH-1:0] write_mask,  // Write mask input
    input wire we,                           // Write enable
    input wire write_protect,                // Write protection enable
    input wire burst_mode,                   // Enable burst mode
    input wire [$clog2(DEPTH)-1:0] burst_len, // Burst length for burst mode
    input wire test_mode,                    // Test mode signal
    output reg [DATA_WIDTH-1:0] data_out,    // Data output
    output reg busy,                         // Busy signal
    output reg [$clog2(DEPTH)-1:0] current_address, // Current address
    output reg [1:0] last_operation          // Last operation (0: Idle, 1: Read, 2: Write)
);

    // Memory array with ECC
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] ram [DEPTH-1:0];
    reg [DATA_WIDTH-1:0] ecc_array [DEPTH-1:0]; // ECC memory array
    reg [$clog2(DEPTH)-1:0] burst_counter;      // Burst operation counter
    integer i;

    // ECC Calculation Function
    function [DATA_WIDTH-1:0] calculate_ecc(input [DATA_WIDTH-1:0] data);
        integer j;
        begin
            calculate_ecc = 0;
            for (j = 0; j < DATA_WIDTH; j = j + 1) begin
                calculate_ecc = calculate_ecc ^ data[j];
            end
        end
    endfunction

    // Initialization
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, ram); // Load data from file
            for (i = 0; i < DEPTH; i = i + 1) begin
                ecc_array[i] = calculate_ecc(ram[i]); // Compute ECC for each memory location
            end
        end else begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                ram[i] = INIT_VALUE;
                ecc_array[i] = calculate_ecc(INIT_VALUE); // Default ECC for initialized values
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset all memory and ECC values
            for (i = 0; i < DEPTH; i = i + 1) begin
                ram[i] <= INIT_VALUE;
                ecc_array[i] <= calculate_ecc(INIT_VALUE);
            end
            data_out <= 0;
            busy <= 0;
            current_address <= 0;
            last_operation <= 0;
            burst_counter <= 0;
        end else if (!enable) begin
            // Low-power mode: no operations
            busy <= 0;
        end else if (test_mode) begin
            // Test mode: Validate ECC for each memory location
            for (i = 0; i < DEPTH; i = i + 1) begin
                if (calculate_ecc(ram[i]) !== ecc_array[i]) begin
                    $display("ECC Error at Address %0d. Data: %h, ECC: %h", i, ram[i], ecc_array[i]);
                end
            end
        end else begin
            if (burst_mode && burst_counter > 0) begin
                // Burst operation (read/write)
                if (we && !write_protect) begin
                    // Burst write
                    ram[current_address] <= data_in;
                    ecc_array[current_address] <= calculate_ecc(data_in);
                end else begin
                    // Burst read
                    data_out <= ram[current_address];
                end
                current_address <= current_address + 1; // Increment address
                burst_counter <= burst_counter - 1;    // Decrement counter
                busy <= 1;
            end else if (burst_mode && burst_len > 0) begin
                // Initialize burst mode
                burst_counter <= burst_len;
                current_address <= addr;
                busy <= 1;
            end else if (we && !write_protect) begin
                // Single write operation
                ram[addr] <= (ram[addr] & ~write_mask) | (data_in & write_mask);
                ecc_array[addr] <= calculate_ecc((ram[addr] & ~write_mask) | (data_in & write_mask));
                data_out <= data_in; // Immediate RAW handling
                current_address <= addr;
                busy <= 1;
                last_operation <= 2; // Write
            end else if (!we) begin
                // Single read operation
                data_out <= ram[addr];
                current_address <= addr;
                busy <= 1;
                last_operation <= 1; // Read
            end else begin
                // Idle state
                busy <= 0;
                last_operation <= 0;
            end
        end
    end
endmodule
