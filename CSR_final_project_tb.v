`timescale 1ns/1ps
`include "CSR_final_project.v"
module axi4_lite_slave_tb;

  localparam ADDR_WIDTH = 12;
  localparam DATA_WIDTH = 32;
  localparam CLK_PERIOD = 10;

  reg ACLK;
  reg ARESETn;

  // AXI Write Address Channel
  reg  AWVALID;
  wire AWREADY;
  reg  [ADDR_WIDTH-1:0] AWADDR;

  // AXI Write Data Channel
  reg  WVALID;
  wire WREADY;
  reg  [DATA_WIDTH-1:0] WDATA;
  reg  [DATA_WIDTH/8-1:0] WSTRB;

  // AXI Write Response Channel
  wire BVALID;
  reg  BREADY;
  wire [1:0] BRESP;

  // AXI Read Address Channel
  reg  ARVALID;
  wire ARREADY;
  reg  [ADDR_WIDTH-1:0] ARADDR;

  // AXI Read Data Channel
  wire RVALID;
  reg  RREADY;
  wire [DATA_WIDTH-1:0] RDATA;
  wire [1:0] RRESP;

  // FIFO status signals (NEW)
  reg fifo_empty_i;
  reg fifo_full_i;
  reg [DATA_WIDTH-1:0] fifo_level_i;

  integer test_count = 0;
  integer pass_count = 0;
  integer fail_count = 0;

  // DUT
  axi4_lite_slave dut (
    .ACLK(ACLK),
    .ARESETn(ARESETn),

    .S_AXI_AWADDR(AWADDR),
    .S_AXI_AWVALID(AWVALID),
    .S_AXI_AWREADY(AWREADY),

    .S_AXI_WDATA(WDATA),
    .S_AXI_WSTRB(WSTRB),
    .S_AXI_WVALID(WVALID),
    .S_AXI_WREADY(WREADY),

    .S_AXI_BRESP(BRESP),
    .S_AXI_BVALID(BVALID),
    .S_AXI_BREADY(BREADY),

    .S_AXI_ARADDR(ARADDR),
    .S_AXI_ARVALID(ARVALID),
    .S_AXI_ARREADY(ARREADY),

    .S_AXI_RDATA(RDATA),
    .S_AXI_RRESP(RRESP),
    .S_AXI_RVALID(RVALID),
    .S_AXI_RREADY(RREADY),

    .fifo_empty_i(fifo_empty_i),
    .fifo_full_i(fifo_full_i),
    .fifo_level_i(fifo_level_i),

    .CONTROL_o()
  );

  // Clock generation
  initial ACLK = 0;
  always #(CLK_PERIOD/2) ACLK = ~ACLK;

  // ---------------- AXI WRITE TASK ----------------
  task axi_write;
    input [ADDR_WIDTH-1:0] addr;
    input [DATA_WIDTH-1:0] data;
    begin
      @(posedge ACLK);
      AWVALID = 1;
      WVALID  = 1;
      AWADDR  = addr;
      WDATA   = data;
      WSTRB   = {DATA_WIDTH/8{1'b1}};

      wait (AWREADY && WREADY);
      @(posedge ACLK);
      AWVALID = 0;
      WVALID  = 0;

      BREADY = 1;
      wait (BVALID);
      @(posedge ACLK);
      BREADY = 0;
    end
  endtask

  // ---------------- AXI READ TASK ----------------
  task axi_read;
    input  [ADDR_WIDTH-1:0] addr;
    output [DATA_WIDTH-1:0] data;
    begin
      @(posedge ACLK);
      ARVALID = 1;
      ARADDR  = addr;

      wait (ARREADY);
      @(posedge ACLK);
      ARVALID = 0;

      RREADY = 1;
      wait (RVALID);
      data = RDATA;
      @(posedge ACLK);
      RREADY = 0;
    end
  endtask

  // ---------------- CHECK TASK ----------------
  task check;
    input [DATA_WIDTH-1:0] exp;
    input [DATA_WIDTH-1:0] act;
    input [256*8-1:0] msg;
    begin
      test_count = test_count + 1;
      if (exp === act) begin
        pass_count = pass_count + 1;
        $display("[PASS] %s", msg);
      end else begin
        fail_count = fail_count + 1;
        $display("[FAIL] %s : EXP=0x%h GOT=0x%h", msg, exp, act);
      end
    end
  endtask

  reg [DATA_WIDTH-1:0] rd_data;

  // ---------------- TEST SEQUENCE ----------------
  initial begin
    $display("AXI4-Lite CSR Testbench (Corrected)");

    // Init
    AWVALID = 0; WVALID = 0; BREADY = 0;
    ARVALID = 0; RREADY = 0;
    AWADDR  = 0; WDATA  = 0; WSTRB  = 0; ARADDR = 0;

    fifo_empty_i = 1;
    fifo_full_i  = 0;
    fifo_level_i = 0;

    ARESETn = 0;
    #(CLK_PERIOD*5);
    ARESETn = 1;
    #(CLK_PERIOD*2);

    // ---- CONTROL RW ----
    axi_write(12'h000, 32'hDEADBEEF);
    axi_read (12'h000, rd_data);
    check(32'hDEADBEEF, rd_data, "CONTROL register RW");

    // ---- STATUS RO ----
    fifo_empty_i = 0;
    fifo_full_i  = 1;
    axi_read(12'h004, rd_data);
    check({30'b0,1'b1,1'b0}, rd_data, "STATUS reflects FIFO state");

    // ---- FIFO_LEVEL RO ----
    fifo_level_i = 32'd5;
    axi_read(12'h008, rd_data);
    check(32'd5, rd_data, "FIFO_LEVEL reflects occupancy");

    // ---- Attempt write to RO register ----
    axi_write(12'h004, 32'hFFFFFFFF);
    axi_read (12'h004, rd_data);
    check({30'b0,1'b1,1'b0}, rd_data, "STATUS remains RO");

    $display("Tests=%0d Pass=%0d Fail=%0d",
              test_count, pass_count, fail_count);

    $finish;
  end
  
    // Waveform dump
    initial begin
      $dumpfile("csr_axil_dump.vcd");
        $dumpvars(0, axi4_lite_slave_tb);
    end

endmodule

