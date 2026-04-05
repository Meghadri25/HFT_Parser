module cdc_pulse_sync (
    input  logic src_clk,
    input  logic src_rst_n,
    input  logic src_pulse,
    output logic src_ready,

    input  logic dst_clk,
    input  logic dst_rst_n,
    output logic dst_pulse
);

    logic src_toggle;
    logic dst_ack_toggle;
    logic dst_ack_sync1;
    logic dst_ack_sync2;

    logic dst_req_sync1;
    logic dst_req_sync2;
    logic dst_req_sync2_d;

    assign src_ready = (src_toggle == dst_ack_sync2);

    always_ff @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            src_toggle    <= 1'b0;
            dst_ack_sync1 <= 1'b0;
            dst_ack_sync2 <= 1'b0;
        end else begin
            dst_ack_sync1 <= dst_ack_toggle;
            dst_ack_sync2 <= dst_ack_sync1;

            if (src_pulse && src_ready) begin
                src_toggle <= ~src_toggle;
            end
        end
    end

    always_ff @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            dst_req_sync1   <= 1'b0;
            dst_req_sync2   <= 1'b0;
            dst_req_sync2_d <= 1'b0;
            dst_ack_toggle  <= 1'b0;
            dst_pulse       <= 1'b0;
        end else begin
            dst_req_sync1   <= src_toggle;
            dst_req_sync2   <= dst_req_sync1;
            dst_pulse       <= dst_req_sync2 ^ dst_req_sync2_d;
            dst_req_sync2_d <= dst_req_sync2;
            dst_ack_toggle  <= dst_req_sync2;
        end
    end

endmodule