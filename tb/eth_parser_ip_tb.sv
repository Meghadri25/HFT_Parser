`timescale 1ns/1ps

module eth_parser_ip_tb;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst_n = 1'b0;

    logic [31:0] s_axis_tdata;
    logic [3:0]  s_axis_tkeep;
    logic        s_axis_tvalid;
    logic        s_axis_tlast;
    logic        s_axis_tready;

    logic [31:0] m_axis_tdata;
    logic [3:0]  m_axis_tkeep;
    logic        m_axis_tvalid;
    logic        m_axis_tlast;

    logic        packet_valid;
    logic [31:0] src_ip_out;
    logic [31:0] dst_ip_out;
    logic [15:0] src_port_out;
    logic [15:0] dst_port_out;

    logic        packet_valid_seen;

    byte packet [0:63];
    integer i;

    // Packaged IP instance name in this project.
    eth_design_wrapper_0 uut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(1'b1),
        .m_axis_tlast(m_axis_tlast),
        .packet_valid(packet_valid),
        .src_ip_out(src_ip_out),
        .dst_ip_out(dst_ip_out),
        .src_port_out(src_port_out),
        .dst_port_out(dst_port_out)
    );

    task automatic drive_word(
        input logic [31:0] word_value,
        input logic [3:0]  keep_value,
        input logic        last_value
    );
        begin
            @(negedge clk);
            s_axis_tdata  = word_value;
            s_axis_tkeep  = keep_value;
            s_axis_tvalid = 1'b1;
            s_axis_tlast  = last_value;

            do begin
                @(posedge clk);
            end while (!s_axis_tready);

            #1;
            s_axis_tvalid = 1'b0;
            s_axis_tdata  = '0;
            s_axis_tkeep  = '0;
            s_axis_tlast  = 1'b0;
        end
    endtask

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            packet_valid_seen <= 1'b0;
        end else if (packet_valid) begin
            packet_valid_seen <= 1'b1;
        end
    end

    initial begin
        s_axis_tdata  = '0;
        s_axis_tkeep  = '0;
        s_axis_tvalid = 1'b0;
        s_axis_tlast  = 1'b0;
        packet_valid_seen = 1'b0;

        // Ethernet header
        packet[0]  = 8'hFF; packet[1]  = 8'hFF; packet[2]  = 8'hFF; packet[3]  = 8'hFF;
        packet[4]  = 8'hFF; packet[5]  = 8'hFF;
        packet[6]  = 8'h11; packet[7]  = 8'h22; packet[8]  = 8'h33; packet[9]  = 8'h44;
        packet[10] = 8'h55; packet[11] = 8'h66;
        packet[12] = 8'h08; packet[13] = 8'h00;

        // IPv4 header
        packet[14] = 8'h45; packet[15] = 8'h00;
        packet[16] = 8'h00; packet[17] = 8'h2C;
        packet[18] = 8'h00; packet[19] = 8'h00;
        packet[20] = 8'h00; packet[21] = 8'h00;
        packet[22] = 8'h40; packet[23] = 8'h11;
        packet[24] = 8'h00; packet[25] = 8'h00;

        // Src IP = 192.168.1.10
        packet[26] = 8'hC0; packet[27] = 8'hA8; packet[28] = 8'h01; packet[29] = 8'h0A;
        // Dst IP = 192.168.1.20
        packet[30] = 8'hC0; packet[31] = 8'hA8; packet[32] = 8'h01; packet[33] = 8'h14;

        // UDP header
        packet[34] = 8'h12; packet[35] = 8'h34;
        packet[36] = 8'h56; packet[37] = 8'h78;
        packet[38] = 8'h00; packet[39] = 8'h10;
        packet[40] = 8'h00; packet[41] = 8'h00;

        // Payload
        for (i = 42; i < 64; i = i + 1) begin
            packet[i] = i[7:0];
        end

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        for (i = 0; i < 64; i = i + 4) begin
            drive_word({packet[i+3], packet[i+2], packet[i+1], packet[i]}, 4'hF, (i == 60));
        end

        repeat (5) @(posedge clk);

        if (!packet_valid_seen) $fatal(1, "eth_parser packet_valid did not pulse");
        if (src_ip_out  !== 32'hC0A8010A) $fatal(1, "src_ip_out mismatch: %08h", src_ip_out);
        if (dst_ip_out  !== 32'hC0A80114) $fatal(1, "dst_ip_out mismatch: %08h", dst_ip_out);
        if (src_port_out !== 16'h1234)    $fatal(1, "src_port_out mismatch: %04h", src_port_out);
        if (dst_port_out !== 16'h5678)    $fatal(1, "dst_port_out mismatch: %04h", dst_port_out);

        $display("eth_parser_ip_tb PASSED");
        $finish;
    end

endmodule
