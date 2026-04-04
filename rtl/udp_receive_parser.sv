module udp_receive_parser (
    input  logic       clk,
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

    output logic       packet_valid,
    output logic       packet_error,
    output logic [15:0] src_port,
    output logic [15:0] dst_port,
    output logic [15:0] udp_length,
    output logic [15:0] payload_length
);

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_HEADER,
        ST_PAYLOAD
    } state_t;

    state_t state;

    logic [2:0]  header_index;
    logic [15:0] captured_length;
    logic [15:0] payload_remaining;

    logic        out_valid_r;
    logic [7:0]  out_data_r;
    logic        out_sop_r;
    logic        out_eop_r;

    assign out_valid = out_valid_r;
    assign out_data  = out_data_r;
    assign out_sop   = out_sop_r;
    assign out_eop   = out_eop_r;

    assign in_ready = (state != ST_PAYLOAD) || !out_valid_r || out_ready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= ST_IDLE;
            header_index      <= '0;
            captured_length   <= '0;
            payload_remaining <= '0;
            src_port          <= '0;
            dst_port          <= '0;
            udp_length        <= '0;
            payload_length    <= '0;
            out_valid_r       <= 1'b0;
            out_data_r        <= '0;
            out_sop_r         <= 1'b0;
            out_eop_r         <= 1'b0;
            packet_valid      <= 1'b0;
            packet_error      <= 1'b0;
        end else begin
            packet_valid <= 1'b0;

            if (out_valid_r && out_ready) begin
                out_valid_r <= 1'b0;
                out_sop_r   <= 1'b0;
                out_eop_r   <= 1'b0;
            end

            if (in_valid && in_ready) begin
                case (state)
                    ST_IDLE: begin
                        src_port[15:8]    <= in_data;
                        header_index      <= 3'd1;
                        captured_length   <= '0;
                        payload_remaining <= '0;
                        packet_error      <= in_error;
                        state             <= ST_HEADER;
                    end

                    ST_HEADER: begin
                        case (header_index)
                            3'd0: src_port[15:8] <= in_data;
                            3'd1: src_port[7:0]  <= in_data;
                            3'd2: dst_port[15:8] <= in_data;
                            3'd3: dst_port[7:0]  <= in_data;
                            3'd4: begin
                                udp_length[15:8]     <= in_data;
                                captured_length[15:8] <= in_data;
                            end
                            3'd5: begin
                                udp_length[7:0]      <= in_data;
                                captured_length[7:0] <= in_data;
                            end
                            3'd6: begin
                            end
                            3'd7: begin
                            end
                            default: begin
                            end
                        endcase

                        if (header_index == 3'd7) begin
                            if (captured_length >= 16'd8) begin
                                payload_length    <= captured_length - 16'd8;
                                payload_remaining <= captured_length - 16'd8;
                                if ((captured_length - 16'd8) == 16'd0) begin
                                    packet_valid <= !packet_error;
                                    state        <= ST_IDLE;
                                end else begin
                                    state <= ST_PAYLOAD;
                                end
                            end else begin
                                payload_length    <= 16'd0;
                                payload_remaining <= 16'd0;
                                packet_error      <= 1'b1;
                                state             <= ST_IDLE;
                            end
                        end else begin
                            header_index <= header_index + 3'd1;
                        end
                    end

                    ST_PAYLOAD: begin
                        if (!out_valid_r || out_ready) begin
                            out_valid_r <= 1'b1;
                            out_data_r  <= in_data;
                            out_sop_r   <= (payload_remaining == payload_length);
                            out_eop_r   <= (payload_remaining == 16'd1) || in_eop;
                        end

                        if (payload_remaining != 16'd0) begin
                            payload_remaining <= payload_remaining - 16'd1;
                        end

                        if ((payload_remaining == 16'd1) || in_eop) begin
                            packet_valid <= !packet_error;
                            state        <= ST_IDLE;
                            header_index <= '0;
                        end
                    end

                    default: begin
                        state <= ST_IDLE;
                    end
                endcase
            end
        end
    end

endmodule