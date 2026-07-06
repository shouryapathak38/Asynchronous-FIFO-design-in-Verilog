module read_ctrl#(parameter ADDR_SIZE = 3)(
    input rd_clk,    // Read clock
    input rd_rst,    // Read reset
    input rd_en,     // Read enable
    input [ADDR_SIZE:0] wr_ptr_gray_sync, // Write pointer in Gray code synced to read clock
    output [ADDR_SIZE-1:0] rd_addr,   // Read address
    output [ADDR_SIZE:0] rd_ptr_bin, // Read pointer in binary
    output [ADDR_SIZE:0] rd_ptr_gray, // Read pointer in Gray code
    output empty       // FIFO empty flag
    );
// Internal Registers
reg [ADDR_SIZE:0] rd_bin;
reg [ADDR_SIZE:0] rd_gray;
// Next pointer logic
wire [ADDR_SIZE:0] rd_bin_next;
wire [ADDR_SIZE:0] rd_gray_next;
// Increment only when read is enabled and FIFO is not empty
assign rd_bin_next = rd_bin + (rd_en && !empty);
// Binary to Gray conversion
assign rd_gray_next = rd_bin_next ^ (rd_bin_next >> 1);
// Sequential logic
always @(posedge rd_clk or posedge rd_rst)
begin
    if (rd_rst)
    begin
        rd_bin  <= 0;
        rd_gray <= 0;
    end
    else
    begin
        rd_bin  <= rd_bin_next;
        rd_gray <= rd_gray_next;
    end
end
// Outputs
assign rd_addr    = rd_bin[ADDR_SIZE-1:0];
assign rd_ptr_bin = rd_bin;
assign rd_ptr_gray = rd_gray;
// Empty flag detection
assign empty =(rd_gray == wr_ptr_gray_sync);
endmodule
