`timescale 1ns/1ps

module udp_receive_parser_tb;

    logic clk = 1'b0;
    always #5 clk = ~clk;

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

    logic       packet_valid;
    logic       packet_error;
    logic [15:0] src_port;
    logic [15:0] dst_port;
    logic [15:0] udp_length;
    logic [15:0] payload_length;

    udp_receive_parser dut (
        .clk(clk),
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
        .packet_valid(packet_valid),
        .packet_error(packet_error),
        .src_port(src_port),
        .dst_port(dst_port),
        .udp_length(udp_length),
        .payload_length(payload_length)
    );

    task automatic drive_byte(
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
            in_sop   = 1'b0;
            in_eop   = 1'b0;
            in_data  = '0;
            in_error = 1'b0;
        end
    endtask

    task automatic expect_no_output;
        begin
            if (out_valid) begin
                $fatal(1, "Unexpected output byte: %02h", out_data);
            end
        end
    endtask

    task automatic expect_payload_byte(
        input logic [7:0] expected_data,
        input logic expected_sop,
        input logic expected_eop
    );
        begin
            if (!out_valid) begin
                $fatal(1, "Expected payload byte %02h, but out_valid was low", expected_data);
            end
            if (out_data !== expected_data || out_sop !== expected_sop || out_eop !== expected_eop) begin
                $fatal(1, "Payload mismatch exp=%02h sop=%0b eop=%0b got=%02h sop=%0b eop=%0b",
                    expected_data, expected_sop, expected_eop, out_data, out_sop, out_eop);
            end
        end
    endtask

    initial begin
        in_valid = 1'b0;
        in_data  = '0;
        in_sop   = 1'b0;
        in_eop   = 1'b0;
        in_error = 1'b0;
        out_ready = 1'b1;
        rst_n    = 1'b0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        drive_byte(8'h12, 1'b1, 1'b0, 1'b0);
        expect_no_output();

        drive_byte(8'h34, 1'b0, 1'b0, 1'b0);
        expect_no_output();

        drive_byte(8'h56, 1'b0, 1'b0, 1'b0);
        expect_no_output();

        drive_byte(8'h78, 1'b0, 1'b0, 1'b0);
        expect_no_output();

        drive_byte(8'h00, 1'b0, 1'b0, 1'b0);
        expect_no_output();

        drive_byte(8'h0C, 1'b0, 1'b0, 1'b0);
        expect_no_output();

        drive_byte(8'h00, 1'b0, 1'b0, 1'b0);
        expect_no_output();

        drive_byte(8'h00, 1'b0, 1'b0, 1'b0);
        expect_no_output();

        drive_byte(8'hAA, 1'b0, 1'b0, 1'b0);
        expect_payload_byte(8'hAA, 1'b1, 1'b0);

        drive_byte(8'hBB, 1'b0, 1'b0, 1'b0);
        expect_payload_byte(8'hBB, 1'b0, 1'b0);

        drive_byte(8'hCC, 1'b0, 1'b1, 1'b0);
        expect_payload_byte(8'hCC, 1'b0, 1'b1);

        if (src_port !== 16'h1234) $fatal(1, "src_port mismatch: %04h", src_port);
        if (dst_port !== 16'h5678) $fatal(1, "dst_port mismatch: %04h", dst_port);
        if (udp_length !== 16'h000C) $fatal(1, "udp_length mismatch: %04h", udp_length);
        if (payload_length !== 16'h0004) $fatal(1, "payload_length mismatch: %04h", payload_length);
        if (!packet_valid) $fatal(1, "packet_valid did not pulse");
        if (packet_error) $fatal(1, "packet_error should be low for a valid packet");

        $display("udp_receive_parser_tb PASSED");
        $finish;
    end

endmodule