//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.02.2026 14:24:52
// Design Name: 
// Module Name: tb_fifo_csr_top
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
`timescale 1ns/1ps
module tb_axi_csr_fifo_top_phase7_csv;

    // ============================================================
    // PARAMETERS
    // ============================================================
    parameter ADDR_WIDTH  = 12;
    parameter DATA_WIDTH  = 32;
    parameter FIFO_DEPTH  = 16;

    parameter CONTROL_ADDR = 12'h000;
    parameter STATUS_ADDR  = 12'h004;

    // ============================================================
    // CLOCK & RESET
    // ============================================================
    reg ACLK;
    reg ARESETn;

    initial ACLK = 0;
    always #5 ACLK = ~ACLK;

    // ============================================================
    // AXI SIGNALS
    // ============================================================
    reg  [ADDR_WIDTH-1:0]  S_AXI_AWADDR;
    reg                    S_AXI_AWVALID;
    wire                   S_AXI_AWREADY;

    reg  [DATA_WIDTH-1:0]  S_AXI_WDATA;
    reg  [(DATA_WIDTH/8)-1:0] S_AXI_WSTRB;
    reg                    S_AXI_WVALID;
    wire                   S_AXI_WREADY;

    wire [1:0]             S_AXI_BRESP;
    wire                   S_AXI_BVALID;
    reg                    S_AXI_BREADY;

    reg  [ADDR_WIDTH-1:0]  S_AXI_ARADDR;
    reg                    S_AXI_ARVALID;
    wire                   S_AXI_ARREADY;

    wire [DATA_WIDTH-1:0]  S_AXI_RDATA;
    wire [1:0]             S_AXI_RRESP;
    wire                   S_AXI_RVALID;
    reg                    S_AXI_RREADY;

    // ============================================================
    // FIFO STREAM INTERFACE
    // ============================================================
    reg wr_en;
    reg rd_en;
    reg [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;

    // ============================================================
    // CSV HANDLING
    // ============================================================
    integer file_fd;
    integer out_fd;
    integer csv_value;
    integer scan_status;

    // ============================================================
    // STATUS REGISTERS
    // ============================================================
    reg [DATA_WIDTH-1:0] status_reg;
    reg status_empty;
    reg status_full;
    reg [7:0] status_level;

    integer write_count;
    integer read_count;

    // ============================================================
    // DUT
    // ============================================================
    axi_csr_fifo_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .ACLK(ACLK),
        .ARESETn(ARESETn),

        .S_AXI_AWADDR(S_AXI_AWADDR),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY),

        .S_AXI_WDATA(S_AXI_WDATA),
        .S_AXI_WSTRB(S_AXI_WSTRB),
        .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_WREADY(S_AXI_WREADY),

        .S_AXI_BRESP(S_AXI_BRESP),
        .S_AXI_BVALID(S_AXI_BVALID),
        .S_AXI_BREADY(S_AXI_BREADY),

        .S_AXI_ARADDR(S_AXI_ARADDR),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY),

        .S_AXI_RDATA(S_AXI_RDATA),
        .S_AXI_RRESP(S_AXI_RRESP),
        .S_AXI_RVALID(S_AXI_RVALID),
        .S_AXI_RREADY(S_AXI_RREADY),

        .wr_en(wr_en),
        .rd_en(rd_en),
        .data_in(data_in),
        .data_out(data_out)
    );

    // ============================================================
    // AXI WRITE TASK
    // ============================================================
    task axi_write(input [ADDR_WIDTH-1:0] addr,
                   input [DATA_WIDTH-1:0] data);
    begin
        @(posedge ACLK);
        S_AXI_AWADDR  <= addr;
        S_AXI_AWVALID <= 1;
        S_AXI_WDATA   <= data;
        S_AXI_WSTRB   <= 4'hF;
        S_AXI_WVALID  <= 1;
        S_AXI_BREADY  <= 1;

        wait(S_AXI_AWREADY && S_AXI_WREADY);
        @(posedge ACLK);
        S_AXI_AWVALID <= 0;
        S_AXI_WVALID  <= 0;

        wait(S_AXI_BVALID);
        @(posedge ACLK);
        S_AXI_BREADY <= 0;
    end
    endtask

    // ============================================================
    // AXI READ TASK
    // ============================================================
    task axi_read(input  [ADDR_WIDTH-1:0] addr,
                  output [DATA_WIDTH-1:0] data);
    begin
        @(posedge ACLK);
        S_AXI_ARADDR  <= addr;
        S_AXI_ARVALID <= 1;
        S_AXI_RREADY  <= 1;

        wait(S_AXI_ARREADY);
        @(posedge ACLK);
        S_AXI_ARVALID <= 0;

        wait(S_AXI_RVALID);
        data = S_AXI_RDATA;

        @(posedge ACLK);
        S_AXI_RREADY <= 0;
    end
    endtask

    // ============================================================
    // DATA MONITOR + OUTPUT CSV WRITE
    // ============================================================
    always @(posedge ACLK) begin
        if (rd_en) begin
            $display("%0t READ : %0d (signed %0d)", 
                      $time, data_out, $signed(data_out));

            // Write FIFO output to CSV
            $fwrite(out_fd, "%0d\n", $signed(data_out));

            read_count = read_count + 1;
        end
    end

    // ============================================================
    // MAIN STREAMING TEST
    // ============================================================
    initial begin

        // Reset
        ARESETn = 0;
        wr_en   = 0;
        rd_en   = 0;
        data_in = 0;

        write_count = 0;
        read_count  = 0;

        S_AXI_AWVALID = 0;
        S_AXI_WVALID  = 0;
        S_AXI_ARVALID = 0;
        S_AXI_RREADY  = 0;
        S_AXI_BREADY  = 0;

        repeat(5) @(posedge ACLK);
        ARESETn = 1;
        repeat(3) @(posedge ACLK);

        // Enable FIFO
        axi_write(CONTROL_ADDR, 32'h1);

        // Open Input CSV
        file_fd = $fopen("filtered_ecg_q31_0_to_10s.csv", "r");
        if (file_fd == 0) begin
            $display("❌ CSV file not found");
            $finish;
        end

        // Open Output CSV
        out_fd = $fopen("fifo_output_stream_10s.csv", "w");
        if (out_fd == 0) begin
            $display("❌ Could not create output CSV file");
            $finish;
        end

        $display("\n=== CONTINUOUS STREAMING STARTED ===");
        $display("\n      TIME     EMPTY  FULL  LEVEL  WR_COUNT  RD_COUNT");
        $display("--------------------------------------------------------");

        while (1) begin

            // Read STATUS
            axi_read(STATUS_ADDR, status_reg);
            status_empty = status_reg[0];
            status_full  = status_reg[1];
            status_level = status_reg[15:8];

            // STATUS LOG
            $display("%8t |   %0d      %0d     %3d      %4d        %4d",
                     $time,
                     status_empty,
                     status_full,
                     status_level,
                     write_count,
                     read_count);

            // WRITE
            if (!status_full && !$feof(file_fd)) begin
                scan_status = $fscanf(file_fd, "%d\n", csv_value);
                if (scan_status == 1) begin
                    @(posedge ACLK);
                    data_in <= csv_value;
                    wr_en   <= 1;
                    @(posedge ACLK);
                    wr_en   <= 0;

                    write_count = write_count + 1;
                end
            end

            // READ
            if (!status_empty) begin
                @(posedge ACLK);
                rd_en <= 1;
                @(posedge ACLK);
                rd_en <= 0;
            end

            if ($feof(file_fd) && status_empty) begin
                break;
            end
        end

        $display("\n=== STREAMING COMPLETE ===");
        $display("Total Writes = %0d", write_count);
        $display("Total Reads  = %0d", read_count);

        if (write_count == read_count)
            $display("✅ PASS: All samples transferred correctly");
        else
            $display("❌ ERROR: Write/Read count mismatch");

        $fclose(file_fd);
        $fclose(out_fd);

        #50;
        $finish;
    end

    // ============================================================
    // WAVEFORM DUMP
    // ============================================================
    initial begin
        $dumpfile("tb_axi_csr_fifo_top_phase7_csv.vcd");
        $dumpvars(0, tb_axi_csr_fifo_top_phase7_csv);
    end

endmodule
/*
`timescale 1ns/1ps

