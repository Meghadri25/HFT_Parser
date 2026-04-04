module tcp_receive_parser (
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

    output logic       message_valid,
    output logic       message_error,
    output logic [15:0] message_length
);

    typedef enum logic [1:0] {
        ST_LEN_HI,
        ST_LEN_LO,
        ST_PAYLOAD
    } state_t;

    state_t state;

    logic [15:0] length_reg;
    logic [15:0] bytes_left;

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
            state          <= ST_LEN_HI;
            length_reg     <= '0;
            bytes_left     <= '0;
            out_valid_r    <= 1'b0;
            out_data_r     <= '0;
            out_sop_r      <= 1'b0;
            out_eop_r      <= 1'b0;
            message_valid  <= 1'b0;
            message_error  <= 1'b0;
            message_length <= '0;
        end else begin
            message_valid <= 1'b0;

            if (out_valid_r && out_ready) begin
                out_valid_r <= 1'b0;
                out_sop_r   <= 1'b0;
                out_eop_r   <= 1'b0;
            end

            if (in_valid && in_ready) begin
                case (state)
                    ST_LEN_HI: begin
                        length_reg[15:8] <= in_data;
                        message_error    <= in_error;
                        state            <= ST_LEN_LO;
                    end

                    ST_LEN_LO: begin
                        length_reg[7:0] <= in_data;
                        if ({length_reg[15:8], in_data} == 16'd0) begin
                            message_length <= 16'd0;
                            message_valid  <= !in_error;
                            state          <= ST_LEN_HI;
                        end else begin
                            bytes_left     <= {length_reg[15:8], in_data};
                            message_length <= {length_reg[15:8], in_data};
                            state          <= ST_PAYLOAD;
                        end
                    end

                    ST_PAYLOAD: begin
                        if (!out_valid_r || out_ready) begin
                            out_valid_r <= 1'b1;
                            out_data_r  <= in_data;
                            out_sop_r   <= (bytes_left == message_length);
                            out_eop_r   <= (bytes_left == 16'd1) || in_eop;
                        end

                        if (bytes_left != 16'd0) begin
                            bytes_left <= bytes_left - 16'd1;
                        end

                        if ((bytes_left == 16'd1) || in_eop) begin
                            message_valid <= !message_error && !in_error;
                            state         <= ST_LEN_HI;
                        end
                    end

                    default: begin
                        state <= ST_LEN_HI;
                    end
                endcase
            end
        end
    end

endmodule