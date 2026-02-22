`timescale 1ns / 1ps
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
/*
`timescale 1ns/1ps

module tb_axi_csr_fifo_top_phase5;

    parameter ADDR_WIDTH = 12;
    parameter DATA_WIDTH = 32;
    parameter FIFO_DEPTH = 16;

    parameter CONTROL_ADDR = 12'h000;
    parameter STATUS_ADDR  = 12'h004;

    // ----------------------------------------
    // Clock & Reset
    // ----------------------------------------
    reg ACLK;
    reg ARESETn;

    initial ACLK = 0;
    always #5 ACLK = ~ACLK;

    // ----------------------------------------
    // AXI Signals
    // ----------------------------------------
    reg  [ADDR_WIDTH-1:0] S_AXI_AWADDR;
    reg                   S_AXI_AWVALID;
    wire                  S_AXI_AWREADY;

    reg  [DATA_WIDTH-1:0] S_AXI_WDATA;
    reg  [(DATA_WIDTH/8)-1:0] S_AXI_WSTRB;
    reg                   S_AXI_WVALID;
    wire                  S_AXI_WREADY;

    wire [1:0]            S_AXI_BRESP;
    wire                  S_AXI_BVALID;
    reg                   S_AXI_BREADY;

    reg  [ADDR_WIDTH-1:0] S_AXI_ARADDR;
    reg                   S_AXI_ARVALID;
    wire                  S_AXI_ARREADY;

    wire [DATA_WIDTH-1:0] S_AXI_RDATA;
    wire [1:0]            S_AXI_RRESP;
    wire                  S_AXI_RVALID;
    reg                   S_AXI_RREADY;

    // ----------------------------------------
    // FIFO Interface
    // ----------------------------------------
    reg                   wr_en;
    reg                   rd_en;
    reg  [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;

    // ----------------------------------------
    // DUT
    // ----------------------------------------
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

    // ----------------------------------------
    // AXI WRITE TASK
    // ----------------------------------------
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
        S_AXI_BREADY  <= 0;
    end
    endtask

    // ----------------------------------------
    // AXI READ TASK
    // ----------------------------------------
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

    // ----------------------------------------
    // TEST
    // ----------------------------------------
    integer i;
    reg [31:0] status_reg;
    reg [7:0]  level_before;
    reg [7:0]  level_after;

    initial begin

        // Initialize
        ARESETn = 0;
        wr_en   = 0;
        rd_en   = 0;
        data_in = 0;

        S_AXI_AWVALID = 0;
        S_AXI_WVALID  = 0;
        S_AXI_ARVALID = 0;
        S_AXI_BREADY  = 0;
        S_AXI_RREADY  = 0;

        #50;
        ARESETn = 1;

        // Enable FIFO
        axi_write(CONTROL_ADDR, 32'h1);

        // ----------------------------------------
        // Pre-fill FIFO with 8 entries
        // ----------------------------------------
        for (i = 1; i <= 8; i = i + 1) begin
            @(posedge ACLK);
            data_in <= i;
            wr_en   <= 1;
            @(posedge ACLK);
            wr_en   <= 0;
        end

        repeat(3) @(posedge ACLK);

        axi_read(STATUS_ADDR, status_reg);
        level_before = status_reg[15:8];
        $display("Level before simultaneous R/W = %0d", level_before);

        // ----------------------------------------
        // Simultaneous Read/Write Stress
        // ----------------------------------------
        $display("Starting simultaneous R/W...");

        for (i = 0; i < 20; i = i + 1) begin
            @(posedge ACLK);
            wr_en   <= 1;
            rd_en   <= 1;
            data_in <= i + 100;   // new values

            @(posedge ACLK);
            wr_en <= 0;
            rd_en <= 0;
        end

        repeat(3) @(posedge ACLK);

        axi_read(STATUS_ADDR, status_reg);
        level_after = status_reg[15:8];
        $display("Level after simultaneous R/W = %0d", level_after);

        // ----------------------------------------
        // Self-check
        // ----------------------------------------
        if (level_before == level_after)
            $display("PHASE-5 PASSED: Level stable during simultaneous R/W.");
        else
            $display("PHASE-5 FAILED: Level changed during simultaneous R/W!");

        #50;
        $stop;

    end

endmodule
*/

/*
`timescale 1ns/1ps

module tb_axi_csr_fifo_top_phase5_advanced;

    // ============================================================
    // PARAMETERS
    // ============================================================
    parameter ADDR_WIDTH = 12;
    parameter DATA_WIDTH = 32;
    parameter FIFO_DEPTH = 16;

    // Register Map (Must match CSR)
    localparam CONTROL_ADDR    = 12'h000;
    localparam STATUS_ADDR     = 12'h004;
    localparam FIFO_LEVEL_ADDR = 12'h008;

    // ============================================================
    // CLOCK & RESET
    // ============================================================
    reg ACLK;
    reg ARESETn;

    initial ACLK = 0;
    always #5 ACLK = ~ACLK;   // 100 MHz clock

    // ============================================================
    // AXI SIGNALS
    // ============================================================
    reg  [ADDR_WIDTH-1:0] S_AXI_AWADDR;
    reg                   S_AXI_AWVALID;
    wire                  S_AXI_AWREADY;

    reg  [DATA_WIDTH-1:0] S_AXI_WDATA;
    reg  [(DATA_WIDTH/8)-1:0] S_AXI_WSTRB;
    reg                   S_AXI_WVALID;
    wire                  S_AXI_WREADY;

    wire [1:0]            S_AXI_BRESP;
    wire                  S_AXI_BVALID;
    reg                   S_AXI_BREADY;

    reg  [ADDR_WIDTH-1:0] S_AXI_ARADDR;
    reg                   S_AXI_ARVALID;
    wire                  S_AXI_ARREADY;

    wire [DATA_WIDTH-1:0] S_AXI_RDATA;
    wire [1:0]            S_AXI_RRESP;
    wire                  S_AXI_RVALID;
    reg                   S_AXI_RREADY;

    // ============================================================
    // FIFO INTERFACE
    // ============================================================
    reg                   wr_en;
    reg                   rd_en;
    reg  [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;

    reg  [DATA_WIDTH-1:0] level_reg;  // AXI read storage

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
    // SCOREBOARD
    // ============================================================
    int scoreboard[$];
    int error_count = 0;

    reg fifo_full_d, fifo_empty_d;
    reg rd_request;
    reg [DATA_WIDTH-1:0] expected_data;

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
    task axi_read(input [ADDR_WIDTH-1:0] addr,
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
    // MAIN TEST
    // ============================================================
    integer i;

    initial begin

        // ---------------- Initialization ----------------
        ARESETn = 0;
        wr_en   = 0;
        rd_en   = 0;
        data_in = 0;

        S_AXI_AWVALID = 0;
        S_AXI_WVALID  = 0;
        S_AXI_ARVALID = 0;
        S_AXI_BREADY  = 0;
        S_AXI_RREADY  = 0;

        #50;
        ARESETn = 1;

        // Enable FIFO via CONTROL register
        axi_write(CONTROL_ADDR, 32'h1);

        $display("=== Phase-5 Advanced Random Stress Test Started ===");

        // ============================================================
        // RANDOM STRESS LOOP
        // ============================================================
        for (i = 0; i < 500; i = i + 1) begin

            @(posedge ACLK);

            // Capture previous status
            fifo_full_d  = dut.fifo_inst.fifo_full;
            fifo_empty_d = dut.fifo_inst.fifo_empty;

            // Random stimulus
            wr_en   = $urandom_range(0,1);
            rd_en   = $urandom_range(0,1);
            data_in = $urandom_range(0,1000000);

            // ---------------- WRITE MODEL ----------------
            if (wr_en && !fifo_full_d)
                scoreboard.push_back(data_in);

            // ---------------- READ MODEL ----------------
            rd_request = (rd_en && !fifo_empty_d);

            if (rd_request && scoreboard.size() > 0)
                expected_data = scoreboard[0];

            @(posedge ACLK);  // FIFO read latency

            if (rd_request && scoreboard.size() > 0) begin
                if (data_out !== expected_data) begin
                    $display("❌ DATA MISMATCH at cycle %0d! Expected=%0d Got=%0d",
                             i, expected_data, data_out);
                    error_count++;
                end
                else begin
                    $display("✅ DATA MATCH at cycle %0d (Value=%0d)",
                             i, data_out);
                end
                scoreboard.pop_front();
            end

            // ---------------- SAFE LEVEL CHECK ----------------
            if (i % 1 == 0) begin   // snapshot check

                wr_en = 0;
                rd_en = 0;

                @(posedge ACLK);
                @(posedge ACLK);

                axi_read(FIFO_LEVEL_ADDR, level_reg);

                if (level_reg != scoreboard.size()) begin
                    $display("❌ LEVEL MISMATCH at cycle %0d! HW=%0d SW=%0d",
                             i, level_reg, scoreboard.size());
                    error_count++;
                end
                else begin
                    $display("✅ LEVEL MATCH at cycle %0d (Level=%0d)",
                             i, level_reg);
                end
            end
            
            // ------------------------------------------------
            // Overflow Check
            // ------------------------------------------------
            if (scoreboard.size() > FIFO_DEPTH) begin
                $display("❌ Overflow detected in scoreboard at cycle %0d!", i);
                error_count++;
            end
            else begin
                $display("✅ No overflow at cycle %0d", i);
            end
        
            // ------------------------------------------------
            // Underflow Check
            // ------------------------------------------------
            if (scoreboard.size() < 0) begin
                $display("❌ Underflow detected in scoreboard at cycle %0d!", i);
                error_count++;
            end
            else begin
                $display("✅ No underflow at cycle %0d", i);
            end
        
        end

        // ---------------- FINAL RESULT ----------------
        if (error_count == 0)
            $display("🎉 PHASE-5 ADVANCED PASSED: No errors detected.");
        else
            $display("🚨 PHASE-5 ADVANCED FAILED: %0d errors detected.", error_count);

        #100;
        $stop;
    end
    
    initial begin
        $dumpfile("tb_axi_csr_fifo_top_phase5_advanced.vcd");
        $dumpvars(0, tb_axi_csr_fifo_top_phase5_advanced);
    end

endmodule
*/
`timescale 1ns/1ps

module tb_axi_csr_fifo_top_phase6;

    // ============================================================
    // PARAMETERS
    // ============================================================
    parameter ADDR_WIDTH = 12;
    parameter DATA_WIDTH = 32;
    parameter FIFO_DEPTH = 16;

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
    reg  [ADDR_WIDTH-1:0] S_AXI_AWADDR;
    reg                   S_AXI_AWVALID;
    wire                  S_AXI_AWREADY;

    reg  [DATA_WIDTH-1:0] S_AXI_WDATA;
    reg  [(DATA_WIDTH/8)-1:0] S_AXI_WSTRB;
    reg                   S_AXI_WVALID;
    wire                  S_AXI_WREADY;

    wire [1:0]            S_AXI_BRESP;
    wire                  S_AXI_BVALID;
    reg                   S_AXI_BREADY;

    reg  [ADDR_WIDTH-1:0] S_AXI_ARADDR;
    reg                   S_AXI_ARVALID;
    wire                  S_AXI_ARREADY;

    wire [DATA_WIDTH-1:0] S_AXI_RDATA;
    wire [1:0]            S_AXI_RRESP;
    wire                  S_AXI_RVALID;
    reg                   S_AXI_RREADY;

    // ============================================================
    // FIFO INTERFACE
    // ============================================================
    reg                   wr_en;
    reg                   rd_en;
    reg  [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;

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
    // REFERENCE MODEL
    // ============================================================
    reg [31:0] expected_level;
    integer error_count;

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

        wait (S_AXI_AWREADY && S_AXI_WREADY);

        @(posedge ACLK);
        S_AXI_AWVALID <= 0;
        S_AXI_WVALID  <= 0;

        wait (S_AXI_BVALID);
        @(posedge ACLK);
        S_AXI_BREADY <= 0;
    end
    endtask

    // ============================================================
    // CONTINUOUS LEVEL CHECK (ASSERTION STYLE)
    // ============================================================
    always @(posedge ACLK) begin
        if (!ARESETn)
            expected_level <= 0;
        else begin
            case ({wr_en && !dut.fifo_inst.fifo_full,
                   rd_en && !dut.fifo_inst.fifo_empty})
                2'b10: expected_level <= expected_level + 1;
                2'b01: expected_level <= expected_level - 1;
            endcase
        end

        if (dut.fifo_inst.fifo_level !== expected_level) begin
            $display("❌ LEVEL ERROR! HW=%0d SW=%0d",
                      dut.fifo_inst.fifo_level, expected_level);
            error_count = error_count + 1;
        end
    end

    // ============================================================
    // MAIN TEST
    // ============================================================
    integer i;

    initial begin

        // ---------------------------
        // INITIALIZATION
        // ---------------------------
        ARESETn = 0;
        wr_en   = 0;
        rd_en   = 0;
        data_in = 0;
        error_count = 0;

        S_AXI_AWVALID = 0;
        S_AXI_WVALID  = 0;
        S_AXI_ARVALID = 0;
        S_AXI_BREADY  = 0;
        S_AXI_RREADY  = 0;

        #50;
        ARESETn = 1;

        // Enable FIFO
        axi_write(CONTROL_ADDR, 32'h1);

        $display("=== PHASE-6 SYSTEM ROBUSTNESS TEST STARTED ===");

        // --------------------------------------------------------
        // LONG RANDOM TRAFFIC + RANDOM RESET INSERTION
        // --------------------------------------------------------
        for (i = 0; i < 2000; i = i + 1) begin

            @(posedge ACLK);

            wr_en   = $urandom_range(0,1);
            rd_en   = $urandom_range(0,1);
            data_in = $urandom;

            // Random reset injection
            if ($urandom_range(0,200) == 5) begin
                $display("⚠ Injecting reset at cycle %0d", i);
                ARESETn = 0;
                @(posedge ACLK);
                @(posedge ACLK);
                ARESETn = 1;
            end
        end

        // --------------------------------------------------------
        // BOUNDARY CONDITION TEST
        // --------------------------------------------------------
        $display("=== Boundary Test: Fill FIFO ===");

        wr_en = 1;
        rd_en = 0;

        for (i = 0; i < FIFO_DEPTH+2; i = i + 1)
            @(posedge ACLK);

        wr_en = 0;

        $display("=== Boundary Test: Empty FIFO ===");

        rd_en = 1;
        for (i = 0; i < FIFO_DEPTH+2; i = i + 1)
            @(posedge ACLK);

        rd_en = 0;

        // --------------------------------------------------------
        // FINAL RESULT
        // --------------------------------------------------------
        if (error_count == 0)
            $display("🎉 PHASE-6 PASSED: System Robustness Verified.");
        else
            $display("🚨 PHASE-6 FAILED: %0d errors detected.", error_count);

        #100;
        $stop;
    end

endmodule