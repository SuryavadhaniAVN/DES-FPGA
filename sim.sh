#!/bin/bash
# Runs every testbench in the repo. Needs Icarus Verilog (iverilog + vvp).
set -e
cd "$(dirname "$0")"
mkdir -p build
B=$(pwd)/build

echo "=== DES core: 12 vectors, encrypt and decrypt ==="
(cd des && iverilog -g2005 -o "$B/des_sim" des_core.v tb_des.v && vvp "$B/des_sim" | tail -7)

echo
echo "=== S-DES core: all 256 plaintexts + known-answer test ==="
(cd sdes && iverilog -g2005 -o "$B/sdes_sim" sdes.v tb_sdes.v && vvp "$B/sdes_sim" | tail -8)

echo
echo "=== S-DES self-test top: sweep + LED logic ==="
(cd sdes && iverilog -g2005 -o "$B/selftest_sim" sdes.v selftest/sdes_top.v selftest/tb_top.v && vvp "$B/selftest_sim")

echo
echo "=== S-DES UART top: serial frames in, serial reply out ==="
(cd sdes && iverilog -g2005 -o "$B/uart_sim" sdes.v uart/uart.v uart/sdes_uart_top.v uart/tb_uart.v && vvp "$B/uart_sim")
