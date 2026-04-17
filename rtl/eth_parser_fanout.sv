module eth_parser_fanout (
    input  logic        clk,
    input  logic        rst_n,

    input  logic [31:0] s_axis_tdata,
    input  logic [3:0]  s_axis_tkeep,
    input  logic        s_axis_tvalid,
    output logic        s_axis_tready,
    input  logic        s_axis_tlast,

    output logic [31:0] udp_m_axis_tdata,
    output logic [3:0]  udp_m_axis_tkeep,
    output logic        udp_m_axis_tvalid,
    input  logic        udp_m_axis_tready,
    output logic        udp_m_axis_tlast,

    output logic [31:0] tcp_m_axis_tdata,
    output logic [3:0]  tcp_m_axis_tkeep,
    output logic        tcp_m_axis_tvalid,
    input  logic        tcp_m_axis_tready,
    output logic        tcp_m_axis_tlast,

    output logic        eth_packet_valid,
    output logic [31:0] eth_src_ip,
    output logic [31:0] eth_dst_ip,
    output logic [15:0] eth_src_port,
    output logic [15:0] eth_dst_port,

    output logic        udp_packet_valid,
    output logic        udp_packet_error,
    output logic [15:0] udp_src_port,
    output logic [15:0] udp_dst_port,
    output logic [15:0] udp_length,
    output logic [15:0] udp_payload_length,
    output logic        udp_pillar_msg_valid,
    output logic [2:0]  udp_pillar_msg_type,
    output logic        udp_pillar_side,
    output logic [7:0]  udp_pillar_symbol_id,
    output logic [15:0] udp_pillar_order_id,
    output logic [11:0] udp_pillar_price_idx,
    output logic [15:0] udp_pillar_sequence_num,
    output logic [31:0] udp_pillar_quantity,

    output logic        tcp_message_valid,
    output logic        tcp_message_error,
    output logic [15:0] tcp_message_length,
    output logic        tcp_pillar_msg_valid,
    output logic [2:0]  tcp_pillar_msg_type,
    output logic        tcp_pillar_side,
    output logic [7:0]  tcp_pillar_symbol_id,
    output logic [15:0] tcp_pillar_order_id,
    output logic [11:0] tcp_pillar_price_idx,
    output logic [15:0] tcp_pillar_sequence_num,
    output logic [31:0] tcp_pillar_quantity
);

    logic [31:0] eth_m_axis_tdata;
    logic [3:0]  eth_m_axis_tkeep;
    logic        eth_m_axis_tvalid;
    logic        eth_m_axis_tready;
    logic        eth_m_axis_tlast;

    logic        udp_s_axis_tready;
    logic        tcp_s_axis_tready;

    eth_design_wrapper_0 u_eth_parser (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(eth_m_axis_tdata),
        .m_axis_tkeep(eth_m_axis_tkeep),
        .m_axis_tvalid(eth_m_axis_tvalid),
        .m_axis_tready(eth_m_axis_tready),
        .m_axis_tlast(eth_m_axis_tlast),
        .packet_valid(eth_packet_valid),
        .src_ip_out(eth_src_ip),
        .dst_ip_out(eth_dst_ip),
        .src_port_out(eth_src_port),
        .dst_port_out(eth_dst_port)
    );

    udp_receive_parser u_udp_receive_parser (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(eth_m_axis_tdata),
        .s_axis_tkeep(eth_m_axis_tkeep),
        .s_axis_tvalid(eth_m_axis_tvalid),
        .s_axis_tready(udp_s_axis_tready),
        .s_axis_tlast(eth_m_axis_tlast),
        .eth_packet_valid(eth_packet_valid),
        .eth_src_port(eth_src_port),
        .eth_dst_port(eth_dst_port),
        .m_axis_tdata(udp_m_axis_tdata),
        .m_axis_tkeep(udp_m_axis_tkeep),
        .m_axis_tvalid(udp_m_axis_tvalid),
        .m_axis_tready(udp_m_axis_tready),
        .m_axis_tlast(udp_m_axis_tlast),
        .packet_valid(udp_packet_valid),
        .packet_error(udp_packet_error),
        .src_port(udp_src_port),
        .dst_port(udp_dst_port),
        .udp_length(udp_length),
        .payload_length(udp_payload_length),
        .pillar_msg_valid(udp_pillar_msg_valid),
        .pillar_msg_type(udp_pillar_msg_type),
        .pillar_side(udp_pillar_side),
        .pillar_symbol_id(udp_pillar_symbol_id),
        .pillar_order_id(udp_pillar_order_id),
        .pillar_price_idx(udp_pillar_price_idx),
        .pillar_sequence_num(udp_pillar_sequence_num),
        .pillar_quantity(udp_pillar_quantity)
    );

    tcp_receive_parser u_tcp_receive_parser (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(eth_m_axis_tdata),
        .s_axis_tkeep(eth_m_axis_tkeep),
        .s_axis_tvalid(eth_m_axis_tvalid),
        .s_axis_tready(tcp_s_axis_tready),
        .s_axis_tlast(eth_m_axis_tlast),
        .eth_packet_valid(eth_packet_valid),
        .m_axis_tdata(tcp_m_axis_tdata),
        .m_axis_tkeep(tcp_m_axis_tkeep),
        .m_axis_tvalid(tcp_m_axis_tvalid),
        .m_axis_tready(tcp_m_axis_tready),
        .m_axis_tlast(tcp_m_axis_tlast),
        .message_valid(tcp_message_valid),
        .message_error(tcp_message_error),
        .message_length(tcp_message_length),
        .pillar_msg_valid(tcp_pillar_msg_valid),
        .pillar_msg_type(tcp_pillar_msg_type),
        .pillar_side(tcp_pillar_side),
        .pillar_symbol_id(tcp_pillar_symbol_id),
        .pillar_order_id(tcp_pillar_order_id),
        .pillar_price_idx(tcp_pillar_price_idx),
        .pillar_sequence_num(tcp_pillar_sequence_num),
        .pillar_quantity(tcp_pillar_quantity)
    );

    // Both downstream parsers see the same stream; stall only if any leg stalls.
    assign eth_m_axis_tready = udp_s_axis_tready && tcp_s_axis_tready;

endmodule