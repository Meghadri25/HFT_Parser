`timescale 1ns/1ps

module tcp_receive_parser_tb;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst_n;

    logic [31:0] s_axis_tdata;
    logic [3:0]  s_axis_tkeep;
    logic        s_axis_tvalid;
    logic        s_axis_tready;
    logic        s_axis_tlast;

    logic        eth_packet_valid;

    logic [31:0] m_axis_tdata;
    logic [3:0]  m_axis_tkeep;
    logic        m_axis_tvalid;
    logic        m_axis_tready;
    logic        m_axis_tlast;

    logic       message_valid;
    logic       message_error;
    logic [15:0] message_length;
    logic        pillar_msg_valid;
    logic [2:0]  pillar_msg_type;
    logic        pillar_side;
    logic [7:0]  pillar_symbol_id;
    logic [15:0] pillar_order_id;
    logic [11:0] pillar_price_idx;
    logic [15:0] pillar_sequence_num;
    logic [31:0] pillar_quantity;
    logic        message_valid_seen;
    logic        pillar_msg_valid_seen;

    tcp_receive_parser dut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .eth_packet_valid(eth_packet_valid),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        .message_valid(message_valid),
        .message_error(message_error),
        .message_length(message_length),
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
            message_valid_seen <= 1'b0;
            pillar_msg_valid_seen <= 1'b0;
        end else begin
            if (message_valid) begin
                message_valid_seen <= 1'b1;
            end
            if (pillar_msg_valid) begin
                pillar_msg_valid_seen <= 1'b1;
            end
        end
    end

    initial begin
        rst_n = 1'b0;
        s_axis_tvalid = 1'b0;
        s_axis_tdata  = '0;
        s_axis_tkeep  = '0;
        s_axis_tlast  = 1'b0;
        eth_packet_valid = 1'b1;
        m_axis_tready = 1'b1;
        message_valid_seen = 1'b0;
        pillar_msg_valid_seen = 1'b0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // Ethernet(14B) + IPv4(20B) + TCP(20B) + payload(12B) = 66B frame.
        drive_word(32'h00000000, 4'hF, 1'b0); // bytes 0-3
        drive_word(32'h00000000, 4'hF, 1'b0); // bytes 4-7
        drive_word(32'h00000000, 4'hF, 1'b0); // bytes 8-11
        drive_word(32'h45000000, 4'hF, 1'b0); // bytes 12-15, byte14 = 0x45
        drive_word(32'h00003400, 4'hF, 1'b0); // bytes 16-19, total_len=0x0034
        drive_word(32'h06000000, 4'hF, 1'b0); // bytes 20-23
        drive_word(32'h00000000, 4'hF, 1'b0); // bytes 24-27
        drive_word(32'h00000000, 4'hF, 1'b0); // bytes 28-31
        drive_word(32'h00000000, 4'hF, 1'b0); // bytes 32-35
        drive_word(32'h00000000, 4'hF, 1'b0); // bytes 36-39
        drive_word(32'h00000000, 4'hF, 1'b0); // bytes 40-43
        drive_word(32'h00500000, 4'hF, 1'b0); // bytes 44-47, data offset nibble at byte46 = 0x5
        drive_word(32'h00000000, 4'hF, 1'b0); // bytes 48-51
        drive_word(32'h33090000, 4'hF, 1'b0); // bytes 52-55, payload[0..1]=09,33
        drive_word(32'h05C3A1B2, 4'hF, 1'b0); // bytes 56-59, payload[2..5]
        drive_word(32'hF4A91234, 4'hF, 1'b0); // bytes 60-63, payload[6..9]
        drive_word(32'h00000001, 4'h3, 1'b1); // bytes 64-65, payload[10..11]

        repeat (3) @(posedge clk);
        #1;

        if (message_length !== 16'd12) $fatal(1, "message_length mismatch: %0d", message_length);
        if (!message_valid_seen) $fatal(1, "message_valid did not pulse");
        if (message_error) $fatal(1, "message_error should be low for a valid message");
        if (!pillar_msg_valid_seen) $fatal(1, "pillar_msg_valid did not pulse");
        if (pillar_msg_type !== 3'b001) $fatal(1, "pillar_msg_type mismatch: %0d", pillar_msg_type);
        if (pillar_side !== 1'b1) $fatal(1, "pillar_side mismatch");
        if (pillar_symbol_id !== 8'h33) $fatal(1, "pillar_symbol_id mismatch: %02h", pillar_symbol_id);
        if (pillar_order_id !== 16'hA1B2) $fatal(1, "pillar_order_id mismatch: %04h", pillar_order_id);
        if (pillar_price_idx !== 12'h5C3) $fatal(1, "pillar_price_idx mismatch: %03h", pillar_price_idx);
        if (pillar_sequence_num !== 16'h1234) $fatal(1, "pillar_sequence_num mismatch: %04h", pillar_sequence_num);
        if (pillar_quantity !== 32'h0001F4A9) $fatal(1, "pillar_quantity mismatch: %08h", pillar_quantity);

        $display("tcp_receive_parser_tb PASSED");
        $finish;
    end

endmodule