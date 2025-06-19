`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.06.2025 12:04:26
// Design Name: 
// Module Name: tb_single_port_ram
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

module tb_single_port_ram;

    // Parameters
    parameter DATA_WIDTH = 8;
    parameter DEPTH = 16;
    parameter INIT_VALUE = 0;

    // Testbench Signals
    reg clk;
    reg rst;
    reg enable;
    reg [$clog2(DEPTH)-1:0] addr;
    reg [DATA_WIDTH-1:0] data_in;
    reg [DATA_WIDTH-1:0] write_mask;
    reg we;
    reg write_protect;
    reg test_mode;
    wire [DATA_WIDTH-1:0] data_out;
    wire busy;
    wire [$clog2(DEPTH)-1:0] current_address;
    wire [1:0] last_operation;

    // Instantiate DUT
    single_port_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .INIT_VALUE(INIT_VALUE),
        .INIT_FILE("init_file.mem")
    ) dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .addr(addr),
        .data_in(data_in),
        .write_mask(write_mask),
        .we(we),
        .write_protect(write_protect),
        .test_mode(test_mode),
        .data_out(data_out),
        .busy(busy),
        .current_address(current_address),
        .last_operation(last_operation)
    );

    // Clock Generation
    initial clk = 0;
    always #5 clk = ~clk; // 10ns clock period
    
    // Task for Testing Reset
    task test_reset;
        begin
            @(posedge clk);
            rst = 1;       // Activate reset
            #10;
            rst = 0;       // Deactivate reset
            @(posedge clk);
            for (addr = 0; addr < DEPTH; addr = addr + 1) begin
                @(posedge clk);
                if (dut.ram[addr] !== INIT_VALUE) begin
                    $display("ERROR: Reset Mismatch at Address %d. Expected: %h, Got: %h", addr, INIT_VALUE, dut.ram[addr]);
                end else begin
                    $display("PASS: Reset Passed at Address %d", addr);
                end
            end
        end
    endtask

    // Task for Read-Write Testing
    task test_read_write;
        input [$clog2(DEPTH)-1:0] test_addr;
        input [DATA_WIDTH-1:0] test_data;
        begin
            @(posedge clk);
            addr = test_addr;
            data_in = test_data;
            we = 1;
            enable = 1;
            write_protect = 0;
            #10; // Wait for write to complete
            we = 0;
            @(posedge clk);
            if (data_out !== test_data) begin
                $display("ERROR: Read-Write Mismatch at Address %d. Expected: %h, Got: %h", test_addr, test_data, data_out);
            end else begin
                $display("PASS: Read-Write Test Passed at Address %d", test_addr);
            end
        end
    endtask

    // Task for Burst Mode Testing
    task test_burst_mode;
        input [$clog2(DEPTH)-1:0] start_addr;
        input [DATA_WIDTH-1:0] burst_data;
        input [$clog2(DEPTH)-1:0] burst_len;
        reg [$clog2(DEPTH)-1:0] burst_counter; // Local burst counter
        reg [DATA_WIDTH-1:0] calculated_ecc;
        begin
            burst_counter = burst_len; // Initialize burst counter locally
            @(posedge clk);
            addr = start_addr;
            data_in = burst_data;
            we = 1;
            enable = 1;
            write_protect = 0;
            #10;
            while (burst_counter > 0) begin
                @(posedge clk);
                if (dut.ram[addr] !== burst_data) begin
                    $display("ERROR: Burst Mode Mismatch at Address %d. Expected: %h, Got: %h", addr, burst_data, dut.ram[addr]);
                end else begin
                    calculated_ecc = dut.calculate_ecc(burst_data);
                    if (calculated_ecc !== dut.ecc_array[addr]) begin
                        $display("ERROR: ECC Mismatch during Burst Mode at Address %d. Data: %h, ECC: %h, Calculated: %h",
                            addr, burst_data, dut.ecc_array[addr], calculated_ecc);
                    end else begin
                        $display("PASS: Burst Mode and ECC Passed at Address %d", addr);
                    end
                end
                addr = addr + 1; // Move to next address
                burst_counter = burst_counter - 1; // Decrement counter
            end
            we = 0;
        end
    endtask

    // Testbench Execution
    initial begin
        // Initialize Signals
        rst = 0;
        enable = 0;
        addr = 0;
        data_in = 0;
        write_mask = {DATA_WIDTH{1'b1}};
        we = 0;
        write_protect = 0;
        test_mode = 0;

        // Apply Reset
        rst = 1;
        #10;
        rst = 0;

        // Perform Read-Write Tests
        test_read_write(5, 8'hAA); // Test Address 5 with Data 0xAA
        test_read_write(10, 8'h55); // Test Address 10 with Data 0x55

        // Perform Burst Mode Test
        test_burst_mode(0, 8'hFF, 5); // Burst Mode starting at Address 0 with 5 entries of Data 0xFF

        // Final Message
        $display("All Tests Completed.");
        $finish;
    end
endmodule
