module udp_receive_parser_cdc #(
    parameter int FIFO_DEPTH = 16
) (
    input  logic        in_clk,
    input  logic        out_clk,
    input  logic        rst_n,

    input  logic [31:0] s_axis_tdata,
    input  logic [3:0]  s_axis_tkeep,
    input  logic        s_axis_tvalid,
    output logic        s_axis_tready,
    input  logic        s_axis_tlast,

    input  logic        eth_packet_valid,
    input  logic [15:0] eth_src_port,
    input  logic [15:0] eth_dst_port,

    output logic [31:0] m_axis_tdata,
    output logic [3:0]  m_axis_tkeep,
    output logic        m_axis_tvalid,
    input  logic        m_axis_tready,
    output logic        m_axis_tlast,

    output logic        packet_valid,
    output logic        packet_error,
    output logic [15:0] src_port,
    output logic [15:0] dst_port,
    output logic [15:0] udp_length,
    output logic [15:0] payload_length,

    output logic        pillar_msg_valid,
    output logic [2:0]  pillar_msg_type,
    output logic        pillar_side,
    output logic [7:0]  pillar_symbol_id,
    output logic [15:0] pillar_order_id,
    output logic [11:0] pillar_price_idx,
    output logic [15:0] pillar_sequence_num,
    output logic [31:0] pillar_quantity
);

    logic [31:0] core_m_axis_tdata;
    logic [3:0]  core_m_axis_tkeep;
    logic        core_m_axis_tvalid;
    logic        core_m_axis_tready;
    logic        core_m_axis_tlast;

    logic        fifo_rd_valid;
    logic [36:0] fifo_rd_data;

    udp_receive_parser core (
        .clk(in_clk),
        .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .eth_packet_valid(eth_packet_valid),
        .eth_src_port(eth_src_port),
        .eth_dst_port(eth_dst_port),
        .m_axis_tdata(core_m_axis_tdata),
        .m_axis_tkeep(core_m_axis_tkeep),
        .m_axis_tvalid(core_m_axis_tvalid),
        .m_axis_tready(core_m_axis_tready),
        .m_axis_tlast(core_m_axis_tlast),
        .packet_valid(packet_valid),
        .packet_error(packet_error),
        .src_port(src_port),
        .dst_port(dst_port),
        .udp_length(udp_length),
        .payload_length(payload_length),
        .pillar_msg_valid(pillar_msg_valid),
        .pillar_msg_type(pillar_msg_type),
        .pillar_side(pillar_side),
        .pillar_symbol_id(pillar_symbol_id),
        .pillar_order_id(pillar_order_id),
        .pillar_price_idx(pillar_price_idx),
        .pillar_sequence_num(pillar_sequence_num),
        .pillar_quantity(pillar_quantity)
    );

    async_fifo #(
        .DATA_WIDTH(37),
        .DEPTH(FIFO_DEPTH)
    ) stream_fifo (
        .wr_clk(in_clk),
        .wr_rst_n(rst_n),
        .wr_en(core_m_axis_tvalid),
        .wr_data({core_m_axis_tlast, core_m_axis_tkeep, core_m_axis_tdata}),
        .wr_ready(core_m_axis_tready),
        .full(),
        .rd_clk(out_clk),
        .rd_rst_n(rst_n),
        .rd_en(m_axis_tready && fifo_rd_valid),
        .rd_data(fifo_rd_data),
        .rd_valid(fifo_rd_valid),
        .empty()
    );

    assign m_axis_tvalid = fifo_rd_valid;
    assign {m_axis_tlast, m_axis_tkeep, m_axis_tdata} = fifo_rd_data;

endmodule