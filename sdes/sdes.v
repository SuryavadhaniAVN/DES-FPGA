// sdes.v -- Simplified DES (Schaefer, 1996). Fully combinational: 1 cycle per block.
//
// Bit convention: the spec numbers bits 1..N starting at the MSB.
// In Verilog [N-1:0], spec bit n is index N-n. All tables below follow that.

module sdes (
    input  wire [7:0] data_in,
    input  wire [9:0] key,
    input  wire       decrypt,   // 0 = encrypt, 1 = decrypt
    output wire [7:0] data_out
);

    // ---- key schedule -------------------------------------------------
    // P10 = 3 5 2 7 4 10 1 9 8 6
    wire [9:0] p10 = {key[7], key[5], key[8], key[3], key[6],
                      key[0], key[9], key[1], key[2], key[4]};

    wire [4:0] l0 = p10[9:5];
    wire [4:0] r0 = p10[4:0];

    // LS-1
    wire [4:0] l1 = {l0[3:0], l0[4]};
    wire [4:0] r1 = {r0[3:0], r0[4]};
    // LS-2 applied to the LS-1 result (total shift 3)
    wire [4:0] l2 = {l1[2:0], l1[4:3]};
    wire [4:0] r2 = {r1[2:0], r1[4:3]};

    wire [9:0] kk1 = {l1, r1};
    wire [9:0] kk2 = {l2, r2};

    // P8 = 6 3 7 4 8 5 10 9
    wire [7:0] k1 = {kk1[4], kk1[7], kk1[3], kk1[6],
                     kk1[2], kk1[5], kk1[0], kk1[1]};
    wire [7:0] k2 = {kk2[4], kk2[7], kk2[3], kk2[6],
                     kk2[2], kk2[5], kk2[0], kk2[1]};

    // decryption uses the subkeys in the opposite order
    wire [7:0] ka = decrypt ? k2 : k1;
    wire [7:0] kb = decrypt ? k1 : k2;

    // ---- S-boxes ------------------------------------------------------
    // row = {b1, b4}, col = {b2, b3}
    function [1:0] s0;
        input [3:0] x;
        reg   [3:0] a;
        begin
            a = {x[3], x[0], x[2], x[1]};
            case (a)
                4'd0: s0=2'd1; 4'd1: s0=2'd0; 4'd2: s0=2'd3; 4'd3: s0=2'd2;
                4'd4: s0=2'd3; 4'd5: s0=2'd2; 4'd6: s0=2'd1; 4'd7: s0=2'd0;
                4'd8: s0=2'd0; 4'd9: s0=2'd2; 4'd10:s0=2'd1; 4'd11:s0=2'd3;
                4'd12:s0=2'd3; 4'd13:s0=2'd1; 4'd14:s0=2'd3; 4'd15:s0=2'd2;
            endcase
        end
    endfunction

    function [1:0] s1;
        input [3:0] x;
        reg   [3:0] a;
        begin
            a = {x[3], x[0], x[2], x[1]};
            case (a)
                4'd0: s1=2'd0; 4'd1: s1=2'd1; 4'd2: s1=2'd2; 4'd3: s1=2'd3;
                4'd4: s1=2'd2; 4'd5: s1=2'd0; 4'd6: s1=2'd1; 4'd7: s1=2'd3;
                4'd8: s1=2'd3; 4'd9: s1=2'd0; 4'd10:s1=2'd1; 4'd11:s1=2'd0;
                4'd12:s1=2'd2; 4'd13:s1=2'd1; 4'd14:s1=2'd0; 4'd15:s1=2'd3;
            endcase
        end
    endfunction

    // ---- round function ----------------------------------------------
    // EP = 4 1 2 3 2 3 4 1 ; P4 = 2 4 3 1
    function [3:0] ff;
        input [3:0] r;
        input [7:0] k;
        reg   [7:0] e;
        reg   [3:0] s;
        begin
            e = {r[0], r[3], r[2], r[1], r[2], r[1], r[0], r[3]} ^ k;
            s = {s0(e[7:4]), s1(e[3:0])};
            ff = {s[2], s[0], s[1], s[3]};
        end
    endfunction

    // ---- datapath ------------------------------------------------------
    // IP = 2 6 3 1 4 8 5 7
    wire [7:0] ip = {data_in[6], data_in[2], data_in[5], data_in[7],
                     data_in[4], data_in[0], data_in[3], data_in[1]};

    wire [3:0] a_l = ip[7:4];
    wire [3:0] a_r = ip[3:0];

    wire [3:0] b_l = a_l ^ ff(a_r, ka);     // fk with first subkey
    wire [3:0] b_r = a_r;

    wire [3:0] c_l = b_r;                   // SW
    wire [3:0] c_r = b_l;

    wire [3:0] d_l = c_l ^ ff(c_r, kb);     // fk with second subkey
    wire [3:0] d_r = c_r;

    wire [7:0] pre = {d_l, d_r};

    // IP^-1 = 4 1 3 5 7 2 8 6
    assign data_out = {pre[4], pre[7], pre[5], pre[3],
                       pre[1], pre[6], pre[0], pre[2]};

endmodule
