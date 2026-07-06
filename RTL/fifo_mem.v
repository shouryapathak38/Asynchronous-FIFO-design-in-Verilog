`timescale 1ns / 1ps
module fifo_mem
#(
    parameter DATA_WIDTH = 8,
    parameter ADDR_SIZE  = 3
)
(
    input wr_clk,
    input wr_en,

    input [ADDR_SIZE-1:0] wr_addr,
    input [DATA_WIDTH-1:0] din,

    input [ADDR_SIZE-1:0] rd_addr,

    output [DATA_WIDTH-1:0] dout
);

reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_SIZE)-1];

// Write Port
always @(posedge wr_clk)
begin
    if(wr_en)
        mem[wr_addr] <= din;
end

assign dout = mem[rd_addr];

endmodule
