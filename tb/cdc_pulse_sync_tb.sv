`timescale 1ns/1ps

module cdc_pulse_sync_tb;

    logic src_clk = 1'b0;
    logic dst_clk = 1'b0;
    always #3 src_clk = ~src_clk;
    always #5 dst_clk = ~dst_clk;

    logic rst_n;
    logic src_pulse;
    logic src_ready;
    logic dst_pulse;

    cdc_pulse_sync dut (
        .src_clk(src_clk),
        .src_rst_n(rst_n),
        .src_pulse(src_pulse),
        .src_ready(src_ready),
        .dst_clk(dst_clk),
        .dst_rst_n(rst_n),
        .dst_pulse(dst_pulse)
    );

    int pulse_count;

    task automatic send_pulse;
        begin
            @(negedge src_clk);
            src_pulse = 1'b1;
            @(posedge src_clk);
            #1;
            src_pulse = 1'b0;
        end
    endtask

    initial begin
        rst_n = 1'b0;
        src_pulse = 1'b0;
        pulse_count = 0;

        repeat (2) @(posedge src_clk);
        repeat (2) @(posedge dst_clk);
        rst_n = 1'b1;

        send_pulse();
        while (pulse_count < 1) begin
            @(posedge dst_clk);
            if (dst_pulse) pulse_count++;
        end

        send_pulse();
        while (pulse_count < 2) begin
            @(posedge dst_clk);
            if (dst_pulse) pulse_count++;
        end

        send_pulse();
        while (pulse_count < 3) begin
            @(posedge dst_clk);
            if (dst_pulse) pulse_count++;
        end

        repeat (3) @(posedge src_clk);
        if (!src_ready) $fatal(1, "src_ready should return high after acknowledgement");

        $display("cdc_pulse_sync_tb PASSED");
        $finish;
    end

endmodule