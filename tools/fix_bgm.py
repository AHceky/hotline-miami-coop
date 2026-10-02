"""Write hmbgm.dll: the user's own bgm.dll with its duplicated relocation table fixed.

bgm.dll's base-relocation directory contains the whole block list twice, so a relocated load adds
every delta twice and DllMain crashes (ERROR_DLL_INIT_FAILED 1114). Halving the directory size
makes the loader apply each relocation once.
"""
import struct
import sys


def fix_bgm(src, dst):
    b = bytearray(open(src, 'rb').read())
    pe = struct.unpack_from('<I', b, 0x3c)[0]
    opt = pe + 24
    rrva, rsz = struct.unpack_from('<II', b, opt + 96 + 5 * 8)
    half = rsz // 2
    nsec = struct.unpack_from('<H', b, pe + 6)[0]
    s = opt + struct.unpack_from('<H', b, pe + 20)[0]
    raw = None
    for i in range(nsec):
        _n, vs, va, rs, ra = struct.unpack_from('<8sIIII', b, s + 40 * i)
        if va <= rrva < va + max(vs, rs):
            raw = rrva - va + ra
    # only halve when the second half really repeats the first
    if rsz % 2 == 0 and raw is not None and b[raw:raw + half] == b[raw + half:raw + rsz]:
        struct.pack_into('<I', b, opt + 96 + 5 * 8 + 4, half)
        fixed = True
    else:
        fixed = False
    open(dst, 'wb').write(b)
    return fixed


if __name__ == '__main__':
    print('fixed' if fix_bgm(sys.argv[1], sys.argv[2]) else 'copied unchanged (no duplicate relocations)')
