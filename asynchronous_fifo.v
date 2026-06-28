module asynchronous_fifo
#(
    parameter DEPTH = 8,
    parameter DATA_WIDTH = 8
)
(
    input wclk,
    input wrst_n,

    input rclk,
    input rrst_n,

    input w_en,
    input r_en,

    input [DATA_WIDTH-1:0] data_in,

    output [DATA_WIDTH-1:0] data_out,
    output full,
    output empty
);

parameter PTR_WIDTH = $clog2(DEPTH);

wire [PTR_WIDTH:0] g_wptr_sync;
wire [PTR_WIDTH:0] g_rptr_sync;

wire [PTR_WIDTH:0] b_wptr;
wire [PTR_WIDTH:0] b_rptr;

wire [PTR_WIDTH:0] g_wptr;
wire [PTR_WIDTH:0] g_rptr;


synchronizer #(PTR_WIDTH)
sync_wptr
(
    .clk(rclk),
    .rst_n(rrst_n),
    .d_in(g_wptr),
    .d_out(g_wptr_sync)
);

synchronizer #(PTR_WIDTH)
sync_rptr
(
    .clk(wclk),
    .rst_n(wrst_n),
    .d_in(g_rptr),
    .d_out(g_rptr_sync)
);

wptr_handler #(PTR_WIDTH)
wptr_h
(
    .wclk(wclk),
    .wrst_n(wrst_n),
    .w_en(w_en),
    .g_rptr_sync(g_rptr_sync),
    .b_wptr(b_wptr),
    .g_wptr(g_wptr),
    .full(full)
);

rptr_handler #(PTR_WIDTH)
rptr_h
(
    .rclk(rclk),
    .rrst_n(rrst_n),
    .r_en(r_en),
    .g_wptr_sync(g_wptr_sync),
    .b_rptr(b_rptr),
    .g_rptr(g_rptr),
    .empty(empty)
);

fifo_mem
#(
    .DEPTH(DEPTH),
    .DATA_WIDTH(DATA_WIDTH),
    .PTR_WIDTH(PTR_WIDTH)
)
fifom
(
    .wclk(wclk),
    .w_en(w_en),
    .rclk(rclk),
    .r_en(r_en),
    .b_wptr(b_wptr),
    .b_rptr(b_rptr),
    .data_in(data_in),
    .full(full),
    .empty(empty),
    .data_out(data_out)
);

endmodule
