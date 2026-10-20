#!/usr/bin/env python3
"""S-DES reference (Schaefer 1996). Bit lists are MSB-first, 1-indexed tables."""

P10 = [3,5,2,7,4,10,1,9,8,6]
P8  = [6,3,7,4,8,5,10,9]
IP  = [2,6,3,1,4,8,5,7]
IPI = [4,1,3,5,7,2,8,6]
EP  = [4,1,2,3,2,3,4,1]
P4  = [2,4,3,1]

S0 = [[1,0,3,2],[3,2,1,0],[0,2,1,3],[3,1,3,2]]
S1 = [[0,1,2,3],[2,0,1,3],[3,0,1,0],[2,1,0,3]]


def perm(bits, table):
    return [bits[i-1] for i in table]


def ls(bits, n):
    return bits[n:] + bits[:n]


def keys(k10):
    p = perm(k10, P10)
    l, r = p[:5], p[5:]
    l1, r1 = ls(l,1), ls(r,1)
    k1 = perm(l1+r1, P8)
    l2, r2 = ls(l1,2), ls(r1,2)
    k2 = perm(l2+r2, P8)
    return k1, k2


def sbox(box, b):
    row = (b[0] << 1) | b[3]
    col = (b[1] << 1) | b[2]
    v = box[row][col]
    return [(v >> 1) & 1, v & 1]


def F(r4, k8):
    e = perm(r4, EP)
    x = [a ^ b for a, b in zip(e, k8)]
    out = sbox(S0, x[:4]) + sbox(S1, x[4:])
    return perm(out, P4)


def fk(bits, k8):
    l, r = bits[:4], bits[4:]
    return [a ^ b for a, b in zip(l, F(r, k8))] + r


def encrypt(p8, k10):
    k1, k2 = keys(k10)
    b = perm(p8, IP)
    b = fk(b, k1)
    b = b[4:] + b[:4]          # SW
    b = fk(b, k2)
    return perm(b, IPI)


def decrypt(c8, k10):
    k1, k2 = keys(k10)
    b = perm(c8, IP)
    b = fk(b, k2)
    b = b[4:] + b[:4]
    b = fk(b, k1)
    return perm(b, IPI)


def tobits(v, n):
    return [(v >> (n-1-i)) & 1 for i in range(n)]


def toint(bits):
    out = 0
    for b in bits:
        out = (out << 1) | b
    return out


if __name__ == "__main__":
    # published check: key 1010000010, plaintext 10010111 -> 00111000
    k = tobits(0b1010000010, 10)
    p = tobits(0b10010111, 8)
    c = encrypt(p, k)
    print("key=1010000010 pt=10010111 ct=%s (0x%02X)" %
          ("".join(map(str, c)), toint(c)))

    # a second published check: all-zero key and plaintext
    k0 = tobits(0, 10); p0 = tobits(0, 8)
    print("key=0000000000 pt=00000000 ct=%s" % "".join(map(str, encrypt(p0, k0))))

    # exhaustive round-trip over every plaintext for a fixed key
    KEY = 0b1010000010
    kb = tobits(KEY, 10)
    bad = 0
    for v in range(256):
        pb = tobits(v, 8)
        if decrypt(encrypt(pb, kb), kb) != pb:
            bad += 1
    print("round-trip failures over all 256 plaintexts:", bad)

    with open("sdes_vectors.txt", "w") as f:
        for v in range(256):
            pb = tobits(v, 8)
            f.write("%02X %02X\n" % (v, toint(encrypt(pb, kb))))
    print("wrote sdes_vectors.txt (key=0x%03X)" % KEY)
