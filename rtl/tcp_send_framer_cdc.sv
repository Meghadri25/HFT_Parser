module tcp_send_framer_cdc #(
    parameter int FIFO_DEPTH = 16
) (
    input  logic        in_clk,
    input  logic        out_clk,
    input  logic        rst_n,

    input  logic        start,
    input  logic [15:0] payload_length,
    output logic        busy,
    output logic        done,

    input  logic        in_valid,
    output logic        in_ready,
    input  logic [7:0]  in_data,
    input  logic        in_sop,
    input  logic        in_eop,
    input  logic        in_error,

    output logic        out_valid,
    input  logic        out_ready,
    output logic [7:0]  out_data,
    output logic        out_sop,
    output logic        out_eop,
    output logic        out_error
);

    logic        core_out_valid;
    logic        core_out_ready;
    logic [7:0]  core_out_data;
    logic        core_out_sop;
    logic        core_out_eop;
    logic        core_out_error;
    logic        core_busy;
    logic        core_done_unused;

    logic        fifo_wr_ready;
    logic        fifo_rd_valid;
    logic [10:0] fifo_rd_data;

    logic        busy_sync;
    logic        done_r;

    tcp_send_framer core (
        .clk(in_clk),
        .rst_n(rst_n),
        .start(start),
        .payload_length(payload_length),
        .busy(core_busy),
        .done(core_done_unused),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .in_data(in_data),
        .in_sop(in_sop),
        .in_eop(in_eop),
        .in_error(in_error),
        .out_valid(core_out_valid),
        .out_ready(core_out_ready),
        .out_data(core_out_data),
        .out_sop(core_out_sop),
        .out_eop(core_out_eop),
        .out_error(core_out_error)
    );

    async_fifo #(
        .DATA_WIDTH(11),
        .DEPTH(FIFO_DEPTH)
    ) stream_fifo (
        .wr_clk(in_clk),
        .wr_rst_n(rst_n),
        .wr_en(core_out_valid),
        .wr_data({core_out_error, core_out_eop, core_out_sop, core_out_data}),
        .wr_ready(fifo_wr_ready),
        .full(),
        .rd_clk(out_clk),
        .rd_rst_n(rst_n),
        .rd_en(out_ready && fifo_rd_valid),
        .rd_data(fifo_rd_data),
        .rd_valid(fifo_rd_valid),
        .empty()
    );

    cdc_level_sync busy_sync_inst (
        .src_level(core_busy),
        .dst_clk(out_clk),
        .dst_rst_n(rst_n),
        .dst_level(busy_sync)
    );

    assign core_out_ready = fifo_wr_ready;
    assign out_valid = fifo_rd_valid;
    assign {out_error, out_eop, out_sop, out_data} = fifo_rd_data;
    assign busy = busy_sync || fifo_rd_valid;

    always_ff @(posedge out_clk or negedge rst_n) begin
        if (!rst_n) begin
            done_r <= 1'b0;
        end else begin
            done_r <= out_ready && fifo_rd_valid && fifo_rd_data[9];
        end
    end

    assign done = done_r;

endmodule