`timescale 1ns/1ps

module async_fifo_tb;

    logic wr_clk = 1'b0;
    logic rd_clk = 1'b0;
    always #3 wr_clk = ~wr_clk;
    always #5 rd_clk = ~rd_clk;

    logic rst_n;
    logic wr_en;
    logic [7:0] wr_data;
    logic wr_ready;
    logic full;
    logic rd_en;
    logic [7:0] rd_data;
    logic rd_valid;
    logic empty;

    async_fifo #(
        .DATA_WIDTH(8),
        .DEPTH(8)
    ) dut (
        .wr_clk(wr_clk),
        .wr_rst_n(rst_n),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .wr_ready(wr_ready),
        .full(full),
        .rd_clk(rd_clk),
        .rd_rst_n(rst_n),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .rd_valid(rd_valid),
        .empty(empty)
    );

    int write_index;
    int read_index;
    logic [7:0] expected [0:5];

    initial begin
        expected[0] = 8'h11;
        expected[1] = 8'h22;
        expected[2] = 8'h33;
        expected[3] = 8'h44;
        expected[4] = 8'h55;
        expected[5] = 8'h66;
    end

    task automatic write_expected(input int index);
        begin
            @(negedge wr_clk);
            wr_data = expected[index];
            wr_en = 1'b1;
            @(posedge wr_clk);
            #1;
            wr_en = 1'b0;
        end
    endtask

    initial begin
        rst_n = 1'b0;
        wr_en = 1'b0;
        wr_data = '0;
        rd_en = 1'b1;
        write_index = 0;
        read_index = 0;

        repeat (3) @(posedge wr_clk);
        repeat (2) @(posedge rd_clk);
        rst_n = 1'b1;

        write_expected(0);
        write_expected(1);
        write_expected(2);
        write_expected(3);
        write_expected(4);
        write_expected(5);

        while (read_index < 6) begin
            @(posedge rd_clk);
            #1;
            if (rd_valid) begin
                if (rd_data !== expected[read_index]) begin
                    $fatal(1, "FIFO data mismatch at %0d: exp=%02h got=%02h", read_index, expected[read_index], rd_data);
                end
                read_index++;
            end
        end

        if (!empty) $fatal(1, "FIFO should be empty at the end");
        if (full) $fatal(1, "FIFO should not be full at the end");

        $display("async_fifo_tb PASSED");
        $finish;
    end

endmodule