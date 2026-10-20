#!/usr/bin/env python3
"""Generate golden DES test vectors using an independent reference implementation.
    pip install pycryptodome --break-system-packages
    python3 gen_vectors.py > vectors.txt
Output format, one per line: KEY PLAINTEXT CIPHERTEXT  (hex, 16 chars each)
"""
from Crypto.Cipher import DES
import binascii, random, sys

random.seed(7)
vecs = [('133457799BBCDFF1', '0123456789ABCDEF'),   # the classic worked example
        ('0000000000000000', '0000000000000000'),
        ('FFFFFFFFFFFFFFFF', 'FFFFFFFFFFFFFFFF'),
        ('0E329232EA6D0D73', '8787878787878787')]
for _ in range(8):
    rnd = lambda: binascii.hexlify(bytes(random.randrange(256) for _ in range(8))).decode().upper()
    vecs.append((rnd(), rnd()))

for k, p in vecs:
    c = DES.new(binascii.unhexlify(k), DES.MODE_ECB).encrypt(binascii.unhexlify(p))
    print("%s %s %s" % (k, p, binascii.hexlify(c).decode().upper()))
