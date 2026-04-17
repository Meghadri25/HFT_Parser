`timescale 1ns/1ps

module udp_receive_parser_tb;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst_n;

    logic [31:0] s_axis_tdata;
    logic [3:0]  s_axis_tkeep;
    logic        s_axis_tvalid;
    logic        s_axis_tready;
    logic        s_axis_tlast;

    logic        eth_packet_valid;
    logic [15:0] eth_src_port;
    logic [15:0] eth_dst_port;

    logic [31:0] m_axis_tdata;
    logic [3:0]  m_axis_tkeep;
    logic        m_axis_tvalid;
    logic        m_axis_tready;
    logic        m_axis_tlast;

    logic       packet_valid;
    logic       packet_error;
    logic [15:0] src_port;
    logic [15:0] dst_port;
    logic [15:0] udp_length;
    logic [15:0] payload_length;
    logic        pillar_msg_valid;
    logic [2:0]  pillar_msg_type;
    logic        pillar_side;
    logic [7:0]  pillar_symbol_id;
    logic [15:0] pillar_order_id;
    logic [11:0] pillar_price_idx;
    logic [15:0] pillar_sequence_num;
    logic [31:0] pillar_quantity;
    logic        packet_valid_seen;
    logic        pillar_msg_valid_seen;

    udp_receive_parser dut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .eth_packet_valid(eth_packet_valid),
        .eth_src_port(eth_src_port),
        .eth_dst_port(eth_dst_port),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
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

    task automatic drive_word(
        input logic [31:0] word_value,
        input logic [3:0]  keep_value,
        input logic        last_value
    );
        begin
            @(negedge clk);
            s_axis_tvalid = 1'b1;
            s_axis_tdata  = word_value;
            s_axis_tkeep  = keep_value;
            s_axis_tlast  = last_value;

            do begin
                @(posedge clk);
            end while (!s_axis_tready);

            #1;
            s_axis_tvalid = 1'b0;
            s_axis_tdata  = '0;
            s_axis_tkeep  = '0;
            s_axis_tlast  = 1'b0;
        end
    endtask

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            packet_valid_seen <= 1'b0;
            pillar_msg_valid_seen <= 1'b0;
        end else begin
            if (packet_valid) begin
                packet_valid_seen <= 1'b1;
            end
            if (pillar_msg_valid) begin
                pillar_msg_valid_seen <= 1'b1;
            end
        end
    end

    initial begin
        s_axis_tvalid = 1'b0;
        s_axis_tdata  = '0;
        s_axis_tkeep  = '0;
        s_axis_tlast  = 1'b0;
        m_axis_tready = 1'b1;
        eth_packet_valid = 1'b1;
        eth_src_port = 16'h1234;
        eth_dst_port = 16'h5678;
        packet_valid_seen = 1'b0;
        pillar_msg_valid_seen = 1'b0;
        rst_n    = 1'b0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // Ethernet(14B) + IPv4(20B) + UDP(8B) + payload(12B) = 54B frame.
        drive_word(32'h00000000, 4'hF, 1'b0); // bytes 0-3
        drive_word(32'h00000000, 4'hF, 1'b0); // bytes 4-7
        drive_word(32'h00000000, 4'hF, 1'b0); // bytes 8-11
        drive_word(32'h45000000, 4'hF, 1'b0); // bytes 12-15, byte14 = 0x45
        drive_word(32'h00002800, 4'hF, 1'b0); // bytes 16-19, total_len=0x0028
        drive_word(32'h11000000, 4'hF, 1'b0); // bytes 20-23, protocol at byte23 is 0x11
        drive_word(32'h00000000, 4'hF, 1'b0); // bytes 24-27
        drive_word(32'h00000000, 4'hF, 1'b0); // bytes 28-31
        drive_word(32'h00000000, 4'hF, 1'b0); // bytes 32-35
        drive_word(32'h14000000, 4'hF, 1'b0); // bytes 36-39, udp_len=0x0014 at bytes 38-39
        drive_word(32'h33090000, 4'hF, 1'b0); // bytes 40-43, payload[0..1]=09,33
        drive_word(32'h05C3A1B2, 4'hF, 1'b0); // bytes 44-47, payload[2..5]
        drive_word(32'hF4A91234, 4'hF, 1'b0); // bytes 48-51, payload[6..9]
        drive_word(32'h00000001, 4'h3, 1'b1); // bytes 52-53, payload[10..11]

        repeat (3) @(posedge clk);
        #1;

        if (src_port !== 16'h1234) $fatal(1, "src_port mismatch: %04h", src_port);
        if (dst_port !== 16'h5678) $fatal(1, "dst_port mismatch: %04h", dst_port);
        if (udp_length !== 16'h0014) $fatal(1, "udp_length mismatch: %04h", udp_length);
        if (payload_length !== 16'h000C) $fatal(1, "payload_length mismatch: %04h", payload_length);
        if (!packet_valid_seen) $fatal(1, "packet_valid did not pulse");
        if (packet_error) $fatal(1, "packet_error should be low for a valid packet");
        if (!pillar_msg_valid_seen) $fatal(1, "pillar_msg_valid did not pulse");
        if (pillar_msg_type !== 3'b001) $fatal(1, "pillar_msg_type mismatch: %0d", pillar_msg_type);
        if (pillar_side !== 1'b1) $fatal(1, "pillar_side mismatch");
        if (pillar_symbol_id !== 8'h33) $fatal(1, "pillar_symbol_id mismatch: %02h", pillar_symbol_id);
        if (pillar_order_id !== 16'hA1B2) $fatal(1, "pillar_order_id mismatch: %04h", pillar_order_id);
        if (pillar_price_idx !== 12'h5C3) $fatal(1, "pillar_price_idx mismatch: %03h", pillar_price_idx);
        if (pillar_sequence_num !== 16'h1234) $fatal(1, "pillar_sequence_num mismatch: %04h", pillar_sequence_num);
        if (pillar_quantity !== 32'h0001F4A9) $fatal(1, "pillar_quantity mismatch: %08h", pillar_quantity);

        $display("udp_receive_parser_tb PASSED");
        $finish;
    end

endmodule