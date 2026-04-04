module tcp_send_framer (
    input  logic       clk,
    input  logic       rst_n,

    input  logic       start,
    input  logic [15:0] payload_length,
    output logic       busy,
    output logic       done,

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
    output logic       out_error
);

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_LEN_HI,
        ST_LEN_LO,
        ST_PAYLOAD
    } state_t;

    state_t state;

    logic [15:0] length_reg;
    logic [15:0] bytes_left;

    assign busy = (state != ST_IDLE);
    assign in_ready = (state == ST_PAYLOAD) && (!out_valid || out_ready);
    assign out_error = in_error;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= ST_IDLE;
            length_reg <= '0;
            bytes_left  <= '0;
            out_valid   <= 1'b0;
            out_data    <= '0;
            out_sop     <= 1'b0;
            out_eop     <= 1'b0;
            done        <= 1'b0;
        end else begin
            done <= 1'b0;

            if (out_valid && out_ready) begin
                out_valid <= 1'b0;
                out_sop   <= 1'b0;
                out_eop   <= 1'b0;
            end

            case (state)
                ST_IDLE: begin
                    if (start) begin
                        length_reg <= payload_length;
                        bytes_left  <= payload_length;
                        state       <= ST_LEN_HI;
                    end
                end

                ST_LEN_HI: begin
                    if (!out_valid || out_ready) begin
                        out_valid <= 1'b1;
                        out_data  <= length_reg[15:8];
                        out_sop   <= 1'b1;
                        out_eop   <= 1'b0;
                        state     <= ST_LEN_LO;
                    end
                end

                ST_LEN_LO: begin
                    if (!out_valid || out_ready) begin
                        out_valid <= 1'b1;
                        out_data  <= length_reg[7:0];
                        out_sop   <= 1'b0;
                        out_eop   <= (bytes_left == 16'd0);
                        state     <= (bytes_left == 16'd0) ? ST_IDLE : ST_PAYLOAD;
                        if (bytes_left == 16'd0) begin
                            done <= 1'b1;
                        end
                    end
                end

                ST_PAYLOAD: begin
                    if (in_valid && in_ready) begin
                        out_valid <= 1'b1;
                        out_data  <= in_data;
                        out_sop   <= 1'b0;
                        out_eop   <= (bytes_left == 16'd1) || in_eop;

                        if (bytes_left != 16'd0) begin
                            bytes_left <= bytes_left - 16'd1;
                        end

                        if ((bytes_left == 16'd1) || in_eop) begin
                            state <= ST_IDLE;
                            done  <= 1'b1;
                        end
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule