#!/usr/bin/env python3
"""Generate des_core.v from the standard DES tables (FIPS 46-3).

Generating rather than hand-typing removes transcription errors, which are
the dominant failure mode in a first DES implementation.
"""

IP = [58,50,42,34,26,18,10,2, 60,52,44,36,28,20,12,4,
      62,54,46,38,30,22,14,6, 64,56,48,40,32,24,16,8,
      57,49,41,33,25,17, 9,1, 59,51,43,35,27,19,11,3,
      61,53,45,37,29,21,13,5, 63,55,47,39,31,23,15,7]

FP = [40,8,48,16,56,24,64,32, 39,7,47,15,55,23,63,31,
      38,6,46,14,54,22,62,30, 37,5,45,13,53,21,61,29,
      36,4,44,12,52,20,60,28, 35,3,43,11,51,19,59,27,
      34,2,42,10,50,18,58,26, 33,1,41, 9,49,17,57,25]

E  = [32,1,2,3,4,5, 4,5,6,7,8,9, 8,9,10,11,12,13,
      12,13,14,15,16,17, 16,17,18,19,20,21,
      20,21,22,23,24,25, 24,25,26,27,28,29, 28,29,30,31,32,1]

P  = [16,7,20,21, 29,12,28,17, 1,15,23,26, 5,18,31,10,
      2,8,24,14, 32,27,3,9, 19,13,30,6, 22,11,4,25]

PC1 = [57,49,41,33,25,17,9, 1,58,50,42,34,26,18,
       10,2,59,51,43,35,27, 19,11,3,60,52,44,36,
       63,55,47,39,31,23,15, 7,62,54,46,38,30,22,
       14,6,61,53,45,37,29, 21,13,5,28,20,12,4]

PC2 = [14,17,11,24,1,5, 3,28,15,6,21,10, 23,19,12,4,26,8,
       16,7,27,20,13,2, 41,52,31,37,47,55, 30,40,51,45,33,48,
       44,49,39,56,34,53, 46,42,50,36,29,32]

SHIFTS = [1,1,2,2,2,2,2,2,1,2,2,2,2,2,2,1]

SBOX = [
 [[14,4,13,1,2,15,11,8,3,10,6,12,5,9,0,7],
  [0,15,7,4,14,2,13,1,10,6,12,11,9,5,3,8],
  [4,1,14,8,13,6,2,11,15,12,9,7,3,10,5,0],
  [15,12,8,2,4,9,1,7,5,11,3,14,10,0,6,13]],
 [[15,1,8,14,6,11,3,4,9,7,2,13,12,0,5,10],
  [3,13,4,7,15,2,8,14,12,0,1,10,6,9,11,5],
  [0,14,7,11,10,4,13,1,5,8,12,6,9,3,2,15],
  [13,8,10,1,3,15,4,2,11,6,7,12,0,5,14,9]],
 [[10,0,9,14,6,3,15,5,1,13,12,7,11,4,2,8],
  [13,7,0,9,3,4,6,10,2,8,5,14,12,11,15,1],
  [13,6,4,9,8,15,3,0,11,1,2,12,5,10,14,7],
  [1,10,13,0,6,9,8,7,4,15,14,3,11,5,2,12]],
 [[7,13,14,3,0,6,9,10,1,2,8,5,11,12,4,15],
  [13,8,11,5,6,15,0,3,4,7,2,12,1,10,14,9],
  [10,6,9,0,12,11,7,13,15,1,3,14,5,2,8,4],
  [3,15,0,6,10,1,13,8,9,4,5,11,12,7,2,14]],
 [[2,12,4,1,7,10,11,6,8,5,3,15,13,0,14,9],
  [14,11,2,12,4,7,13,1,5,0,15,10,3,9,8,6],
  [4,2,1,11,10,13,7,8,15,9,12,5,6,3,0,14],
  [11,8,12,7,1,14,2,13,6,15,0,9,10,4,5,3]],
 [[12,1,10,15,9,2,6,8,0,13,3,4,14,7,5,11],
  [10,15,4,2,7,12,9,5,6,1,13,14,0,11,3,8],
  [9,14,15,5,2,8,12,3,7,0,4,10,1,13,11,6],
  [4,3,2,12,9,5,15,10,11,14,1,7,6,0,8,13]],
 [[4,11,2,14,15,0,8,13,3,12,9,7,5,10,6,1],
  [13,0,11,7,4,9,1,10,14,3,5,12,2,15,8,6],
  [1,4,11,13,12,3,7,14,10,15,6,8,0,5,9,2],
  [6,11,13,8,1,4,10,7,9,5,0,15,14,2,3,12]],
 [[13,2,8,4,6,15,11,1,10,9,3,14,5,0,12,7],
  [1,15,13,8,10,3,7,4,12,5,6,11,0,14,9,2],
  [7,11,4,1,9,12,14,2,0,6,10,13,15,3,5,8],
  [2,1,14,7,4,10,8,13,15,12,9,0,3,5,6,11]],
]


def perm_fn(name, table, in_w):
    """Spec bit n (1-indexed, MSB first) maps to Verilog index in_w-n."""
    out_w = len(table)
    bits = ", ".join("x[%d]" % (in_w - n) for n in table)
    lines = []
    lines.append("    function [%d:0] %s;" % (out_w - 1, name))
    lines.append("        input [%d:0] x;" % (in_w - 1))
    # wrap the concatenation for readability
    parts, cur = [], "        %s = {" % name
    for i, n in enumerate(table):
        tok = "x[%d]" % (in_w - n)
        if i < len(table) - 1:
            tok += ", "
        if len(cur) + len(tok) > 96:
            parts.append(cur)
            cur = "            " + tok
        else:
            cur += tok
    parts.append(cur + "};")
    lines.extend(parts)
    lines.append("    endfunction")
    return "\n".join(lines)


