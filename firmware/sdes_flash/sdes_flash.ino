#include "Shrike.h"

ShrikeFlash shrike;

void setup() {
  Serial.begin(115200);
  while (!Serial && millis() < 3000);

  shrike.begin();
  shrike.flash("/sdes.bin");
}

void loop() {
  // Empty loop - nothing to do
}


