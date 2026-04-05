module async_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH = 16
) (
    input  logic                  wr_clk,
    input  logic                  wr_rst_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  wr_ready,
    output logic                  full,

    input  logic                  rd_clk,
    input  logic                  rd_rst_n,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  rd_valid,
    output logic                  empty
);

    localparam int ADDR_WIDTH = (DEPTH <= 2) ? 1 : $clog2(DEPTH);
    localparam int PTR_WIDTH = ADDR_WIDTH + 1;

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    logic [PTR_WIDTH-1:0] wr_bin;
    logic [PTR_WIDTH-1:0] wr_gray;
    logic [PTR_WIDTH-1:0] wr_gray_next;
    logic [PTR_WIDTH-1:0] rd_gray_sync1;
    logic [PTR_WIDTH-1:0] rd_gray_sync2;
    logic                 full_r;

    logic [PTR_WIDTH-1:0] rd_bin;
    logic [PTR_WIDTH-1:0] rd_gray;
    logic [PTR_WIDTH-1:0] rd_gray_next;
    logic [PTR_WIDTH-1:0] wr_gray_sync1;
    logic [PTR_WIDTH-1:0] wr_gray_sync2;
    logic                 empty_r;

    function automatic logic [PTR_WIDTH-1:0] bin2gray(input logic [PTR_WIDTH-1:0] value);
        return (value >> 1) ^ value;
    endfunction

    assign wr_ready = !full_r;
    assign full = full_r;
    assign rd_valid = !empty_r;
    assign empty = empty_r;
    assign rd_data = mem[rd_bin[ADDR_WIDTH-1:0]];

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_bin        <= '0;
            wr_gray       <= '0;
            rd_gray_sync1 <= '0;
            rd_gray_sync2 <= '0;
            full_r        <= 1'b0;
        end else begin
            rd_gray_sync1 <= rd_gray;
            rd_gray_sync2 <= rd_gray_sync1;

            wr_gray_next = bin2gray(wr_bin + ((wr_en && wr_ready) ? 1'b1 : 1'b0));

            if (wr_en && wr_ready) begin
                mem[wr_bin[ADDR_WIDTH-1:0]] <= wr_data;
                wr_bin <= wr_bin + 1'b1;
                wr_gray <= wr_gray_next;
            end

            full_r <= (wr_gray_next == {~rd_gray_sync2[PTR_WIDTH-1:PTR_WIDTH-2], rd_gray_sync2[PTR_WIDTH-3:0]});
        end
    end

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_bin        <= '0;
            rd_gray       <= '0;
            wr_gray_sync1 <= '0;
            wr_gray_sync2 <= '0;
            empty_r       <= 1'b1;
        end else begin
            wr_gray_sync1 <= wr_gray;
            wr_gray_sync2 <= wr_gray_sync1;

            rd_gray_next = bin2gray(rd_bin + ((rd_en && rd_valid) ? 1'b1 : 1'b0));

            if (rd_en && rd_valid) begin
                rd_bin  <= rd_bin + 1'b1;
                rd_gray <= rd_gray_next;
            end

            empty_r <= (wr_gray_sync2 == rd_gray_next);
        end
    end

endmodule