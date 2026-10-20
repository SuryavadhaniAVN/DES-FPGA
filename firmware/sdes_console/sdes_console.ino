/*
 * sdes_console.ino -- talk to the S-DES core on the Shrike Lite FPGA.
 *
 * Loads the bitstream at boot, then bridges the USB serial console to the
 * FPGA's UART so you can type plaintexts and keys and get ciphertext back.
 *
 * Wiring is fixed by the board:
 *   RP2040 GPIO14  ->  FPGA pin 18   (we transmit)
 *   RP2040 GPIO15  <-  FPGA pin 17   (we receive)
 *
 * GPIO14/15 are not hardware UART pins on the RP2040, so this uses SerialPIO,
 * a PIO-based soft UART from the arduino-pico core.
 *
 * Commands (plaintext/key may be binary or hex):
 *     e 10010111 1010000010      encrypt
 *     d 00111000 1010000010      decrypt
 *     e 97 282                   same thing in hex
 *     test                       run the known-answer vector
 */

#include <Shrike.h>
#include <SerialPIO.h>

#define FPGA_TX_PIN 14      // RP2040 -> FPGA
#define FPGA_RX_PIN 15      // FPGA  -> RP2040
#define BAUD        115200

SerialPIO fpga(FPGA_TX_PIN, FPGA_RX_PIN);
ShrikeFlash shrike;

// parse a token as binary if it is all 0/1 and the right length, else as hex
static bool parseVal(const String &s, uint16_t bits, uint16_t &out) {
  if (s.length() == 0) return false;
  bool allBin = true;
  for (unsigned i = 0; i < s.length(); i++)
    if (s[i] != '0' && s[i] != '1') { allBin = false; break; }

  if (allBin && s.length() == bits) {
    out = (uint16_t) strtoul(s.c_str(), nullptr, 2);
    return true;
  }
  char *end;
  unsigned long v = strtoul(s.c_str(), &end, 16);
  if (*end != '\0') return false;
  out = (uint16_t) v;
  return out < (1u << bits);
}

static void printBin(uint16_t v, uint8_t bits) {
  for (int i = bits - 1; i >= 0; i--) Serial.print((v >> i) & 1);
}

// send one request, wait for the reply
static bool query(uint8_t mode, uint8_t block, uint16_t key, uint8_t &result) {
  while (fpga.available()) fpga.read();          // drain anything stale

  fpga.write(mode);
  fpga.write(block);
  fpga.write((uint8_t)((key >> 8) & 0x03));
  fpga.write((uint8_t)(key & 0xFF));

  unsigned long t0 = millis();
  while (!fpga.available()) {
    if (millis() - t0 > 500) return false;
  }
  result = fpga.read();
  return true;
}

static void runOne(uint8_t mode, uint16_t block, uint16_t key) {
  uint8_t out;
  if (!query(mode, (uint8_t)block, key, out)) {
    Serial.println("  no reply from the FPGA (check wiring and bitstream)");
    return;
  }
  Serial.print(mode ? "  decrypt  " : "  encrypt  ");
  printBin(block, 8);
  Serial.print("  key ");
  printBin(key, 10);
  Serial.print("  ->  ");
  printBin(out, 8);
  Serial.print("   (0x");
  if (out < 0x10) Serial.print('0');
  Serial.print(out, HEX);
  Serial.println(")");
}

void setup() {
  Serial.begin(115200);
  while (!Serial && millis() < 3000) {}

  if (shrike.begin() && shrike.flash("/sdes.bin"))
    Serial.println("FPGA programming done");
  else
    Serial.println("FPGA programming FAILED");

  delay(50);                       // let the fabric settle
  fpga.begin(BAUD);

  Serial.println();
  Serial.println("S-DES console. Commands:");
  Serial.println("  e <plaintext> <key>    encrypt");
  Serial.println("  d <ciphertext> <key>   decrypt");
  Serial.println("  test                   run the known-answer vector");
  Serial.println("Values may be binary (8 and 10 bits) or hex.");
  Serial.println();
}

void loop() {
  if (!Serial.available()) return;

  String line = Serial.readStringUntil('\n');
  line.trim();
  if (line.length() == 0) return;

  if (line.equalsIgnoreCase("test")) {
    Serial.println("Known-answer test: expect 00111000");
    runOne(0, 0x97, 0x282);
    Serial.println("Round trip: expect 10010111");
    runOne(1, 0x38, 0x282);
    return;
  }

  int s1 = line.indexOf(' ');
  int s2 = line.indexOf(' ', s1 + 1);
  if (s1 < 0 || s2 < 0) {
    Serial.println("  usage: e|d <block> <key>");
    return;
  }

  char cmd = tolower(line.charAt(0));
  if (cmd != 'e' && cmd != 'd') {
    Serial.println("  first token must be e or d");
    return;
  }

  uint16_t block, key;
  if (!parseVal(line.substring(s1 + 1, s2), 8, block)) {
    Serial.println("  bad block: need 8 binary digits or 2 hex digits");
    return;
  }
  if (!parseVal(line.substring(s2 + 1), 10, key)) {
    Serial.println("  bad key: need 10 binary digits or a hex value under 0x400");
    return;
  }

  runOne(cmd == 'd' ? 1 : 0, block, key);
}
