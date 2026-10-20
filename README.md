# DES-FPGA

DES and Simplified DES (S-DES) written in Verilog. The S-DES core runs on a Vicharak Shrike Lite board, which pairs a Renesas SLG47910 ForgeFPGA with an RP2040. The full DES core passes simulation against reference vectors but I haven't fitted it to the FPGA yet.

There are two S-DES builds for the board. One checks itself on power-up and blinks an LED if everything is right. The other takes a block and key over UART from the RP2040, so you can type values into the Arduino Serial Monitor and get the result back from the FPGA.

## Layout

```
des/
  des_core.v        iterative DES, one round per clock
  tb_des.v          self-checking testbench
  vectors.txt       12 key/plaintext/ciphertext vectors
  gen_des_v.py      generates des_core.v from the FIPS 46-3 tables
  gen_vectors.py    generates vectors.txt using pycryptodome
sdes/
  sdes.v            combinational S-DES, encrypt and decrypt
  tb_sdes.v         checks all 256 plaintexts and the known-answer test
  sdes_ref.py       Python reference, writes sdes_vectors.txt
  sdes_vectors.txt  256 plaintext/ciphertext pairs for key 1010000010
  selftest/         top level that tests itself and drives the LED
  uart/             top level with a UART, plus its testbench
firmware/
  sdes_flash/       RP2040 sketch that loads the bitstream (self-test build)
  sdes_console/     RP2040 sketch that loads the bitstream and runs the console
sim.sh              runs every testbench
```

## Simulation

You need Icarus Verilog. I used version 11.0.

```bash
sudo apt install iverilog
./sim.sh
```

All four testbenches should report `ALL PASS` or `PASS`:

- DES: 24 tests (12 encryptions, 12 decryptions), 0 failures, 17 cycles per block
- S-DES core: 0 of 256 encrypt mismatches, 0 of 256 round-trip failures
- Self-test top: sweep finishes with no failures and the LED toggles
- UART top: 5 trials over real serial frames, 0 failures

Each testbench checks the outputs itself, so you don't have to read waveforms. The DES testbench also writes `des/des.vcd` if you want to look at one in GTKWave.

## DES core

`des_core.v` processes one Feistel round per clock. A block takes 17 cycles: one to load and 16 rounds. Pulse `start` with `key_in`, `data_in` and `decrypt` set, then wait for `done`.

| Port | Width | Notes |
| --- | --- | --- |
| `clk`, `rst_n` | 1 | reset is asynchronous, active low |
| `start` | 1 | one-cycle pulse, ignored while `busy` |
| `decrypt` | 1 | 0 encrypts, 1 decrypts |
| `key_in` | 64 | parity bits are ignored, as PC-1 drops them |
| `data_in` | 64 | |
| `data_out` | 64 | valid when `done` is high |
| `done` | 1 | high for one cycle |
| `busy` | 1 | high while rounds are running |

Some details that took a while to get right:

- **Bit numbering.** The DES spec numbers bits 1 to N from the most significant end. In a Verilog `[N-1:0]` vector, spec bit n is index N-n. I generate the permutation and S-box code with `gen_des_v.py` rather than typing the tables in, because a single misplaced index breaks everything and is hard to spot.
- **No swap after round 16.** The output before the final permutation is `{R16, L16}`, not `{L16, R16}`.
- **Subkeys are made on the fly.** Storing all sixteen 48-bit subkeys would take 768 flip-flops. Instead the key halves C and D rotate each round and the subkey comes straight out of PC-2. For decryption they rotate right instead of left and round 0 doesn't rotate. The left rotations over 16 rounds add up to 28, the full width of each half, so starting from the PC-1 output and rotating right lands on the same subkeys in reverse order.

A quick sanity check: key `133457799BBCDFF1` with plaintext `0123456789ABCDEF` must give `85E813540F0AB405`. The other vectors come from pycryptodome, an implementation separate from mine. To regenerate them:

```bash
pip install pycryptodome
cd des && python3 gen_vectors.py > vectors.txt
```

## S-DES core

S-DES is the teaching version of DES from Schaefer (1996): an 8-bit block, a 10-bit key and two rounds. `sdes.v` is purely combinational, so it produces one block per clock. All the permutations (P10, P8, IP, IP⁻¹, EP, P4) are just wire reordering and cost no logic. Only the S-boxes and the XORs use LUTs. Decryption is the same circuit with the two subkeys swapped.

`sdes_ref.py` is a separate Python implementation that I wrote straight from the paper's tables. It writes `sdes_vectors.txt`, which the testbench checks against. Known answer: key `1010000010` with plaintext `10010111` gives `00111000`.

### Self-test build

`selftest/sdes_top.v` needs nothing from the RP2040 once the bitstream is loaded. After power-up it:

1. encrypts the known-answer plaintext and compares it with `00111000`
2. steps through all 256 plaintexts, encrypting and then decrypting each one, and checks it gets back what it started with (256 clocks, about 5 µs at 50 MHz)

If both pass, the LED on GPIO16 blinks at about 1.5 Hz. If anything fails it stays off.