def sbox_fn(idx, table):
    """6 bits in (spec order b1..b6): row = b1b6, col = b2b3b4b5."""
    lines = []
    lines.append("    function [3:0] s%d;" % (idx + 1))
    lines.append("        input [5:0] x;")
    lines.append("        reg [5:0] a;")
    lines.append("        begin")
    lines.append("            a = {x[5], x[0], x[4], x[3], x[2], x[1]};  // {row, col}")
    lines.append("            case (a)")
    for row in range(4):
        for col in range(16):
            addr = (row << 4) | col
            lines.append("                6'd%-2d: s%d = 4'd%d;" % (addr, idx + 1, table[row][col]))
    lines.append("                default: s%d = 4'd0;" % (idx + 1))
    lines.append("            endcase")
    lines.append("        end")
    lines.append("    endfunction")
    return "\n".join(lines)


out = []
out.append("""// des_core.v  -- iterative DES, one round per clock (16 cycles/block).
// Generated from the FIPS 46-3 tables. Supports encryption and decryption.
//
// Bit convention: the DES spec numbers bits 1..N starting at the MSB.
// In Verilog [N-1:0], spec bit n is index N-n. Every table below follows that.

module des_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,      // pulse high for one cycle to begin
    input  wire        decrypt,    // 0 = encrypt, 1 = decrypt
    input  wire [63:0] key_in,
    input  wire [63:0] data_in,
    output reg  [63:0] data_out,
    output reg         done,       // high for one cycle when data_out is valid
    output wire        busy
);

    // ---------------- permutation tables ----------------""")

out.append(perm_fn("ip",  IP,  64))
out.append(perm_fn("fp",  FP,  64))
out.append(perm_fn("ex",  E,   32))
out.append(perm_fn("pp",  P,   32))
out.append(perm_fn("pc1", PC1, 64))
out.append(perm_fn("pc2", PC2, 56))

out.append("\n    // ---------------- S-boxes ----------------")
for i, t in enumerate(SBOX):
    out.append(sbox_fn(i, t))

shift_bits = "".join(str(s - 1) for s in SHIFTS)  # 1->0, 2->1
out.append("""
    // ---------------- round function ----------------
    function [31:0] feistel;
        input [31:0] r;
        input [47:0] k;
        reg   [47:0] e_out;
        reg   [31:0] s_out;
        begin
            e_out = ex(r) ^ k;
            s_out = {s1(e_out[47:42]), s2(e_out[41:36]),
                     s3(e_out[35:30]), s4(e_out[29:24]),
                     s5(e_out[23:18]), s6(e_out[17:12]),
                     s7(e_out[11:6]),  s8(e_out[5:0])};
            feistel = pp(s_out);
        end
    endfunction

    // shift schedule: bit i = 1 means rotate by 2, 0 means rotate by 1
    localparam [15:0] SHIFT_SCHED = 16'b%s;

    reg [31:0] l, r;
    reg [27:0] c, d;
    reg [4:0]  round;
    reg        running;

    assign busy = running;

    wire       two       = SHIFT_SCHED[15 - round];
    // decryption consumes subkeys in reverse: rotate right, and round 0 does not rotate
    wire       dec_zero  = decrypt & (round == 5'd0);
    wire [4:0] dec_idx   = 5'd16 - round;
    wire       dec_two   = SHIFT_SCHED[15 - dec_idx[3:0]];

    reg [27:0] c_next, d_next;
    reg [47:0] subkey;
    reg [31:0] f_out;

    always @(*) begin
        if (!decrypt) begin
            c_next = two ? {c[25:0], c[27:26]} : {c[26:0], c[27]};
            d_next = two ? {d[25:0], d[27:26]} : {d[26:0], d[27]};
        end else if (dec_zero) begin
            c_next = c;
            d_next = d;
        end else begin
            c_next = dec_two ? {c[1:0], c[27:2]} : {c[0], c[27:1]};
            d_next = dec_two ? {d[1:0], d[27:2]} : {d[0], d[27:1]};
        end
        subkey = pc2({c_next, d_next});
        f_out  = feistel(r, subkey);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running  <= 1'b0;
            done     <= 1'b0;
            round    <= 5'd0;
            l        <= 32'd0;
            r        <= 32'd0;
            c        <= 28'd0;
            d        <= 28'd0;
            data_out <= 64'd0;
        end else begin
            done <= 1'b0;
            if (start && !running) begin
                {l, r}  <= ip(data_in);
                {c, d}  <= pc1(key_in);
                round   <= 5'd0;
                running <= 1'b1;
            end else if (running) begin
                l <= r;
                r <= l ^ f_out;
                c <= c_next;
                d <= d_next;
                if (round == 5'd15) begin
                    running  <= 1'b0;
                    done     <= 1'b1;
                    // round 16 does NOT swap: preoutput is {R16, L16}
                    data_out <= fp({(l ^ f_out), r});
                end else begin
                    round <= round + 5'd1;
                end
            end
        end
    end

endmodule
""" % shift_bits)

open("des_core.v", "w").write("\n".join(out))
print("wrote des_core.v")
