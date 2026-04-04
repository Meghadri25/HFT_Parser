`timescale 1ns/1ps

module tcp_send_framer_tb;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst_n;

    logic        start;
    logic [15:0] payload_length;
    logic        busy;
    logic        done;

    logic       in_valid;
    logic       in_ready;
    logic [7:0] in_data;
    logic       in_sop;
    logic       in_eop;
    logic       in_error;

    logic       out_valid;
    logic       out_ready;
    logic [7:0] out_data;
    logic       out_sop;
    logic       out_eop;
    logic       out_error;

    tcp_send_framer dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .payload_length(payload_length),
        .busy(busy),
        .done(done),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .in_data(in_data),
        .in_sop(in_sop),
        .in_eop(in_eop),
        .in_error(in_error),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_data(out_data),
        .out_sop(out_sop),
        .out_eop(out_eop),
        .out_error(out_error)
    );

    task automatic pulse_start(input logic [15:0] length_value);
        begin
            @(negedge clk);
            payload_length = length_value;
            start = 1'b1;
            @(posedge clk);
            #1;
            start = 1'b0;
        end
    endtask

    task automatic send_payload_byte(
        input logic [7:0] byte_value,
        input logic sop,
        input logic eop,
        input logic error_flag
    );
        begin
            @(negedge clk);
            in_valid = 1'b1;
            in_data  = byte_value;
            in_sop   = sop;
            in_eop   = eop;
            in_error = error_flag;
            @(posedge clk);
            #1;
            in_valid = 1'b0;
            in_data  = '0;
            in_sop   = 1'b0;
            in_eop   = 1'b0;
            in_error = 1'b0;
        end
    endtask

    task automatic expect_output(input logic [7:0] expected_data, input logic expected_sop, input logic expected_eop);
        begin
            if (!out_valid) $fatal(1, "Expected output byte %02h", expected_data);
            if (out_data !== expected_data || out_sop !== expected_sop || out_eop !== expected_eop) begin
                $fatal(1, "Output mismatch exp=%02h sop=%0b eop=%0b got=%02h sop=%0b eop=%0b",
                    expected_data, expected_sop, expected_eop, out_data, out_sop, out_eop);
            end
        end
    endtask

    initial begin
        rst_n = 1'b0;
        start = 1'b0;
        payload_length = '0;
        in_valid = 1'b0;
        in_data  = '0;
        in_sop   = 1'b0;
        in_eop   = 1'b0;
        in_error = 1'b0;
        out_ready = 1'b1;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        pulse_start(16'd3);

        @(posedge clk);
        #1;
        expect_output(8'h00, 1'b1, 1'b0);

        @(posedge clk);
        #1;
        expect_output(8'h03, 1'b0, 1'b0);

        send_payload_byte(8'hA1, 1'b1, 1'b0, 1'b0);
        expect_output(8'hA1, 1'b0, 1'b0);

        send_payload_byte(8'hB2, 1'b0, 1'b0, 1'b0);
        expect_output(8'hB2, 1'b0, 1'b0);

        send_payload_byte(8'hC3, 1'b0, 1'b1, 1'b0);
        expect_output(8'hC3, 1'b0, 1'b1);

        if (!done) $fatal(1, "done did not pulse");
        if (busy) $fatal(1, "busy should be low after completion");
        if (out_error) $fatal(1, "out_error should track the input error flag, which is low here");

        $display("tcp_send_framer_tb PASSED");
        $finish;
    end

endmodule