module tb_axi_csr_fifo_top_phase7_csv;

    // ============================================================
    // PARAMETERS
    // ============================================================
    parameter ADDR_WIDTH  = 12;
    parameter DATA_WIDTH  = 32;
    parameter FIFO_DEPTH  = 16;

    parameter CONTROL_ADDR = 12'h000;
    parameter STATUS_ADDR  = 12'h004;

    // ============================================================
    // CLOCK & RESET
    // ============================================================
    reg ACLK;
    reg ARESETn;

    initial ACLK = 0;
    always #5 ACLK = ~ACLK;

    // ============================================================
    // AXI SIGNALS
    // ============================================================
    reg  [ADDR_WIDTH-1:0]  S_AXI_AWADDR;
    reg                    S_AXI_AWVALID;
    wire                   S_AXI_AWREADY;

    reg  [DATA_WIDTH-1:0]  S_AXI_WDATA;
    reg  [(DATA_WIDTH/8)-1:0] S_AXI_WSTRB;
    reg                    S_AXI_WVALID;
    wire                   S_AXI_WREADY;

    wire [1:0]             S_AXI_BRESP;
    wire                   S_AXI_BVALID;
    reg                    S_AXI_BREADY;

    reg  [ADDR_WIDTH-1:0]  S_AXI_ARADDR;
    reg                    S_AXI_ARVALID;
    wire                   S_AXI_ARREADY;

    wire [DATA_WIDTH-1:0]  S_AXI_RDATA;
    wire [1:0]             S_AXI_RRESP;
    wire                   S_AXI_RVALID;
    reg                    S_AXI_RREADY;

    // ============================================================
    // FIFO STREAM INTERFACE
    // ============================================================
    reg wr_en;
    reg rd_en;
    reg [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;

    // ============================================================
    // CSV HANDLING
    // ============================================================
    integer file_fd;
    integer csv_value;
    integer scan_status;

    // ============================================================
    // STATUS REGISTERS
    // ============================================================
    reg [DATA_WIDTH-1:0] status_reg;
    reg status_empty;
    reg status_full;
    reg [7:0] status_level;

    integer write_count;
    integer read_count;

    // ============================================================
    // DUT
    // ============================================================
    axi_csr_fifo_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .ACLK(ACLK),
        .ARESETn(ARESETn),

        .S_AXI_AWADDR(S_AXI_AWADDR),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY),

        .S_AXI_WDATA(S_AXI_WDATA),
        .S_AXI_WSTRB(S_AXI_WSTRB),
        .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_WREADY(S_AXI_WREADY),

        .S_AXI_BRESP(S_AXI_BRESP),
        .S_AXI_BVALID(S_AXI_BVALID),
        .S_AXI_BREADY(S_AXI_BREADY),

        .S_AXI_ARADDR(S_AXI_ARADDR),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY),

        .S_AXI_RDATA(S_AXI_RDATA),
        .S_AXI_RRESP(S_AXI_RRESP),
        .S_AXI_RVALID(S_AXI_RVALID),
        .S_AXI_RREADY(S_AXI_RREADY),

        .wr_en(wr_en),
        .rd_en(rd_en),
        .data_in(data_in),
        .data_out(data_out)
    );

    // ============================================================
    // AXI TASKS
    // ============================================================
    task axi_write(input [ADDR_WIDTH-1:0] addr,
                   input [DATA_WIDTH-1:0] data);
    begin
        @(posedge ACLK);
        S_AXI_AWADDR  <= addr;
        S_AXI_AWVALID <= 1;
        S_AXI_WDATA   <= data;
        S_AXI_WSTRB   <= 4'hF;
        S_AXI_WVALID  <= 1;
        S_AXI_BREADY  <= 1;

        wait(S_AXI_AWREADY && S_AXI_WREADY);
        @(posedge ACLK);
        S_AXI_AWVALID <= 0;
        S_AXI_WVALID  <= 0;

        wait(S_AXI_BVALID);
        @(posedge ACLK);
        S_AXI_BREADY <= 0;
    end
    endtask

    task axi_read(input  [ADDR_WIDTH-1:0] addr,
                  output [DATA_WIDTH-1:0] data);
    begin
        @(posedge ACLK);
        S_AXI_ARADDR  <= addr;
        S_AXI_ARVALID <= 1;
        S_AXI_RREADY  <= 1;

        wait(S_AXI_ARREADY);
        @(posedge ACLK);
        S_AXI_ARVALID <= 0;

        wait(S_AXI_RVALID);
        data = S_AXI_RDATA;

        @(posedge ACLK);
        S_AXI_RREADY <= 0;
    end
    endtask

    // ============================================================
    // DATA MONITOR
    // ============================================================
    always @(posedge ACLK) begin
        if (rd_en) begin
            $display("%0t READ : %0d (signed %0d)", 
                      $time, data_out, $signed(data_out));
            read_count = read_count + 1;
        end
    end

    // ============================================================
    // MAIN STREAMING TEST
    // ============================================================
    initial begin

        // Reset
        ARESETn = 0;
        wr_en   = 0;
        rd_en   = 0;
        data_in = 0;

        write_count = 0;
        read_count  = 0;

        S_AXI_AWVALID = 0;
        S_AXI_WVALID  = 0;
        S_AXI_ARVALID = 0;
        S_AXI_RREADY  = 0;
        S_AXI_BREADY  = 0;

        repeat(5) @(posedge ACLK);
        ARESETn = 1;
        repeat(3) @(posedge ACLK);

        // Enable FIFO
        axi_write(CONTROL_ADDR, 32'h1);

        // Open CSV
        file_fd = $fopen("filtered_ecg_q31_0_to_2s.csv", "r");
        if (file_fd == 0) begin
            $display("❌ CSV file not found");
            $finish;
        end

        $display("\n=== CONTINUOUS STREAMING STARTED ===");
        $display("\n          time      EMPTY     FULL     LEVEL     WR_COUNT     RD_COUNT");
        $display("---------------------------------------------------------------");
        while (1) begin
        
            // Read STATUS
            axi_read(STATUS_ADDR, status_reg);
            status_empty = status_reg[0];
            status_full  = status_reg[1];
            status_level = status_reg[15:8];
        
            // ---- STATUS LOG ----
            $display("         %8t |     %0d      %0d       %3d        %4d           %4d",
                     $time,
                     status_empty,
                     status_full,
                     status_level,
                     write_count,
                     read_count);
        
            // WRITE if space available
            if (!status_full && !$feof(file_fd)) begin
                scan_status = $fscanf(file_fd, "%d\n", csv_value);
                if (scan_status == 1) begin
                    @(posedge ACLK);
                    data_in <= csv_value;
                    wr_en   <= 1;
                    @(posedge ACLK);
                    wr_en   <= 0;
        
                    write_count = write_count + 1;
        
                    $display("%0t WRITE : %0d", $time, csv_value);
                end
            end
        
            // READ if data available
            if (!status_empty) begin
                @(posedge ACLK);
                rd_en <= 1;
                @(posedge ACLK);
                rd_en <= 0;
            end
        
            if ($feof(file_fd) && status_empty) begin
                break;
            end
        end
                $display("\n=== STREAMING COMPLETE ===");
        $display("Total Writes = %0d", write_count);
        $display("Total Reads  = %0d", read_count);

        if (write_count == read_count)
            $display("✅ PASS: All samples transferred correctly");
        else
            $display("❌ ERROR: Write/Read count mismatch");

        #50;
        $finish;
    end

    // ============================================================
    // WAVEFORM DUMP
    // ============================================================
    initial begin
        $dumpfile("tb_axi_csr_fifo_top_phase7_csv.vcd");
        $dumpvars(0, tb_axi_csr_fifo_top_phase7_csv);
    end

endmodule
*/

/*
module tb_axi_csr_fifo_top_phase7_csv;

    // ============================================================
    // PARAMETERS
    // ============================================================
    parameter ADDR_WIDTH  = 12;
    parameter DATA_WIDTH  = 32;
    parameter FIFO_DEPTH  = 16;

    parameter CONTROL_ADDR     = 12'h000;
    parameter STATUS_ADDR      = 12'h004;
    parameter FIFO_LEVEL_ADDR  = 12'h008;

    // ============================================================
    // CLOCK & RESET
    // ============================================================
    reg ACLK;
    reg ARESETn;

    initial ACLK = 0;
    always #5 ACLK = ~ACLK;

    // ============================================================
    // AXI SIGNALS
    // ============================================================
    reg  [ADDR_WIDTH-1:0]  S_AXI_AWADDR;
    reg                    S_AXI_AWVALID;
    wire                   S_AXI_AWREADY;

    reg  [DATA_WIDTH-1:0]  S_AXI_WDATA;
    reg  [(DATA_WIDTH/8)-1:0] S_AXI_WSTRB;
    reg                    S_AXI_WVALID;
    wire                   S_AXI_WREADY;

    wire [1:0]             S_AXI_BRESP;
    wire                   S_AXI_BVALID;
    reg                    S_AXI_BREADY;

    reg  [ADDR_WIDTH-1:0]  S_AXI_ARADDR;
    reg                    S_AXI_ARVALID;
    wire                   S_AXI_ARREADY;

    wire [DATA_WIDTH-1:0]  S_AXI_RDATA;
    wire [1:0]             S_AXI_RRESP;
    wire                   S_AXI_RVALID;
    reg                    S_AXI_RREADY;

    // ============================================================
    // FIFO STREAM INTERFACE
    // ============================================================
    reg wr_en;
    reg rd_en;
    reg [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;

    // ============================================================
    // CSV HANDLING
    // ============================================================
    integer file_fd;
    integer csv_value;
    integer status;
    reg csv_done;
    reg file_valid;

    // ============================================================
    // DUT
    // ============================================================
    axi_csr_fifo_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .ACLK(ACLK),
        .ARESETn(ARESETn),

        .S_AXI_AWADDR(S_AXI_AWADDR),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY),

        .S_AXI_WDATA(S_AXI_WDATA),
        .S_AXI_WSTRB(S_AXI_WSTRB),
        .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_WREADY(S_AXI_WREADY),

        .S_AXI_BRESP(S_AXI_BRESP),
        .S_AXI_BVALID(S_AXI_BVALID),
        .S_AXI_BREADY(S_AXI_BREADY),

        .S_AXI_ARADDR(S_AXI_ARADDR),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY),

        .S_AXI_RDATA(S_AXI_RDATA),
        .S_AXI_RRESP(S_AXI_RRESP),
        .S_AXI_RVALID(S_AXI_RVALID),
        .S_AXI_RREADY(S_AXI_RREADY),

        .wr_en(wr_en),
        .rd_en(rd_en),
        .data_in(data_in),
        .data_out(data_out)
    );

    // ============================================================
    // AXI TASKS
    // ============================================================
    task axi_write(input [ADDR_WIDTH-1:0] addr,
                   input [DATA_WIDTH-1:0] data);
    begin
        @(posedge ACLK);
        S_AXI_AWADDR  <= addr;
        S_AXI_AWVALID <= 1;
        S_AXI_WDATA   <= data;
        S_AXI_WSTRB   <= 4'hF;
        S_AXI_WVALID  <= 1;
        S_AXI_BREADY  <= 1;

        wait(S_AXI_AWREADY && S_AXI_WREADY);
        @(posedge ACLK);
        S_AXI_AWVALID <= 0;
        S_AXI_WVALID  <= 0;

        wait(S_AXI_BVALID);
        @(posedge ACLK);
        S_AXI_BREADY <= 0;
    end
    endtask

    task axi_read(input  [ADDR_WIDTH-1:0] addr,
                  output [DATA_WIDTH-1:0] data);
    begin
        @(posedge ACLK);
        S_AXI_ARADDR  <= addr;
        S_AXI_ARVALID <= 1;
        S_AXI_RREADY  <= 1;

        wait(S_AXI_ARREADY);
        @(posedge ACLK);
        S_AXI_ARVALID <= 0;

        wait(S_AXI_RVALID);
        data = S_AXI_RDATA;

        @(posedge ACLK);
        S_AXI_RREADY <= 0;
    end
    endtask

    // ============================================================
    // INITIALIZATION
    // ============================================================
    initial begin
        ARESETn = 0;
        wr_en   = 0;
        rd_en   = 0;
        data_in = 0;
        csv_done = 0;
        file_valid = 0;

        S_AXI_AWVALID = 0;
        S_AXI_WVALID  = 0;
        S_AXI_ARVALID = 0;
        S_AXI_RREADY  = 0;
        S_AXI_BREADY  = 0;

        repeat(5) @(posedge ACLK);
        ARESETn = 1;
        repeat(3) @(posedge ACLK);

        axi_write(CONTROL_ADDR, 32'h1);

        file_fd = $fopen("filtered_ecg_q31_0_to_2s.csv", "r");

        if (file_fd == 0) begin
            $display("❌ ERROR: CSV not found.");
            $finish;
        end
        else begin
            file_valid = 1;
            $display("✅ CSV opened.");
        end
    end

    // ============================================================
    // STREAMING LOGIC
    // ============================================================
    always @(posedge ACLK) begin
        if (!ARESETn) begin
            wr_en <= 0;
            rd_en <= 0;
        end
        else begin
            wr_en <= 0;
            rd_en <= 0;

            if (file_valid && !csv_done) begin
                if (!$feof(file_fd)) begin
                    status = $fscanf(file_fd, "%d\n", csv_value);
                    if (status == 1) begin
                        data_in <= csv_value;
                        wr_en <= 1;
                        $display("%0t WRITE : %0d", $time, csv_value);
                    end
                end
                else begin
                    csv_done = 1;
                    file_valid = 0;
                    $fclose(file_fd);
                    $display("--- CSV DONE ---");
                end
            end

            // Continuous read
            rd_en <= 1;
        end
    end

    // ============================================================
    // DATA MONITOR
    // ============================================================
    always @(posedge ACLK) begin
        if (rd_en) begin
            $display("%0t READ  : %0d", $time, data_out);
        end
    end

    // ============================================================
    // TERMINATION
    // ============================================================
    initial begin
        wait(csv_done);
        #200;
        $display("🎉 PHASE-7 COMPLETED");
        $finish;
    end
    initial begin
        $dumpfile("tb_axi_csr_fifo_top_phase7_csv.vcd");
        $dumpvars(0, tb_axi_csr_fifo_top_phase7_csv);
    end
        
endmodule*/