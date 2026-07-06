`timescale 1ns / 1ps
module write_ctrl#(parameter ADDR_SIZE = 3)
(
    input wr_clk, input wr_rst, input wr_en,
    input [ADDR_SIZE:0] rd_ptr_gray_sync,
    output [ADDR_SIZE-1:0] wr_addr,
    output [ADDR_SIZE:0] wr_ptr_bin,
    output [ADDR_SIZE:0] wr_ptr_gray,
    output full
);
reg [ADDR_SIZE:0] wr_bin;
reg [ADDR_SIZE:0] wr_gray;
reg full_q;                          // FIX: registered copy of full
wire [ADDR_SIZE:0] wr_bin_next;
wire [ADDR_SIZE:0] wr_gray_next;
wire full_next;
// FIX: gate the increment with full_q (already-settled, registered value
// from the previous cycle), NOT with the combinational 'full' wire below.
// Using the combinational 'full' here created a zero-delay loop:
//   full -> wr_bin_next -> wr_gray_next -> full
// which 4-state simulators cannot resolve (X never clears, and the
// X propagates into wr_bin/wr_gray forever once latched).
assign wr_bin_next = wr_bin + (wr_en && !full_q);
assign wr_gray_next = wr_bin_next ^ (wr_bin_next >> 1);
assign full_next = (wr_gray_next == {~rd_ptr_gray_sync[ADDR_SIZE:ADDR_SIZE-1],rd_ptr_gray_sync[ADDR_SIZE-2:0]});
always @(posedge wr_clk or posedge wr_rst)
begin
    if (wr_rst) begin
        wr_bin  <= 0;
        wr_gray <= 0;
        full_q  <= 0;
    end else begin
        wr_bin  <= wr_bin_next;
        wr_gray <= wr_gray_next;
        full_q  <= full_next;
    end
end
assign wr_addr    = wr_bin[ADDR_SIZE-1:0];
assign wr_ptr_bin = wr_bin;
assign wr_ptr_gray = wr_gray;
assign full = full_q;
endmodule