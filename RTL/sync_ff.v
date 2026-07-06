`timescale 1ns / 1ps

module sync_ff#( parameter ADDR_SIZE = 3)
(
    input clk,
    input rst,
    input  [ADDR_SIZE:0] gray_in,

    output reg [ADDR_SIZE:0] gray_out
);
reg [ADDR_SIZE:0] sync_ff1;

always @(posedge clk)
begin
    if(rst)
    begin
        sync_ff1 <= 0;
        gray_out <= 0;
    end
    else
    begin
        sync_ff1 <= gray_in;
        gray_out <= sync_ff1;
    end
end
endmodule
