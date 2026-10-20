// des_core.v  -- iterative DES, one round per clock (16 cycles/block).
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

    // ---------------- permutation tables ----------------
    function [63:0] ip;
        input [63:0] x;
        ip = {x[6], x[14], x[22], x[30], x[38], x[46], x[54], x[62], x[4], x[12], x[20], x[28], 
            x[36], x[44], x[52], x[60], x[2], x[10], x[18], x[26], x[34], x[42], x[50], x[58], 
            x[0], x[8], x[16], x[24], x[32], x[40], x[48], x[56], x[7], x[15], x[23], x[31], 
            x[39], x[47], x[55], x[63], x[5], x[13], x[21], x[29], x[37], x[45], x[53], x[61], 
            x[3], x[11], x[19], x[27], x[35], x[43], x[51], x[59], x[1], x[9], x[17], x[25], 
            x[33], x[41], x[49], x[57]};
    endfunction
    function [63:0] fp;
        input [63:0] x;
        fp = {x[24], x[56], x[16], x[48], x[8], x[40], x[0], x[32], x[25], x[57], x[17], x[49], 
            x[9], x[41], x[1], x[33], x[26], x[58], x[18], x[50], x[10], x[42], x[2], x[34], 
            x[27], x[59], x[19], x[51], x[11], x[43], x[3], x[35], x[28], x[60], x[20], x[52], 
            x[12], x[44], x[4], x[36], x[29], x[61], x[21], x[53], x[13], x[45], x[5], x[37], 
            x[30], x[62], x[22], x[54], x[14], x[46], x[6], x[38], x[31], x[63], x[23], x[55], 
            x[15], x[47], x[7], x[39]};
    endfunction
    function [47:0] ex;
        input [31:0] x;
        ex = {x[0], x[31], x[30], x[29], x[28], x[27], x[28], x[27], x[26], x[25], x[24], 
            x[23], x[24], x[23], x[22], x[21], x[20], x[19], x[20], x[19], x[18], x[17], x[16], 
            x[15], x[16], x[15], x[14], x[13], x[12], x[11], x[12], x[11], x[10], x[9], x[8], 
            x[7], x[8], x[7], x[6], x[5], x[4], x[3], x[4], x[3], x[2], x[1], x[0], x[31]};
    endfunction
    function [31:0] pp;
        input [31:0] x;
        pp = {x[16], x[25], x[12], x[11], x[3], x[20], x[4], x[15], x[31], x[17], x[9], x[6], 
            x[27], x[14], x[1], x[22], x[30], x[24], x[8], x[18], x[0], x[5], x[29], x[23], 
            x[13], x[19], x[2], x[26], x[10], x[21], x[28], x[7]};
    endfunction
    function [55:0] pc1;
        input [63:0] x;
        pc1 = {x[7], x[15], x[23], x[31], x[39], x[47], x[55], x[63], x[6], x[14], x[22], 
            x[30], x[38], x[46], x[54], x[62], x[5], x[13], x[21], x[29], x[37], x[45], x[53], 
            x[61], x[4], x[12], x[20], x[28], x[1], x[9], x[17], x[25], x[33], x[41], x[49], 
            x[57], x[2], x[10], x[18], x[26], x[34], x[42], x[50], x[58], x[3], x[11], x[19], 
            x[27], x[35], x[43], x[51], x[59], x[36], x[44], x[52], x[60]};
    endfunction
    function [47:0] pc2;
        input [55:0] x;
        pc2 = {x[42], x[39], x[45], x[32], x[55], x[51], x[53], x[28], x[41], x[50], x[35], 
            x[46], x[33], x[37], x[44], x[52], x[30], x[48], x[40], x[49], x[29], x[36], x[43], 
            x[54], x[15], x[4], x[25], x[19], x[9], x[1], x[26], x[16], x[5], x[11], x[23], 
            x[8], x[12], x[7], x[17], x[0], x[22], x[3], x[10], x[14], x[6], x[20], x[27], x[24]};
    endfunction

    // ---------------- S-boxes ----------------
    function [3:0] s1;
        input [5:0] x;
        reg [5:0] a;
        begin
            a = {x[5], x[0], x[4], x[3], x[2], x[1]};  // {row, col}
            case (a)
                6'd0 : s1 = 4'd14;
                6'd1 : s1 = 4'd4;
                6'd2 : s1 = 4'd13;
                6'd3 : s1 = 4'd1;
                6'd4 : s1 = 4'd2;
                6'd5 : s1 = 4'd15;
                6'd6 : s1 = 4'd11;
                6'd7 : s1 = 4'd8;
                6'd8 : s1 = 4'd3;
                6'd9 : s1 = 4'd10;
                6'd10: s1 = 4'd6;
                6'd11: s1 = 4'd12;
                6'd12: s1 = 4'd5;
                6'd13: s1 = 4'd9;
                6'd14: s1 = 4'd0;
                6'd15: s1 = 4'd7;
                6'd16: s1 = 4'd0;
                6'd17: s1 = 4'd15;
                6'd18: s1 = 4'd7;
                6'd19: s1 = 4'd4;
                6'd20: s1 = 4'd14;
                6'd21: s1 = 4'd2;
                6'd22: s1 = 4'd13;
                6'd23: s1 = 4'd1;
                6'd24: s1 = 4'd10;
                6'd25: s1 = 4'd6;
                6'd26: s1 = 4'd12;
                6'd27: s1 = 4'd11;
                6'd28: s1 = 4'd9;
                6'd29: s1 = 4'd5;
                6'd30: s1 = 4'd3;
                6'd31: s1 = 4'd8;
                6'd32: s1 = 4'd4;
                6'd33: s1 = 4'd1;
                6'd34: s1 = 4'd14;
                6'd35: s1 = 4'd8;
                6'd36: s1 = 4'd13;
                6'd37: s1 = 4'd6;
                6'd38: s1 = 4'd2;
                6'd39: s1 = 4'd11;
                6'd40: s1 = 4'd15;
                6'd41: s1 = 4'd12;
                6'd42: s1 = 4'd9;
                6'd43: s1 = 4'd7;
                6'd44: s1 = 4'd3;
                6'd45: s1 = 4'd10;
                6'd46: s1 = 4'd5;
                6'd47: s1 = 4'd0;
                6'd48: s1 = 4'd15;
                6'd49: s1 = 4'd12;
                6'd50: s1 = 4'd8;
                6'd51: s1 = 4'd2;
                6'd52: s1 = 4'd4;
                6'd53: s1 = 4'd9;
                6'd54: s1 = 4'd1;
                6'd55: s1 = 4'd7;
                6'd56: s1 = 4'd5;
                6'd57: s1 = 4'd11;
                6'd58: s1 = 4'd3;
                6'd59: s1 = 4'd14;
                6'd60: s1 = 4'd10;
                6'd61: s1 = 4'd0;
                6'd62: s1 = 4'd6;
                6'd63: s1 = 4'd13;
                default: s1 = 4'd0;
            endcase
        end
    endfunction
    function [3:0] s2;
        input [5:0] x;
        reg [5:0] a;
        begin
            a = {x[5], x[0], x[4], x[3], x[2], x[1]};  // {row, col}
            case (a)
                6'd0 : s2 = 4'd15;
                6'd1 : s2 = 4'd1;
                6'd2 : s2 = 4'd8;
                6'd3 : s2 = 4'd14;
                6'd4 : s2 = 4'd6;
                6'd5 : s2 = 4'd11;
                6'd6 : s2 = 4'd3;
                6'd7 : s2 = 4'd4;
                6'd8 : s2 = 4'd9;
                6'd9 : s2 = 4'd7;
                6'd10: s2 = 4'd2;
                6'd11: s2 = 4'd13;
                6'd12: s2 = 4'd12;
                6'd13: s2 = 4'd0;
                6'd14: s2 = 4'd5;
                6'd15: s2 = 4'd10;
                6'd16: s2 = 4'd3;
                6'd17: s2 = 4'd13;
                6'd18: s2 = 4'd4;
                6'd19: s2 = 4'd7;
                6'd20: s2 = 4'd15;
                6'd21: s2 = 4'd2;
                6'd22: s2 = 4'd8;
                6'd23: s2 = 4'd14;
                6'd24: s2 = 4'd12;
                6'd25: s2 = 4'd0;
                6'd26: s2 = 4'd1;
                6'd27: s2 = 4'd10;
                6'd28: s2 = 4'd6;
                6'd29: s2 = 4'd9;
                6'd30: s2 = 4'd11;
                6'd31: s2 = 4'd5;
                6'd32: s2 = 4'd0;
                6'd33: s2 = 4'd14;
                6'd34: s2 = 4'd7;
                6'd35: s2 = 4'd11;
                6'd36: s2 = 4'd10;
                6'd37: s2 = 4'd4;
                6'd38: s2 = 4'd13;
                6'd39: s2 = 4'd1;
                6'd40: s2 = 4'd5;
                6'd41: s2 = 4'd8;
                6'd42: s2 = 4'd12;
                6'd43: s2 = 4'd6;
                6'd44: s2 = 4'd9;
                6'd45: s2 = 4'd3;
                6'd46: s2 = 4'd2;
                6'd47: s2 = 4'd15;
                6'd48: s2 = 4'd13;
                6'd49: s2 = 4'd8;
                6'd50: s2 = 4'd10;
                6'd51: s2 = 4'd1;
                6'd52: s2 = 4'd3;
                6'd53: s2 = 4'd15;
                6'd54: s2 = 4'd4;
                6'd55: s2 = 4'd2;
                6'd56: s2 = 4'd11;
                6'd57: s2 = 4'd6;
                6'd58: s2 = 4'd7;
                6'd59: s2 = 4'd12;
                6'd60: s2 = 4'd0;
                6'd61: s2 = 4'd5;
                6'd62: s2 = 4'd14;
                6'd63: s2 = 4'd9;
                default: s2 = 4'd0;
            endcase
        end
    endfunction
    function [3:0] s3;
        input [5:0] x;
        reg [5:0] a;
        begin
            a = {x[5], x[0], x[4], x[3], x[2], x[1]};  // {row, col}
            case (a)
                6'd0 : s3 = 4'd10;
                6'd1 : s3 = 4'd0;
                6'd2 : s3 = 4'd9;
                6'd3 : s3 = 4'd14;
                6'd4 : s3 = 4'd6;
                6'd5 : s3 = 4'd3;
                6'd6 : s3 = 4'd15;
                6'd7 : s3 = 4'd5;
                6'd8 : s3 = 4'd1;
                6'd9 : s3 = 4'd13;
                6'd10: s3 = 4'd12;
                6'd11: s3 = 4'd7;
                6'd12: s3 = 4'd11;
                6'd13: s3 = 4'd4;
                6'd14: s3 = 4'd2;
                6'd15: s3 = 4'd8;
                6'd16: s3 = 4'd13;
                6'd17: s3 = 4'd7;
                6'd18: s3 = 4'd0;
                6'd19: s3 = 4'd9;
                6'd20: s3 = 4'd3;
                6'd21: s3 = 4'd4;
                6'd22: s3 = 4'd6;
                6'd23: s3 = 4'd10;
                6'd24: s3 = 4'd2;
                6'd25: s3 = 4'd8;
                6'd26: s3 = 4'd5;
                6'd27: s3 = 4'd14;
                6'd28: s3 = 4'd12;
                6'd29: s3 = 4'd11;
                6'd30: s3 = 4'd15;
                6'd31: s3 = 4'd1;
                6'd32: s3 = 4'd13;
                6'd33: s3 = 4'd6;
                6'd34: s3 = 4'd4;
                6'd35: s3 = 4'd9;
                6'd36: s3 = 4'd8;
                6'd37: s3 = 4'd15;
                6'd38: s3 = 4'd3;
                6'd39: s3 = 4'd0;
                6'd40: s3 = 4'd11;
                6'd41: s3 = 4'd1;
                6'd42: s3 = 4'd2;
                6'd43: s3 = 4'd12;
                6'd44: s3 = 4'd5;
                6'd45: s3 = 4'd10;
                6'd46: s3 = 4'd14;
                6'd47: s3 = 4'd7;
                6'd48: s3 = 4'd1;
                6'd49: s3 = 4'd10;
                6'd50: s3 = 4'd13;
                6'd51: s3 = 4'd0;
                6'd52: s3 = 4'd6;
                6'd53: s3 = 4'd9;
                6'd54: s3 = 4'd8;
                6'd55: s3 = 4'd7;
                6'd56: s3 = 4'd4;
                6'd57: s3 = 4'd15;
                6'd58: s3 = 4'd14;
                6'd59: s3 = 4'd3;
                6'd60: s3 = 4'd11;
                6'd61: s3 = 4'd5;
                6'd62: s3 = 4'd2;
                6'd63: s3 = 4'd12;
                default: s3 = 4'd0;
            endcase
        end
    endfunction
    function [3:0] s4;
        input [5:0] x;
        reg [5:0] a;
        begin
            a = {x[5], x[0], x[4], x[3], x[2], x[1]};  // {row, col}
            case (a)
                6'd0 : s4 = 4'd7;
                6'd1 : s4 = 4'd13;
                6'd2 : s4 = 4'd14;
                6'd3 : s4 = 4'd3;
                6'd4 : s4 = 4'd0;
                6'd5 : s4 = 4'd6;
                6'd6 : s4 = 4'd9;
                6'd7 : s4 = 4'd10;
                6'd8 : s4 = 4'd1;
                6'd9 : s4 = 4'd2;
                6'd10: s4 = 4'd8;
                6'd11: s4 = 4'd5;
                6'd12: s4 = 4'd11;
                6'd13: s4 = 4'd12;
                6'd14: s4 = 4'd4;
                6'd15: s4 = 4'd15;
                6'd16: s4 = 4'd13;
                6'd17: s4 = 4'd8;
                6'd18: s4 = 4'd11;
                6'd19: s4 = 4'd5;
                6'd20: s4 = 4'd6;
                6'd21: s4 = 4'd15;
                6'd22: s4 = 4'd0;
                6'd23: s4 = 4'd3;
                6'd24: s4 = 4'd4;
                6'd25: s4 = 4'd7;
                6'd26: s4 = 4'd2;
                6'd27: s4 = 4'd12;
                6'd28: s4 = 4'd1;
                6'd29: s4 = 4'd10;
                6'd30: s4 = 4'd14;
                6'd31: s4 = 4'd9;
                6'd32: s4 = 4'd10;
                6'd33: s4 = 4'd6;
                6'd34: s4 = 4'd9;
                6'd35: s4 = 4'd0;
                6'd36: s4 = 4'd12;
                6'd37: s4 = 4'd11;
                6'd38: s4 = 4'd7;
                6'd39: s4 = 4'd13;
                6'd40: s4 = 4'd15;
                6'd41: s4 = 4'd1;
                6'd42: s4 = 4'd3;
                6'd43: s4 = 4'd14;
                6'd44: s4 = 4'd5;
                6'd45: s4 = 4'd2;
                6'd46: s4 = 4'd8;
                6'd47: s4 = 4'd4;
                6'd48: s4 = 4'd3;
                6'd49: s4 = 4'd15;
                6'd50: s4 = 4'd0;
                6'd51: s4 = 4'd6;
                6'd52: s4 = 4'd10;
                6'd53: s4 = 4'd1;
                6'd54: s4 = 4'd13;
                6'd55: s4 = 4'd8;
                6'd56: s4 = 4'd9;
                6'd57: s4 = 4'd4;
                6'd58: s4 = 4'd5;
                6'd59: s4 = 4'd11;
                6'd60: s4 = 4'd12;
                6'd61: s4 = 4'd7;
                6'd62: s4 = 4'd2;
                6'd63: s4 = 4'd14;
                default: s4 = 4'd0;
            endcase
        end
    endfunction
    function [3:0] s5;
        input [5:0] x;
        reg [5:0] a;
        begin
            a = {x[5], x[0], x[4], x[3], x[2], x[1]};  // {row, col}
            case (a)
                6'd0 : s5 = 4'd2;
                6'd1 : s5 = 4'd12;
                6'd2 : s5 = 4'd4;
                6'd3 : s5 = 4'd1;
                6'd4 : s5 = 4'd7;
                6'd5 : s5 = 4'd10;
                6'd6 : s5 = 4'd11;
                6'd7 : s5 = 4'd6;
                6'd8 : s5 = 4'd8;
                6'd9 : s5 = 4'd5;
                6'd10: s5 = 4'd3;
                6'd11: s5 = 4'd15;
                6'd12: s5 = 4'd13;
                6'd13: s5 = 4'd0;
                6'd14: s5 = 4'd14;
                6'd15: s5 = 4'd9;
                6'd16: s5 = 4'd14;
                6'd17: s5 = 4'd11;
                6'd18: s5 = 4'd2;
                6'd19: s5 = 4'd12;
                6'd20: s5 = 4'd4;
                6'd21: s5 = 4'd7;
                6'd22: s5 = 4'd13;
                6'd23: s5 = 4'd1;
                6'd24: s5 = 4'd5;
                6'd25: s5 = 4'd0;
                6'd26: s5 = 4'd15;
                6'd27: s5 = 4'd10;
                6'd28: s5 = 4'd3;
                6'd29: s5 = 4'd9;
                6'd30: s5 = 4'd8;
                6'd31: s5 = 4'd6;
                6'd32: s5 = 4'd4;
                6'd33: s5 = 4'd2;
                6'd34: s5 = 4'd1;
                6'd35: s5 = 4'd11;
                6'd36: s5 = 4'd10;
                6'd37: s5 = 4'd13;
                6'd38: s5 = 4'd7;
                6'd39: s5 = 4'd8;
                6'd40: s5 = 4'd15;
                6'd41: s5 = 4'd9;
                6'd42: s5 = 4'd12;
                6'd43: s5 = 4'd5;
                6'd44: s5 = 4'd6;
                6'd45: s5 = 4'd3;
                6'd46: s5 = 4'd0;
                6'd47: s5 = 4'd14;
                6'd48: s5 = 4'd11;
                6'd49: s5 = 4'd8;
                6'd50: s5 = 4'd12;
                6'd51: s5 = 4'd7;
                6'd52: s5 = 4'd1;
                6'd53: s5 = 4'd14;
                6'd54: s5 = 4'd2;
                6'd55: s5 = 4'd13;
                6'd56: s5 = 4'd6;
                6'd57: s5 = 4'd15;
                6'd58: s5 = 4'd0;
                6'd59: s5 = 4'd9;
                6'd60: s5 = 4'd10;
                6'd61: s5 = 4'd4;
                6'd62: s5 = 4'd5;
                6'd63: s5 = 4'd3;
                default: s5 = 4'd0;
            endcase
        end
    endfunction
    function [3:0] s6;
        input [5:0] x;
        reg [5:0] a;
        begin
            a = {x[5], x[0], x[4], x[3], x[2], x[1]};  // {row, col}
            case (a)
                6'd0 : s6 = 4'd12;
                6'd1 : s6 = 4'd1;
                6'd2 : s6 = 4'd10;
                6'd3 : s6 = 4'd15;
                6'd4 : s6 = 4'd9;
                6'd5 : s6 = 4'd2;
                6'd6 : s6 = 4'd6;
                6'd7 : s6 = 4'd8;
                6'd8 : s6 = 4'd0;
                6'd9 : s6 = 4'd13;
                6'd10: s6 = 4'd3;
                6'd11: s6 = 4'd4;
                6'd12: s6 = 4'd14;
                6'd13: s6 = 4'd7;
                6'd14: s6 = 4'd5;
                6'd15: s6 = 4'd11;
                6'd16: s6 = 4'd10;
                6'd17: s6 = 4'd15;
                6'd18: s6 = 4'd4;
                6'd19: s6 = 4'd2;
                6'd20: s6 = 4'd7;
                6'd21: s6 = 4'd12;
                6'd22: s6 = 4'd9;
                6'd23: s6 = 4'd5;
                6'd24: s6 = 4'd6;
                6'd25: s6 = 4'd1;
                6'd26: s6 = 4'd13;
                6'd27: s6 = 4'd14;
                6'd28: s6 = 4'd0;
                6'd29: s6 = 4'd11;
                6'd30: s6 = 4'd3;
                6'd31: s6 = 4'd8;
                6'd32: s6 = 4'd9;
                6'd33: s6 = 4'd14;
                6'd34: s6 = 4'd15;
                6'd35: s6 = 4'd5;
                6'd36: s6 = 4'd2;
                6'd37: s6 = 4'd8;
                6'd38: s6 = 4'd12;
                6'd39: s6 = 4'd3;
                6'd40: s6 = 4'd7;
                6'd41: s6 = 4'd0;
                6'd42: s6 = 4'd4;
                6'd43: s6 = 4'd10;
                6'd44: s6 = 4'd1;
                6'd45: s6 = 4'd13;
                6'd46: s6 = 4'd11;
                6'd47: s6 = 4'd6;
                6'd48: s6 = 4'd4;
                6'd49: s6 = 4'd3;
                6'd50: s6 = 4'd2;
                6'd51: s6 = 4'd12;
                6'd52: s6 = 4'd9;
                6'd53: s6 = 4'd5;
                6'd54: s6 = 4'd15;
                6'd55: s6 = 4'd10;
                6'd56: s6 = 4'd11;
                6'd57: s6 = 4'd14;
                6'd58: s6 = 4'd1;
                6'd59: s6 = 4'd7;
                6'd60: s6 = 4'd6;
                6'd61: s6 = 4'd0;
                6'd62: s6 = 4'd8;
                6'd63: s6 = 4'd13;
                default: s6 = 4'd0;
            endcase
        end
    endfunction
    function [3:0] s7;
        input [5:0] x;
        reg [5:0] a;
        begin
            a = {x[5], x[0], x[4], x[3], x[2], x[1]};  // {row, col}
            case (a)
                6'd0 : s7 = 4'd4;
                6'd1 : s7 = 4'd11;
                6'd2 : s7 = 4'd2;
                6'd3 : s7 = 4'd14;
                6'd4 : s7 = 4'd15;
                6'd5 : s7 = 4'd0;
                6'd6 : s7 = 4'd8;
                6'd7 : s7 = 4'd13;
                6'd8 : s7 = 4'd3;
                6'd9 : s7 = 4'd12;
                6'd10: s7 = 4'd9;
                6'd11: s7 = 4'd7;
                6'd12: s7 = 4'd5;
                6'd13: s7 = 4'd10;
                6'd14: s7 = 4'd6;
                6'd15: s7 = 4'd1;
                6'd16: s7 = 4'd13;
                6'd17: s7 = 4'd0;
                6'd18: s7 = 4'd11;
                6'd19: s7 = 4'd7;
                6'd20: s7 = 4'd4;
                6'd21: s7 = 4'd9;
                6'd22: s7 = 4'd1;
                6'd23: s7 = 4'd10;
                6'd24: s7 = 4'd14;
                6'd25: s7 = 4'd3;
                6'd26: s7 = 4'd5;
                6'd27: s7 = 4'd12;
                6'd28: s7 = 4'd2;
                6'd29: s7 = 4'd15;
                6'd30: s7 = 4'd8;
                6'd31: s7 = 4'd6;
                6'd32: s7 = 4'd1;
                6'd33: s7 = 4'd4;
                6'd34: s7 = 4'd11;
                6'd35: s7 = 4'd13;
                6'd36: s7 = 4'd12;
                6'd37: s7 = 4'd3;
                6'd38: s7 = 4'd7;
                6'd39: s7 = 4'd14;
                6'd40: s7 = 4'd10;
                6'd41: s7 = 4'd15;
                6'd42: s7 = 4'd6;
                6'd43: s7 = 4'd8;
                6'd44: s7 = 4'd0;
                6'd45: s7 = 4'd5;
                6'd46: s7 = 4'd9;
                6'd47: s7 = 4'd2;
                6'd48: s7 = 4'd6;
                6'd49: s7 = 4'd11;
                6'd50: s7 = 4'd13;
                6'd51: s7 = 4'd8;
                6'd52: s7 = 4'd1;
                6'd53: s7 = 4'd4;
                6'd54: s7 = 4'd10;
                6'd55: s7 = 4'd7;
                6'd56: s7 = 4'd9;
                6'd57: s7 = 4'd5;
                6'd58: s7 = 4'd0;
                6'd59: s7 = 4'd15;
                6'd60: s7 = 4'd14;
                6'd61: s7 = 4'd2;
                6'd62: s7 = 4'd3;
                6'd63: s7 = 4'd12;
                default: s7 = 4'd0;
            endcase
        end
    endfunction
    function [3:0] s8;
        input [5:0] x;
        reg [5:0] a;
        begin
            a = {x[5], x[0], x[4], x[3], x[2], x[1]};  // {row, col}
            case (a)
                6'd0 : s8 = 4'd13;
                6'd1 : s8 = 4'd2;
                6'd2 : s8 = 4'd8;
                6'd3 : s8 = 4'd4;
                6'd4 : s8 = 4'd6;
                6'd5 : s8 = 4'd15;
                6'd6 : s8 = 4'd11;
                6'd7 : s8 = 4'd1;
                6'd8 : s8 = 4'd10;
                6'd9 : s8 = 4'd9;
                6'd10: s8 = 4'd3;
                6'd11: s8 = 4'd14;
                6'd12: s8 = 4'd5;
                6'd13: s8 = 4'd0;
                6'd14: s8 = 4'd12;
                6'd15: s8 = 4'd7;
                6'd16: s8 = 4'd1;
                6'd17: s8 = 4'd15;
                6'd18: s8 = 4'd13;
                6'd19: s8 = 4'd8;
                6'd20: s8 = 4'd10;
                6'd21: s8 = 4'd3;
                6'd22: s8 = 4'd7;
                6'd23: s8 = 4'd4;
                6'd24: s8 = 4'd12;
                6'd25: s8 = 4'd5;
                6'd26: s8 = 4'd6;
                6'd27: s8 = 4'd11;
                6'd28: s8 = 4'd0;
                6'd29: s8 = 4'd14;
                6'd30: s8 = 4'd9;
                6'd31: s8 = 4'd2;
                6'd32: s8 = 4'd7;
                6'd33: s8 = 4'd11;
                6'd34: s8 = 4'd4;
                6'd35: s8 = 4'd1;
                6'd36: s8 = 4'd9;
                6'd37: s8 = 4'd12;
                6'd38: s8 = 4'd14;
                6'd39: s8 = 4'd2;
                6'd40: s8 = 4'd0;
                6'd41: s8 = 4'd6;
                6'd42: s8 = 4'd10;
                6'd43: s8 = 4'd13;
                6'd44: s8 = 4'd15;
                6'd45: s8 = 4'd3;
                6'd46: s8 = 4'd5;
                6'd47: s8 = 4'd8;
                6'd48: s8 = 4'd2;
                6'd49: s8 = 4'd1;
                6'd50: s8 = 4'd14;
                6'd51: s8 = 4'd7;
                6'd52: s8 = 4'd4;
                6'd53: s8 = 4'd10;
                6'd54: s8 = 4'd8;
                6'd55: s8 = 4'd13;
                6'd56: s8 = 4'd15;
                6'd57: s8 = 4'd12;
                6'd58: s8 = 4'd9;
                6'd59: s8 = 4'd0;
                6'd60: s8 = 4'd3;
                6'd61: s8 = 4'd5;
                6'd62: s8 = 4'd6;
                6'd63: s8 = 4'd11;
                default: s8 = 4'd0;
            endcase
        end
    endfunction

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
    localparam [15:0] SHIFT_SCHED = 16'b0011111101111110;

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
