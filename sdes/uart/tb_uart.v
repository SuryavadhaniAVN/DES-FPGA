`timescale 1ns/1ps
module tb_uart;
    localparam CPB = 8;              // tiny for simulation speed
    reg clk = 0;
    reg rx = 1;
    wire tx, tx_oe, led, led_en, clk_en;
    sdes_uart_top #(.CLKS_PER_BIT(CPB)) uut (
        .clk(clk), .uart_rx_pin(rx), .uart_tx_pin(tx), .uart_tx_oe(tx_oe),
        .led(led), .led_en(led_en), .clk_en(clk_en));
    always #5 clk = ~clk;

    task send_byte(input [7:0] b);
        integer i;
        begin
            rx = 0; repeat (CPB) @(posedge clk);                    // start
            for (i = 0; i < 8; i = i + 1) begin
                rx = b[i]; repeat (CPB) @(posedge clk);
            end
            rx = 1; repeat (CPB) @(posedge clk);                    // stop
            repeat (CPB) @(posedge clk);
        end
    endtask

    reg [7:0] got;
    integer i;
    task recv_byte;
        begin
            @(negedge tx);                                          // start bit
            repeat (CPB + CPB/2) @(posedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                got[i] = tx; repeat (CPB) @(posedge clk);
            end
        end
    endtask

    task trial(input mode, input [7:0] blk, input [9:0] k, input [7:0] expect);
        begin
            fork
                begin
                    send_byte({7'd0, mode});
                    send_byte(blk);
                    send_byte({6'd0, k[9:8]});
                    send_byte(k[7:0]);
                end
                recv_byte();
            join
            if (got === expect)
                $display("  ok   mode=%b blk=%02h key=%03h -> %02h", mode, blk, k, got);
            else begin
                $display("  FAIL mode=%b blk=%02h key=%03h -> %02h (expected %02h)",
                         mode, blk, k, got, expect);
                errors = errors + 1;
            end
            repeat (CPB * 4) @(posedge clk);
        end
    endtask

    integer errors = 0;
    initial begin
        repeat (20) @(posedge clk);
        $display("");
        trial(1'b0, 8'h97, 10'h282, 8'h38);     // the published vector
        trial(1'b1, 8'h38, 10'h282, 8'h97);     // and back
        trial(1'b0, 8'hCC, 10'h1DD, 8'hE4);
        trial(1'b1, 8'hE4, 10'h1DD, 8'hCC);
        trial(1'b0, 8'h00, 10'h000, 8'hF0);
        $display("");
        $display("  failures: %0d", errors);
        $display("  RESULT: %s", errors == 0 ? "ALL PASS" : "FAILED");
        $display("");
        $finish;
    end
endmodule
