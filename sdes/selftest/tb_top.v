`timescale 1ns/1ps
module tb_top;
    reg clk = 0;
    wire led, led_en, clk_en;
    sdes_top #(.BLINK_BITS(4)) uut (.clk(clk), .led(led), .led_en(led_en), .clk_en(clk_en));
    always #5 clk = ~clk;
    integer i; integer blinks = 0; reg prev = 0;
    initial begin
        repeat (300) @(posedge clk);          // let the 256-plaintext sweep finish
        $display("after sweep: swept=%b fail=%b kat_ok=%b", uut.swept, uut.fail, uut.kat_ok);
        for (i = 0; i < 200; i = i + 1) begin
            @(posedge clk);
            if (led && !prev) blinks = blinks + 1;
            prev = led;
        end
        $display("led_en=%b clk_en=%b  rising edges on led: %0d", led_en, clk_en, blinks);
        if (uut.swept && !uut.fail && uut.kat_ok && blinks > 0)
            $display("RESULT: PASS -- LED will blink on hardware");
        else
            $display("RESULT: FAIL");
        $finish;
    end
endmodule
