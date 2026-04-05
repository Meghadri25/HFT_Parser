`timescale 1ns/1ps

module cdc_level_sync_tb;

    logic dst_clk = 1'b0;
    always #4 dst_clk = ~dst_clk;

    logic src_level;
    logic dst_level;
    logic rst_n;

    cdc_level_sync dut (
        .src_level(src_level),
        .dst_clk(dst_clk),
        .dst_rst_n(rst_n),
        .dst_level(dst_level)
    );

    initial begin
        rst_n = 1'b0;
        src_level = 1'b0;

        repeat (2) @(posedge dst_clk);
        rst_n = 1'b1;

        @(negedge dst_clk);
        src_level = 1'b1;
        repeat (4) @(posedge dst_clk);
        if (!dst_level) $fatal(1, "dst_level did not follow asserted source level");

        @(negedge dst_clk);
        src_level = 1'b0;
        repeat (4) @(posedge dst_clk);
        if (dst_level) $fatal(1, "dst_level did not return low");

        $display("cdc_level_sync_tb PASSED");
        $finish;
    end

endmodule