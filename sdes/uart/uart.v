// uart.v -- 8N1 UART receiver and transmitter.
// CLKS_PER_BIT = clock frequency / baud rate. At 50 MHz and 115200 baud: 434.

module uart_rx #(
    parameter CLKS_PER_BIT = 434
) (
    input  wire       clk,
    input  wire       rx,
    output reg  [7:0] data  = 8'd0,
    output reg        valid = 1'b0      // high for one cycle when data is ready
);
    localparam IDLE = 2'd0, START = 2'd1, BITS = 2'd2, STOP = 2'd3;

    reg [1:0]  state = IDLE;
    reg [15:0] count = 16'd0;
    reg [2:0]  idx   = 3'd0;
    reg        rx_1  = 1'b1, rx_2 = 1'b1;   // two-stage synchroniser

    always @(posedge clk) begin
        rx_1 <= rx;
        rx_2 <= rx_1;
    end

    always @(posedge clk) begin
        valid <= 1'b0;
        case (state)
            IDLE: begin
                count <= 16'd0;
                idx   <= 3'd0;
                if (rx_2 == 1'b0) state <= START;       // falling edge = start bit
            end
            START: begin
                if (count == (CLKS_PER_BIT - 1) / 2) begin
                    if (rx_2 == 1'b0) begin             // still low at mid-bit
                        count <= 16'd0;
                        state <= BITS;
                    end else
                        state <= IDLE;                  // glitch, not a real start
                end else
                    count <= count + 16'd1;
            end
            BITS: begin
                if (count < CLKS_PER_BIT - 1)
                    count <= count + 16'd1;
                else begin
                    count     <= 16'd0;
                    data[idx] <= rx_2;                  // LSB first
                    if (idx == 3'd7) state <= STOP;
                    else             idx   <= idx + 3'd1;
                end
            end
            STOP: begin
                if (count < CLKS_PER_BIT - 1)
                    count <= count + 16'd1;
                else begin
                    valid <= 1'b1;
                    count <= 16'd0;
                    state <= IDLE;
                end
            end
        endcase
    end
endmodule


module uart_tx #(
    parameter CLKS_PER_BIT = 434
) (
    input  wire       clk,
    input  wire       send,              // pulse high for one cycle
    input  wire [7:0] data,
    output reg        tx   = 1'b1,
    output reg        busy = 1'b0
);
    localparam IDLE = 2'd0, START = 2'd1, BITS = 2'd2, STOP = 2'd3;

    reg [1:0]  state = IDLE;
    reg [15:0] count = 16'd0;
    reg [2:0]  idx   = 3'd0;
    reg [7:0]  shift = 8'd0;

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                tx    <= 1'b1;
                count <= 16'd0;
                idx   <= 3'd0;
                if (send) begin
                    shift <= data;
                    busy  <= 1'b1;
                    state <= START;
                end else
                    busy  <= 1'b0;
            end
            START: begin
                tx <= 1'b0;
                if (count < CLKS_PER_BIT - 1)
                    count <= count + 16'd1;
                else begin
                    count <= 16'd0;
                    state <= BITS;
                end
            end
            BITS: begin
                tx <= shift[idx];
                if (count < CLKS_PER_BIT - 1)
                    count <= count + 16'd1;
                else begin
                    count <= 16'd0;
                    if (idx == 3'd7) state <= STOP;
                    else             idx   <= idx + 3'd1;
                end
            end
            STOP: begin
                tx <= 1'b1;
                if (count < CLKS_PER_BIT - 1)
                    count <= count + 16'd1;
                else begin
                    count <= 16'd0;
                    busy  <= 1'b0;
                    state <= IDLE;
                end
            end
        endcase
    end
endmodule
