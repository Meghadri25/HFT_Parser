module tcp_receive_parser (
    input  logic        clk,
    input  logic        rst_n,

    input  logic [31:0] s_axis_tdata,
    input  logic [3:0]  s_axis_tkeep,
    input  logic        s_axis_tvalid,
    output logic        s_axis_tready,
    input  logic        s_axis_tlast,

    input  logic        eth_packet_valid,

    output logic [31:0] m_axis_tdata,
    output logic [3:0]  m_axis_tkeep,
    output logic        m_axis_tvalid,
    input  logic        m_axis_tready,
    output logic        m_axis_tlast,

    output logic        message_valid,
    output logic        message_error,
    output logic [15:0] message_length,

    output logic        pillar_msg_valid,
    output logic [2:0]  pillar_msg_type,
    output logic        pillar_side,
    output logic [7:0]  pillar_symbol_id,
    output logic [15:0] pillar_order_id,
    output logic [11:0] pillar_price_idx,
    output logic [15:0] pillar_sequence_num,
    output logic [31:0] pillar_quantity
);

    logic [15:0] ip_total_length;
    logic [7:0]  ip_protocol;
    logic [3:0]  ip_ihl;
    logic [3:0]  tcp_data_offset;
    logic [5:0]  byte_cnt;

    logic [7:0]  curr_byte;
    logic [5:0]  byte_cnt_next;
    logic [15:0] ip_total_length_next;
    logic [7:0]  ip_protocol_next;
    logic [3:0]  ip_ihl_next;
    logic [3:0]  tcp_data_offset_next;
    logic [6:0]  payload_start_idx;
    logic [6:0]  payload_start_idx_next;

    logic [95:0] s2p_msg_data;
    logic [3:0]  s2p_msg_bytes;
    logic [95:0] s2p_msg_data_next;
    logic [3:0]  s2p_msg_bytes_next;

    logic [95:0] stage1_msg;
    logic        stage1_valid;
    logic [95:0] stage2_msg;
    logic        stage2_valid;
    logic        stage1_frame_ok;
    logic        stage2_frame_ok;
    logic        capture_msg;
    logic        msg_type_ok;

    integer i;
    integer signed tcp_payload_calc;

    function automatic [7:0] get_byte(input logic [31:0] word, input int unsigned idx);
        case (idx)
            0: get_byte = word[7:0];
            1: get_byte = word[15:8];
            2: get_byte = word[23:16];
            default: get_byte = word[31:24];
        endcase
    endfunction

    assign msg_type_ok = (stage2_msg[2:0] == 3'b001) ||
                         (stage2_msg[2:0] == 3'b010) ||
                         (stage2_msg[2:0] == 3'b011);

    assign s_axis_tready = 1'b1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axis_tdata      <= '0;
            m_axis_tkeep      <= '0;
            m_axis_tvalid     <= 1'b0;
            m_axis_tlast      <= 1'b0;
            message_valid     <= 1'b0;
            message_error     <= 1'b0;
            message_length    <= '0;
            ip_total_length   <= '0;
            ip_protocol       <= '0;
            ip_ihl            <= '0;
            tcp_data_offset   <= '0;
            byte_cnt          <= '0;
            s2p_msg_data      <= '0;
            s2p_msg_bytes     <= '0;
            stage1_msg        <= '0;
            stage1_valid      <= 1'b0;
            stage2_msg        <= '0;
            stage2_valid      <= 1'b0;
            stage1_frame_ok   <= 1'b0;
            stage2_frame_ok   <= 1'b0;
            pillar_msg_valid  <= 1'b0;
            pillar_msg_type   <= '0;
            pillar_side       <= 1'b0;
            pillar_symbol_id  <= '0;
            pillar_order_id   <= '0;
            pillar_price_idx  <= '0;
            pillar_sequence_num <= '0;
            pillar_quantity   <= '0;
        end else begin
            message_valid <= 1'b0;
            pillar_msg_valid <= 1'b0;

            stage2_valid    <= stage1_valid;
            stage2_msg      <= stage1_msg;
            stage2_frame_ok <= stage1_frame_ok;
            stage1_valid    <= 1'b0;

            m_axis_tvalid <= s_axis_tvalid;
            m_axis_tdata  <= s_axis_tdata;
            m_axis_tkeep  <= s_axis_tkeep;
            m_axis_tlast  <= s_axis_tlast;

            if (s_axis_tvalid) begin
                byte_cnt_next        = byte_cnt;
                ip_total_length_next = ip_total_length;
                ip_protocol_next     = ip_protocol;
                ip_ihl_next          = ip_ihl;
                tcp_data_offset_next = tcp_data_offset;
                payload_start_idx    = 7'd14 + {1'b0, ip_ihl, 2'b00} + {1'b0, tcp_data_offset, 2'b00};
                payload_start_idx_next = payload_start_idx;

                s2p_msg_data_next  = s2p_msg_data;
                s2p_msg_bytes_next = s2p_msg_bytes;
                capture_msg        = 1'b0;

                for (i = 0; i < 4; i = i + 1) begin
                    if (s_axis_tkeep[i]) begin
                        curr_byte = get_byte(s_axis_tdata, i);
                        case (byte_cnt_next)
                            6'd14: ip_ihl_next[3:0]           = curr_byte[3:0];
                            6'd16: ip_total_length_next[15:8] = curr_byte;
                            6'd17: ip_total_length_next[7:0]  = curr_byte;
                            6'd23: ip_protocol_next            = curr_byte;
                            6'd46: tcp_data_offset_next       = curr_byte[7:4];
                            default: begin
                            end
                        endcase

                        payload_start_idx_next = 7'd14 + {1'b0, ip_ihl_next, 2'b00} + {1'b0, tcp_data_offset_next, 2'b00};
                        if (({1'b0, byte_cnt_next} >= payload_start_idx_next) && (s2p_msg_bytes_next < 4'd12)) begin
                            s2p_msg_data_next[(s2p_msg_bytes_next * 8) +: 8] = curr_byte;
                            if (s2p_msg_bytes_next == 4'd11) begin
                                capture_msg = 1'b1;
                            end
                            s2p_msg_bytes_next = s2p_msg_bytes_next + 4'd1;
                        end

                        byte_cnt_next = byte_cnt_next + 6'd1;
                    end
                end

                ip_total_length <= ip_total_length_next;
                ip_protocol     <= ip_protocol_next;
                ip_ihl          <= ip_ihl_next;
                tcp_data_offset <= tcp_data_offset_next;
                s2p_msg_data    <= s2p_msg_data_next;
                s2p_msg_bytes   <= s2p_msg_bytes_next;

                if (capture_msg) begin
                    stage1_msg      <= s2p_msg_data_next;
                    stage1_valid    <= 1'b1;
                    stage1_frame_ok <= (ip_protocol_next == 8'h06);
                end

                if (s_axis_tlast) begin
                    tcp_payload_calc = $signed({1'b0, ip_total_length_next}) -
                                       ($signed({1'b0, ip_ihl_next}) * 4) -
                                       ($signed({1'b0, tcp_data_offset_next}) * 4);

                    if (tcp_payload_calc >= 0) begin
                        message_length <= tcp_payload_calc[15:0];
                        message_error  <= 1'b0;
                        message_valid  <= (ip_protocol_next == 8'h06);
                    end else begin
                        message_length <= 16'd0;
                        message_error  <= 1'b1;
                        message_valid  <= 1'b0;
                    end

                    byte_cnt        <= '0;
                    ip_total_length <= '0;
                    ip_protocol     <= '0;
                    ip_ihl          <= '0;
                    tcp_data_offset <= '0;
                    s2p_msg_data    <= '0;
                    s2p_msg_bytes   <= '0;
                end else begin
                    byte_cnt <= byte_cnt_next;
                end
            end

            if (stage2_valid && stage2_frame_ok && msg_type_ok) begin
                pillar_msg_valid <= 1'b1;
                pillar_msg_type  <= stage2_msg[2:0];
                pillar_side      <= stage2_msg[3];
                pillar_symbol_id <= stage2_msg[15:8];
                pillar_order_id  <= stage2_msg[31:16];
                pillar_price_idx <= stage2_msg[43:32];
                pillar_sequence_num <= stage2_msg[63:48];
                pillar_quantity  <= stage2_msg[95:64];
            end
        end
    end

endmodule