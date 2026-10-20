// sdes_uart_top.v -- interactive S-DES over UART on the Vicharak Shrike Lite.
//
// Wiring (from the Shrike FPGA/MCU interconnect table):
//   FPGA pin 18  <-  RP2040 GPIO14   host transmits, FPGA receives
//   FPGA pin 17  ->  RP2040 GPIO15   FPGA transmits, host receives
//
// Protocol: the host sends 4 bytes, the FPGA replies with 1.
//   byte 0  mode      0x00 = encrypt, anything else = decrypt
//   byte 1  plaintext or ciphertext, 8 bits
//   byte 2  key high  only the low 2 bits are used  -> key[9:8]
//   byte 3  key low                                 -> key[7:0]
//   reply   result, 8 bits
//
// 115200 baud, 8N1. The LED mirrors UART activity.

(* top *)
module sdes_uart_top #(
    parameter CLKS_PER_BIT = 434        // 50 MHz / 115200
) (
    (* iopad_external_pin, clkbuf_inhibit *) input  wire clk,
    (* iopad_external_pin *)                 input  wire uart_rx_pin,
    (* iopad_external_pin *)                 output wire uart_tx_pin,
    (* iopad_external_pin *)                 output wire uart_tx_oe,
    (* iopad_external_pin *)                 output wire led,
    (* iopad_external_pin *)                 output wire led_en,
    (* iopad_external_pin *)                 output wire clk_en
);

    assign clk_en     = 1'b1;
    assign led_en     = 1'b1;
    assign uart_tx_oe = 1'b1;

    // ---- UART ----------------------------------------------------------
    wire [7:0] rx_data;
    wire       rx_valid;
    reg        tx_send = 1'b0;
    reg  [7:0] tx_data = 8'd0;
    wire       tx_busy;

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
        .clk(clk), .rx(uart_rx_pin), .data(rx_data), .valid(rx_valid));

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
        .clk(clk), .send(tx_send), .data(tx_data),
        .tx(uart_tx_pin), .busy(tx_busy));

    // ---- byte collector ------------------------------------------------
    reg [1:0] byte_no = 2'd0;
    reg       mode    = 1'b0;
    reg [7:0] block   = 8'd0;
    reg [9:0] key     = 10'd0;

    wire [7:0] result;

    sdes u_sdes (.data_in(block), .key(key), .decrypt(mode), .data_out(result));

    always @(posedge clk) begin
        tx_send <= 1'b0;

        if (rx_valid) begin
            case (byte_no)
                2'd0: begin mode  <= |rx_data;        byte_no <= 2'd1; end
                2'd1: begin block <= rx_data;         byte_no <= 2'd2; end
                2'd2: begin key[9:8] <= rx_data[1:0]; byte_no <= 2'd3; end
                2'd3: begin
                    key[7:0] <= rx_data;
                    byte_no  <= 2'd0;
                end
            endcase
        end

        // one cycle after the last byte lands, the combinational core has
        // settled and the answer can go out
        if (byte_no == 2'd0 && !tx_busy && send_pending) begin
            tx_data <= result;
            tx_send <= 1'b1;
        end
    end

    reg send_pending = 1'b0;
    always @(posedge clk) begin
        if (rx_valid && byte_no == 2'd3) send_pending <= 1'b1;
        else if (tx_send)                send_pending <= 1'b0;
    end

    // ---- status LED ----------------------------------------------------
    reg [21:0] blip = 22'd0;
    always @(posedge clk) begin
        if (rx_valid) blip <= 22'h3FFFFF;
        else if (|blip) blip <= blip - 22'd1;
    end
    assign led = |blip;

endmodule
