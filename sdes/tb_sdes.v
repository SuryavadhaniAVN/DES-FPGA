`timescale 1ns/1ps

module tb_sdes;

    localparam [9:0] KEY = 10'b1010000010;

    reg  [7:0] pt, ct_exp;
    wire [7:0] ct, rt;

    sdes enc (.data_in(pt), .key(KEY), .decrypt(1'b0), .data_out(ct));
    sdes dec (.data_in(ct), .key(KEY), .decrypt(1'b1), .data_out(rt));

    integer fd, code, i, errors, rt_errors;
    reg [7:0] v_pt, v_ct;

    initial begin
        errors = 0; rt_errors = 0;

        // 1. known-answer test from the literature
        pt = 8'b10010111; #1;
        if (ct !== 8'b00111000) begin
            $display("KAT FAIL: pt=10010111 expected 00111000 got %b", ct);
            errors = errors + 1;
        end else
            $display("KAT ok : pt=10010111 -> %b", ct);

        // 2. every one of the 256 plaintexts against the reference
        fd = $fopen("sdes_vectors.txt", "r");
        if (fd == 0) begin $display("cannot open sdes_vectors.txt"); $finish; end
        while (!$feof(fd)) begin
            code = $fscanf(fd, "%h %h\n", v_pt, v_ct);
            if (code == 2) begin
                pt = v_pt; #1;
                if (ct !== v_ct) begin
                    errors = errors + 1;
                    $display("ENC FAIL pt=%02h expected %02h got %02h", v_pt, v_ct, ct);
                end
                if (rt !== v_pt) begin
                    rt_errors = rt_errors + 1;
                    $display("RT  FAIL pt=%02h round-tripped to %02h", v_pt, rt);
                end
            end
        end
        $fclose(fd);

        $display("");
        $display("==================================================");
        $display("  key              : %b", KEY);
        $display("  encrypt mismatches : %0d / 256", errors);
        $display("  round-trip failures: %0d / 256", rt_errors);
        $display("  cycles per block   : 1 (combinational)");
        if (errors == 0 && rt_errors == 0) $display("  RESULT: ALL PASS");
        else                               $display("  RESULT: FAILED");
        $display("==================================================");
        $finish;
    end

endmodule