### UART build

`uart/sdes_uart_top.v` adds an 8N1 UART running at 115200 baud. FPGA pins 17 and 18 are already wired to RP2040 GPIO15 and GPIO14 on the board, so no extra wiring is needed.

| FPGA pin | RP2040 pin | Direction |
| --- | --- | --- |
| 18 | GPIO14 | RP2040 to FPGA |
| 17 | GPIO15 | FPGA to RP2040 |

The RP2040 sends four bytes and the FPGA replies with one:

| Byte | Contents |
| --- | --- |
| 0 | mode: `0x00` encrypts, anything else decrypts |
| 1 | the 8-bit block |
| 2 | key bits 9 and 8, in the low two bits |
| 3 | key bits 7 to 0 |
| reply | the 8-bit result |

GPIO14 and GPIO15 aren't hardware UART pins on the RP2040, so `sdes_console.ino` uses `SerialPIO` from the arduino-pico core. The LED blinks briefly whenever a byte arrives.

At 50 MHz, `CLKS_PER_BIT` is 434. If you clock the design at a different frequency, recalculate it as clock / 115200.

## Building a bitstream

The bitstreams are not in the repo. Build them with Renesas Go Configure Software Hub.

1. Start from the `examples/led_blink` project in [vicharak-in/shrike](https://github.com/vicharak-in/shrike), which already has the oscillator and GPIO16 set up.
2. Replace its Verilog with the files for the build you want, joined into one file:
   ```bash
   cd sdes
   cat sdes.v selftest/sdes_top.v > combined.v                  # self-test
   cat sdes.v uart/uart.v uart/sdes_uart_top.v > combined.v     # UART
   ```
3. Map the signals in the I/O Planner:

   | Signal | Self-test | UART |
   | --- | --- | --- |
   | `clk` | OSC_CLK | OSC_CLK |
   | `clk_en` | OSC_EN | OSC_EN |
   | `led` | GPIO16_OUT | GPIO16_OUT |
   | `led_en` | GPIO16_OE | GPIO16_OE |
   | `uart_rx_pin` | | GPIO18_IN |
   | `uart_tx_pin` | | GPIO17_OUT |
   | `uart_tx_oe` | | GPIO17_OE |

   `uart_rx_pin` goes to GPIO18_**IN**. Mapping it to an output is an easy mistake, and when it happens the FPGA never replies.
4. Synthesize and generate the bitstream. The file you want is `ffpga/build/bitstream/FPGA_bitstream_MCU.bin`. None of the other files in that folder will load.

If you write your own top level for the ForgeFPGA, it needs:

- `(* top *)` on the module
- `(* iopad_external_pin, clkbuf_inhibit *)` on the clock and `(* iopad_external_pin *)` on every other port
- a `clk_en` output tied high, or the internal oscillator never starts
- an output-enable signal for every output pin
- no `inout` ports

## Flashing the board

The RP2040 loads the bitstream into the FPGA at boot, from a file in its LittleFS filesystem.

Setup in Arduino IDE 2.x:

- the arduino-pico board package (Earle Philhower's), board **Generic RP2040**
- the `Shrike` library from [vicharak-in/shrike_flash](https://github.com/vicharak-in/shrike_flash)
- the [arduino-littlefs-upload](https://github.com/earlephilhower/arduino-littlefs-upload) plugin
- **Tools → Flash Size: 4MB (Sketch: 2MB, FS: 2MB).** Use the same setting for both the sketch upload and the filesystem upload.

Then:

1. Copy `FPGA_bitstream_MCU.bin` into the sketch's folder as `data/sdes.bin`. Use `firmware/sdes_flash` for the self-test build and `firmware/sdes_console` for the UART build.
2. Upload the sketch.
3. Run **Upload LittleFS to Pico/ESP8266/ESP32** from the command palette (Ctrl+Shift+P). This needs the board's serial port (`/dev/ttyACM0` on Linux). If the UF2 port is selected instead, you get an "Unknown upload method" error.

If the board still has the MicroPython firmware it ships with, hold BOOT while you plug it in for the first upload. After that the IDE can reset it on its own.

For the UART build, open the Serial Monitor at 115200 baud with the line ending set to Newline:

```
> test
Known-answer test: expect 00111000
  encrypt  10010111  key 1010000010  ->  00111000   (0x38)
Round trip: expect 10010111
  decrypt  00111000  key 1010000010  ->  10010111   (0x97)
> e CC 1DD
  encrypt  11001100  key 0111011101  ->  11100100   (0xE4)
```

Values can be binary (exactly 8 or 10 digits) or hex.

## Not done yet

- Fit the full DES core on the ForgeFPGA and record LUT, flip-flop and timing figures. The SLG47910 is a small part, so the eight S-boxes may not fit as they are.
- Put DES behind the same UART interface as S-DES.

## References

- E. Schaefer, "A Simplified Data Encryption Standard Algorithm", *Cryptologia* 20(1), 1996
- FIPS PUB 46-3, *Data Encryption Standard*, NIST, 1999

## License

MIT. See [LICENSE](LICENSE).
