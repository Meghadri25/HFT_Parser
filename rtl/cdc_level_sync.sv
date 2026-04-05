module cdc_level_sync #(
    parameter int STAGES = 2
) (
    input  logic src_level,
    input  logic dst_clk,
    input  logic dst_rst_n,
    output logic dst_level
);

    generate
        if (STAGES <= 1) begin : g_passthrough
            assign dst_level = src_level;
        end else begin : g_sync
            logic [STAGES-1:0] sync_r;

            always_ff @(posedge dst_clk or negedge dst_rst_n) begin
                if (!dst_rst_n) begin
                    sync_r <= '0;
                end else begin
                    sync_r <= {sync_r[STAGES-2:0], src_level};
                end
            end

            assign dst_level = sync_r[STAGES-1];
        end
    endgenerate

endmodule