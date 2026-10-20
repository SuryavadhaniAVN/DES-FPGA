// tb_des.v -- self-checking testbench for des_core.
// Reads vectors.txt (key pt ct, hex) and checks encrypt and decrypt both ways.

`timescale 1ns/1ps

module tb_des;

    reg         clk = 0;
    reg         rst_n = 0;
    reg         start = 0;
    reg         decrypt = 0;
    reg  [63:0] key_in, data_in;
    wire [63:0] data_out;
    wire        done, busy;

    integer errors = 0;
    integer tests  = 0;
    integer cycles_used;

    des_core uut (
        .clk(clk), .rst_n(rst_n), .start(start), .decrypt(decrypt),
        .key_in(key_in), .data_in(data_in),
        .data_out(data_out), .done(done), .busy(busy)
    );

    always #5 clk = ~clk;   // 100 MHz simulation clock

    // run one block through the core and count cycles from start to done
    task run_block;
        input [63:0] k;
        input [63:0] din;
        input        dec;
        output [63:0] dout;
        begin
            @(negedge clk);
            key_in  = k;
            data_in = din;
            decrypt = dec;
            start   = 1'b1;
            @(negedge clk);
            start   = 1'b0;
            cycles_used = 1;
            while (!done) begin
                @(negedge clk);
                cycles_used = cycles_used + 1;
            end
            dout = data_out;
        end
    endtask

    reg [63:0] k, pt, ct, got;
    integer    fd, code;

    initial begin
        $dumpfile("des.vcd");
        $dumpvars(0, tb_des);

        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        fd = $fopen("vectors.txt", "r");
        if (fd == 0) begin
            $display("ERROR: cannot open vectors.txt");
            $finish;
        end

        while (!$feof(fd)) begin
            code = $fscanf(fd, "%h %h %h\n", k, pt, ct);
            if (code == 3) begin
                // encryption
                run_block(k, pt, 1'b0, got);
                tests = tests + 1;
                if (got !== ct) begin
                    errors = errors + 1;
                    $display("ENC FAIL key=%h pt=%h  expected=%h got=%h", k, pt, ct, got);
                end else begin
                    $display("ENC ok   key=%h pt=%h -> %h   (%0d cycles)", k, pt, got, cycles_used);
                end

                // decryption must recover the plaintext
                run_block(k, ct, 1'b1, got);
                tests = tests + 1;
                if (got !== pt) begin
                    errors = errors + 1;
                    $display("DEC FAIL key=%h ct=%h  expected=%h got=%h", k, ct, pt, got);
                end
            end
        end
        $fclose(fd);

        $display("");
        $display("================================================");
        $display("  tests run : %0d", tests);
        $display("  failures  : %0d", errors);
        $display("  cycles/block : %0d", cycles_used);
        if (errors == 0) $display("  RESULT: ALL PASS");
        else             $display("  RESULT: FAILED");
        $display("================================================");
        $finish;
    end

endmodule
