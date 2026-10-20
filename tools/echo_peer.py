"""Fake co-op partner for solo testing: listens on the peer port, mirrors your own state back
shifted by an offset, so a ghost shadows you in game. Your events are acknowledged and dropped.

usage: py -3 echo_peer.py [listen_port=7778] [game_port=7777] [seconds=600] [dx=40]
(the game's hmcoop.txt needs peer=127.0.0.1:<listen_port>)

Packet layout (net/hmnet.c, "HMC4", v0.8): magic, modver, session, seq (u32 each), name[16],
32 doubles of state from offset 32, ack (u32) at 288, nev / nuev (u16) at 292, 40-byte events from 296.
"""
import random
import socket
import struct
import sys
import time

HEAD = 296
EVENT = 40

listen = int(sys.argv[1]) if len(sys.argv) > 1 else 7778
game = int(sys.argv[2]) if len(sys.argv) > 2 else 7777
secs = float(sys.argv[3]) if len(sys.argv) > 3 else 600
dx = float(sys.argv[4]) if len(sys.argv) > 4 else 40

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(('127.0.0.1', listen))
s.settimeout(1)
session = random.randrange(1, 2 ** 32)
ack = 0
end = time.time() + secs
n = 0
while time.time() < end:
    try:
        d, _ = s.recvfrom(2048)
    except socket.timeout:
        continue
    if len(d) < HEAD or d[:4] != b'HMC4':
        continue
    nev = struct.unpack_from('<H', d, 292)[0]
    if nev:
        # events come oldest first and in order: the last one's id is the highest we have "delivered"
        ack = max(ack, struct.unpack_from('<I', d, HEAD + (nev - 1) * EVENT)[0])
    p = bytearray(d[:HEAD])
    struct.pack_into('<I', p, 8, session)
    p[16:32] = b'ECHO'.ljust(16, b'\0')
    x = struct.unpack_from('<d', p, 32 + 2 * 8)[0]
    struct.pack_into('<d', p, 32 + 2 * 8, x + dx)
    struct.pack_into('<IHH', p, 288, ack, 0, 0)
    s.sendto(bytes(p), ('127.0.0.1', game))
    n += 1
    if n % 300 == 0:
        f = struct.unpack_from('<15d', p, 32)
        print(f'{n} pkts  state={f[0]:.0f} room={f[1]:.0f} x={f[2]:.0f} y={f[3]:.0f} spr={f[4]:.0f} leg={f[9]:.0f}', flush=True)
