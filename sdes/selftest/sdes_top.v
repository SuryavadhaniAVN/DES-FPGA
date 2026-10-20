// sdes_top.v -- self-checking S-DES for the Vicharak Shrike Lite (SLG47910).
//
// The FPGA verifies S-DES entirely on its own:
//   1. a known-answer test from the literature
//      key = 1010000010, plaintext = 10010111 -> ciphertext = 00111000
//   2. an exhaustive sweep of all 256 plaintexts, encrypting then decrypting
//      each one and checking the result comes back equal to what went in
//
// LED blinks at about 1.5 Hz  -> every check passed
// LED stays off               -> something failed
//
// No microcontroller involvement beyond loading the bitstream.

(* top *)
module sdes_top #(
    parameter BLINK_BITS = 25       // testbench overrides this to keep sims short
) (
    (* iopad_external_pin, clkbuf_inhibit *) input  wire clk,
    (* iopad_external_pin *)                 output wire led,
    (* iopad_external_pin *)                 output wire led_en,
    (* iopad_external_pin *)                 output wire clk_en
);

    localparam [9:0] KEY    = 10'b1010000010;
    localparam [7:0] KAT_PT = 8'b10010111;
    localparam [7:0] KAT_CT = 8'b00111000;

    assign led_en = 1'b1;           // enable the output pad
    assign clk_en = 1'b1;           // enable the internal oscillator

    // ---- sweep counter ------------------------------------------------
    reg [7:0]            pt    = 8'd0;
    reg                  fail  = 1'b0;
    reg                  swept = 1'b0;
    reg [BLINK_BITS-1:0] div   = {BLINK_BITS{1'b0}};

    // ---- S-DES instances ----------------------------------------------
    wire [7:0] ct, rt, kat_ct;

    sdes u_enc (.data_in(pt),     .key(KEY), .decrypt(1'b0), .data_out(ct));
    sdes u_dec (.data_in(ct),     .key(KEY), .decrypt(1'b1), .data_out(rt));
    sdes u_kat (.data_in(KAT_PT), .key(KEY), .decrypt(1'b0), .data_out(kat_ct));

    wire kat_ok = (kat_ct == KAT_CT);

    // ---- checking -----------------------------------------------------
    always @(posedge clk) begin
        pt  <= pt + 8'd1;
        div <= div + 1'b1;

        if (rt != pt)
            fail <= 1'b1;           // sticky: one bad round-trip is fatal

        if (pt == 8'hFF)
            swept <= 1'b1;          // every plaintext has now been exercised
    end

    wire all_ok = swept & ~fail & kat_ok;

    assign led = all_ok & div[BLINK_BITS-1];

endmodule
