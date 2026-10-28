"""Fake co-op partner for solo testing: listens on the peer port, mirrors your own state back
shifted by an offset, so a ghost shadows you in game. Your events are acknowledged and dropped.

usage: py -3 echo_peer.py [listen_port=7778] [game_port=7777] [seconds=600] [dx=40] [room code]
(the game's hmcoop.txt needs peer=127.0.0.1:<listen_port> and the same room= as given here)

Packet layout (net/hmnet.c, "HMC4", v1.2): magic, modver, session, seq, room, txe, first, ack_txe (u32 each),
name[16] at 32, 32 doubles of state from offset 48, ack (u32) at 304, nev / nuev (u16) at 308, 40-byte events
from 312.
"""
import random
import socket
import struct
import sys
import time

HEAD = 312
EVENT = 40
NAME, STATE, ACK = 32, 48, 304


def room_of(code):
    """Same hash as room_of() in hmnet.c: FNV-1a of the code without spaces, lower case; 0 = none."""
    h, any_ = 2166136261, False
    for c in code.encode('latin-1', 'replace'):
        if c <= 32:
            continue
        c = ord(chr(c).lower()) if c < 128 else c
        h = ((h ^ c) * 16777619) & 0xFFFFFFFF
        any_ = True
    return (h or 1) if any_ else 0


listen = int(sys.argv[1]) if len(sys.argv) > 1 else 7778
game = int(sys.argv[2]) if len(sys.argv) > 2 else 7777
secs = float(sys.argv[3]) if len(sys.argv) > 3 else 600
dx = float(sys.argv[4]) if len(sys.argv) > 4 else 40
room = room_of(sys.argv[5]) if len(sys.argv) > 5 else 0

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(('127.0.0.1', listen))
s.settimeout(1)
session = random.randrange(1, 2 ** 32)
txe = random.randrange(1, 2 ** 32)  # our (empty) stream: its oldest unacked event is always 1
ack, game_txe = 0, 0
end = time.time() + secs
n = 0
while time.time() < end:
    try:
        d, _ = s.recvfrom(2048)
    except socket.timeout:
        continue
    if len(d) < HEAD or d[:4] != b'HMC4':
        continue
    t = struct.unpack_from('<I', d, 20)[0]
    if t != game_txe:  # the game's stream to us started again
        game_txe, ack = t, 0
    nev = struct.unpack_from('<H', d, ACK + 4)[0]
    if nev:
        # events come oldest first and in order: the last one's id is the highest we have "delivered"
        ack = max(ack, struct.unpack_from('<I', d, HEAD + (nev - 1) * EVENT)[0])
    p = bytearray(d[:HEAD])
    struct.pack_into('<I', p, 8, session)
    struct.pack_into('<IIII', p, 16, room, txe, 1, game_txe)
    p[NAME:NAME + 16] = b'ECHO'.ljust(16, b'\0')
    x = struct.unpack_from('<d', p, STATE + 2 * 8)[0]
    struct.pack_into('<d', p, STATE + 2 * 8, x + dx)
    struct.pack_into('<IHH', p, ACK, ack, 0, 0)
    s.sendto(bytes(p), ('127.0.0.1', game))
    n += 1
    if n % 300 == 0:
        f = struct.unpack_from('<15d', p, STATE)
        print(f'{n} pkts  state={f[0]:.0f} room={f[1]:.0f} x={f[2]:.0f} y={f[3]:.0f} spr={f[4]:.0f} leg={f[9]:.0f}', flush=True)
