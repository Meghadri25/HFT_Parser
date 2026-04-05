module tcp_receive_parser_cdc #(
    parameter int FIFO_DEPTH = 16
) (
    input  logic       in_clk,
    input  logic       out_clk,
    input  logic       rst_n,

    input  logic       in_valid,
    output logic       in_ready,
    input  logic [7:0] in_data,
    input  logic       in_sop,
    input  logic       in_eop,
    input  logic       in_error,

    output logic       out_valid,
    input  logic       out_ready,
    output logic [7:0] out_data,
    output logic       out_sop,
    output logic       out_eop,

    output logic       message_valid,
    output logic       message_error,
    output logic [15:0] message_length
);

    logic        core_out_valid;
    logic        core_out_ready;
    logic [7:0]  core_out_data;
    logic        core_out_sop;
    logic        core_out_eop;

    logic        fifo_rd_valid;
    logic [9:0]  fifo_rd_data;

    tcp_receive_parser core (
        .clk(in_clk),
        .rst_n(rst_n),
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
        .message_valid(message_valid),
        .message_error(message_error),
        .message_length(message_length)
    );

    async_fifo #(
        .DATA_WIDTH(10),
        .DEPTH(FIFO_DEPTH)
    ) stream_fifo (
        .wr_clk(in_clk),
        .wr_rst_n(rst_n),
        .wr_en(core_out_valid),
        .wr_data({core_out_eop, core_out_sop, core_out_data}),
        .wr_ready(core_out_ready),
        .full(),
        .rd_clk(out_clk),
        .rd_rst_n(rst_n),
        .rd_en(out_ready && fifo_rd_valid),
        .rd_data(fifo_rd_data),
        .rd_valid(fifo_rd_valid),
        .empty()
    );

    assign out_valid = fifo_rd_valid;
    assign {out_eop, out_sop, out_data} = fifo_rd_data;

endmodule