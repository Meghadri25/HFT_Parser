`timescale 1ns/1ps

module tcp_receive_parser_cdc_tb;

    logic in_clk = 1'b0;
    logic out_clk = 1'b0;
    always #3 in_clk = ~in_clk;
    always #5 out_clk = ~out_clk;

    logic rst_n;

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

    logic       message_valid;
    logic       message_error;
    logic [15:0] message_length;

    logic       message_valid_seen;

    tcp_receive_parser_cdc dut (
        .in_clk(in_clk),
        .out_clk(out_clk),
        .rst_n(rst_n),
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
        .message_valid(message_valid),
        .message_error(message_error),
        .message_length(message_length)
    );

    task automatic drive_byte(
        input logic [7:0] byte_value,
        input logic sop,
        input logic eop,
        input logic error_flag
    );
        begin
            @(negedge in_clk);
            in_valid = 1'b1;
            in_data  = byte_value;
            in_sop   = sop;
            in_eop   = eop;
            in_error = error_flag;
            @(posedge in_clk);
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
            out_ready = 1'b0;
            do begin
                @(posedge out_clk);
                #1;
            end while (!out_valid);

            if (out_data !== expected_data || out_sop !== expected_sop || out_eop !== expected_eop) begin
                $fatal(1, "Output mismatch exp=%02h sop=%0b eop=%0b got=%02h sop=%0b eop=%0b",
                    expected_data, expected_sop, expected_eop, out_data, out_sop, out_eop);
            end

            @(negedge out_clk);
            out_ready = 1'b1;
            @(posedge out_clk);
            #1;
            out_ready = 1'b0;
        end
    endtask

    always_ff @(posedge in_clk or negedge rst_n) begin
        if (!rst_n) begin
            message_valid_seen <= 1'b0;
        end else if (message_valid) begin
            message_valid_seen <= 1'b1;
        end
    end

    initial begin
        rst_n = 1'b0;
        in_valid = 1'b0;
        in_data  = '0;
        in_sop   = 1'b0;
        in_eop   = 1'b0;
        in_error = 1'b0;
        out_ready = 1'b0;
        message_valid_seen = 1'b0;

        repeat (3) @(posedge in_clk);
        repeat (2) @(posedge out_clk);
        rst_n = 1'b1;
        @(posedge in_clk);

        drive_byte(8'h00, 1'b1, 1'b0, 1'b0);
        drive_byte(8'h03, 1'b0, 1'b0, 1'b0);
        drive_byte(8'hD1, 1'b0, 1'b0, 1'b0);
        drive_byte(8'hE2, 1'b0, 1'b0, 1'b0);
        drive_byte(8'hF3, 1'b0, 1'b1, 1'b0);

        expect_output(8'hD1, 1'b1, 1'b0);
        expect_output(8'hE2, 1'b0, 1'b0);
        expect_output(8'hF3, 1'b0, 1'b1);

        if (message_length !== 16'd3) $fatal(1, "message_length mismatch: %0d", message_length);
        if (!message_valid_seen) $fatal(1, "message_valid did not pulse");
        if (message_error) $fatal(1, "message_error should be low for a valid message");

        $display("tcp_receive_parser_cdc_tb PASSED");
        $finish;
    end

endmodule