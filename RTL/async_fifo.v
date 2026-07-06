`timescale 1ns / 1ps

module async_fifo#(parameter DATA_WIDTH = 8,parameter ADDR_SIZE  = 3)
(
    // Write Side
    input wr_clk,
    input wr_rst,
    input wr_en,
    input [DATA_WIDTH-1:0] din,

    // Read Side
    input rd_clk,
    input rd_rst,
    input rd_en,

    output [DATA_WIDTH-1:0] dout,

    output full,
    output empty
);
// Write Pointer
wire [ADDR_SIZE:0] wr_ptr_bin;
wire [ADDR_SIZE:0] wr_ptr_gray;
wire [ADDR_SIZE-1:0] wr_addr;
// Read Pointer
wire [ADDR_SIZE:0] rd_ptr_bin;
wire [ADDR_SIZE:0] rd_ptr_gray;
wire [ADDR_SIZE-1:0] rd_addr;

// Synchronized Gray Pointers
wire [ADDR_SIZE:0] wr_ptr_gray_sync;
wire [ADDR_SIZE:0] rd_ptr_gray_sync;

write_ctrl #(
    .ADDR_SIZE(ADDR_SIZE)
)
WR_CTRL
(
    .wr_clk(wr_clk),
    .wr_rst(wr_rst),
    .wr_en(wr_en),

    .rd_ptr_gray_sync(rd_ptr_gray_sync),

    .wr_addr(wr_addr),
    .wr_ptr_bin(wr_ptr_bin),
    .wr_ptr_gray(wr_ptr_gray),

    .full(full)
);
// Read Controller
read_ctrl #(
    .ADDR_SIZE(ADDR_SIZE)
)
RD_CTRL
(
    .rd_clk(rd_clk),
    .rd_rst(rd_rst),
    .rd_en(rd_en),

    .wr_ptr_gray_sync(wr_ptr_gray_sync),

    .rd_addr(rd_addr),
    .rd_ptr_bin(rd_ptr_bin),
    .rd_ptr_gray(rd_ptr_gray),

    .empty(empty)
);
// FIFO Memory
fifo_mem #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_SIZE(ADDR_SIZE)
)
MEM
(
    .wr_clk(wr_clk),
    .wr_en(wr_en && !full),

    .wr_addr(wr_addr),
    .din(din),

    .rd_addr(rd_addr),
    .dout(dout)
);
// Write Pointer -> Read Clock Synchronizer
sync_ff #(
    .ADDR_SIZE(ADDR_SIZE)
)
WR2RD_SYNC
(
    .clk(rd_clk),
    .rst(rd_rst),

    .gray_in(wr_ptr_gray),
    .gray_out(wr_ptr_gray_sync)
);
// Read Pointer -> Write Clock Synchronizer
sync_ff #(
    .ADDR_SIZE(ADDR_SIZE)
)
RD2WR_SYNC
(
    .clk(wr_clk),
    .rst(wr_rst),

    .gray_in(rd_ptr_gray),
    .gray_out(rd_ptr_gray_sync)
);
endmodule
