//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.01.2026 19:41:02
// Design Name: 
// Module Name: tb_FIFO_synch
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

`timescale 1ns/1ns
module tb_fifo_sync;

    // Parameters
    parameter FIFO_DEPTH = 8;
    parameter DATA_WIDTH = 32;

    // DUT signals
    reg clk;
    reg rst_n;
    reg cs;
    reg wr_en;
    reg rd_en;
    reg [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;
    wire empty;
    wire full;

    // CSV handling
    integer file_fd;
    integer csv_value;
    integer status;
    reg     csv_done;

    // DUT
    fifo_sync #(
        .FIFO_DEPTH(FIFO_DEPTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .cs       (cs),
        .wr_en    (wr_en),
        .rd_en    (rd_en),
        .data_in  (data_in),
        .data_out (data_out),
        .empty    (empty),
        .full     (full)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // ---------------- INITIALIZATION ----------------
    initial begin
        rst_n    = 0;
        cs       = 1;          // keep CS permanently enabled
        wr_en    = 0;
        rd_en    = 0;
        data_in  = 0;
        csv_done = 0;

        @(posedge clk);
        rst_n = 1;

        // Open CSV file
        file_fd = $fopen("fifo_input.csv", "r");
        if (file_fd == 0) begin
            $display("ERROR: Unable to open fifo_input.csv");
            $finish;
        end

        $display("\n--- FIFO CSV STREAMING STARTED ---");
    end

    // ---------------- SINGLE CONTROL PROCESS ----------------
    always @(posedge clk) begin
        if (!rst_n) begin
            wr_en <= 0;
            rd_en <= 0;
        end
        else begin
            // Default disables
            wr_en <= 0;
            rd_en <= 0;

            // ---------------- WRITE PHASE ----------------
            if (!csv_done && !full) begin
                status = $fscanf(file_fd, "%d\n", csv_value);
                if (status == 1) begin
                    data_in <= csv_value;
                    wr_en   <= 1;
                    $display("%0t WRITE : %0d", $time, csv_value);
                end
                else begin
                    csv_done <= 1;
                    $fclose(file_fd);
                    $display("--- CSV FILE COMPLETED ---");
                end
            end

            // ---------------- READ PHASE ----------------
            if (!empty) begin
                rd_en <= 1;
            end
        end
    end

    // ---------------- READ MONITOR ----------------
    always @(posedge clk) begin
        if (rd_en && !empty) begin
            $display("%0t READ  : %0d", $time, data_out);
        end
    end

    // ---------------- TERMINATION ----------------
    always @(posedge clk) begin
        if (csv_done && empty) begin
            $display("\n--- FIFO STREAMING COMPLETED SUCCESSFULLY ---");
            #20 $finish;
        end
    end

    // Waveform dump
    initial begin
        $dumpfile("fifo_dump.vcd");
        $dumpvars(0, tb_fifo_sync);
    end

endmodule
