#!/usr/bin/env python3
"""
hm2_extract.py - read sprites out of a Hotline Miami 2 (Abstraction Games engine) .wad.

Standard library only (PNG decode/encode is done here with zlib).
Reads the user's own game files; never writes to the game folder.

Formats (verified against hlm2_data_desktop.wad, Steam build):

  WAD  ("AGAR" archive, little endian)
    char[4]  "AGAR"
    u32      version major (1)
    u32      version minor (1)
    u32      extra header length N, followed by N bytes (0 in practice)
    u32      file count
      per file: u32 name_len, name (utf-8, '/' separated), u64 size, u64 offset
                (offset is relative to the start of the data section)
    u32      directory count
      per dir:  u32 name_len, name, u32 child count,
                per child: u32 name_len, name, u8 is_directory
    data section (immediately after the directory table)

  Atlas .meta ("AGTEXTUREPACKER")
    u8 len + "AGTEXTUREPACKER"
    u32 version (2), u32 (1 - texture page count)
    repeated until EOF:
      u8 name_len, name
      u32 frame_count
      per frame (36 bytes):
        u32 page (always 0), u32 w, u32 h, u32 x, u32 y,   (pixel rect in the .png)
        f32 u0, v0, u1, v1                                  (same rect normalised)
    Frames are stored untrimmed: every frame of a sprite has the sprite's full w x h.

  GL/hlm2_sprites.bin (sprite properties, origin lives here, not in .meta)
    u32 id_count; i32[id_count] id -> record index (-1 = unused)
    u32 record_count; record_count x 64-byte records of 16 x i32:
      [0] id   [1] width [2] height [3] origin_x [4] origin_y
      [5] bbox_left [6] bbox_right [7] bbox_top [8] bbox_bottom
      [9] frame_count [10..13] flags (unknown) [14] name offset [15] 0
    u32 string_table_size; NUL-terminated names
"""
import json
import os
import re
import struct
import sys
import zlib

# --------------------------------------------------------------------------- WAD

_WAD_CACHE = {}


def _wad_index(wad_path):
    key = os.path.abspath(wad_path)
    if key in _WAD_CACHE:
        return _WAD_CACHE[key]
    with open(wad_path, 'rb') as f:
        head = f.read(16)
        if head[:4] != b'AGAR':
            raise ValueError('%s: not an AGAR wad' % wad_path)
        _maj, _min, extra = struct.unpack_from('<3I', head, 4)
        f.seek(16 + extra)
        count, = struct.unpack('<I', f.read(4))
        entries = {}
        order = []
        for _ in range(count):
            n, = struct.unpack('<I', f.read(4))
            name = f.read(n).decode('utf-8')
            size, off = struct.unpack('<QQ', f.read(16))
            entries[name] = (size, off)
            order.append(name)
        ndirs, = struct.unpack('<I', f.read(4))
        for _ in range(ndirs):
            n, = struct.unpack('<I', f.read(4))
            f.seek(n, 1)
            nchild, = struct.unpack('<I', f.read(4))
            for _ in range(nchild):
                n, = struct.unpack('<I', f.read(4))
                f.seek(n + 1, 1)
        data_start = f.tell()
    idx = (entries, order, data_start)
    _WAD_CACHE[key] = idx
    return idx


def list_files(wad_path):
    """Return [(name, size)] for every file in the wad, in table order."""
    entries, order, _ = _wad_index(wad_path)
    return [(n, entries[n][0]) for n in order]


def read_file(wad_path, name):
    """Return the bytes of one file inside the wad."""
    entries, _, data_start = _wad_index(wad_path)
    if name not in entries:
        raise KeyError(name)
    size, off = entries[name]
    with open(wad_path, 'rb') as f:
        f.seek(data_start + off)
        return f.read(size)


# --------------------------------------------------------------------------- PNG

def png_decode(data):
    """Decode an 8-bit PNG (gray/RGB/palette/gray+A/RGBA, non-interlaced) -> (w, h, RGBA bytes)."""
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('not a PNG')
    p = 8
    idat = []
    plte = trns = None
    w = h = depth = ctype = interlace = None
    while p < len(data):
        ln, = struct.unpack_from('>I', data, p)
        typ = data[p + 4:p + 8]
        body = data[p + 8:p + 8 + ln]
        p += 12 + ln
        if typ == b'IHDR':
            w, h, depth, ctype, _c, _f, interlace = struct.unpack('>IIBBBBB', body)
        elif typ == b'PLTE':
            plte = body
        elif typ == b'tRNS':
            trns = body
        elif typ == b'IDAT':
            idat.append(body)
        elif typ == b'IEND':
            break
    if depth != 8 or interlace:
        raise ValueError('unsupported PNG (depth %s, interlace %s)' % (depth, interlace))
    bpp = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    raw = zlib.decompress(b''.join(idat))
    stride = w * bpp
    out = bytearray(h * stride)
    prev = bytearray(stride)
    p = 0
    for y in range(h):
        ft = raw[p]
        line = bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        if ft == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 255
        elif ft == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif ft == 3:
            for i in range(bpp):
                line[i] = (line[i] + (prev[i] >> 1)) & 255
            for i in range(bpp, stride):
                line[i] = (line[i] + ((line[i - bpp] + prev[i]) >> 1)) & 255
        elif ft == 4:
            for i in range(bpp):
                line[i] = (line[i] + prev[i]) & 255
            for i in range(bpp, stride):
                a = line[i - bpp]
                b = prev[i]
                c = prev[i - bpp]
                pa = abs(b - c)
                pb = abs(a - c)
                pc = abs(a + b - c - c)
                if pa <= pb and pa <= pc:
                    pr = a
                elif pb <= pc:
                    pr = b
                else:
                    pr = c
                line[i] = (line[i] + pr) & 255
        out[y * stride:(y + 1) * stride] = line
        prev = line
    if ctype == 6:
        return w, h, bytes(out)
    rgba = bytearray(w * h * 4)
    if ctype == 2:
        rgba[0::4] = out[0::3]
        rgba[1::4] = out[1::3]
        rgba[2::4] = out[2::3]
        rgba[3::4] = b'\xff' * (w * h)
    elif ctype == 0:
        rgba[0::4] = out
        rgba[1::4] = out
        rgba[2::4] = out
        rgba[3::4] = b'\xff' * (w * h)
    elif ctype == 4:
        rgba[0::4] = out[0::2]
        rgba[1::4] = out[0::2]
        rgba[2::4] = out[0::2]
        rgba[3::4] = out[1::2]
    elif ctype == 3:
        pal = []
        for i in range(len(plte) // 3):
            a = trns[i] if trns and i < len(trns) else 255
            pal.append(bytes((plte[3 * i], plte[3 * i + 1], plte[3 * i + 2], a)))
        rgba = bytearray(b''.join(pal[v] for v in out))
    return w, h, bytes(rgba)


def png_encode(w, h, rgba):
    """Encode RGBA bytes as a PNG (filter 0, zlib level 9)."""
    stride = w * 4
    raw = b''.join(b'\x00' + rgba[y * stride:(y + 1) * stride] for y in range(h))

    def chunk(t, b):
        return struct.pack('>I', len(b)) + t + b + struct.pack('>I', zlib.crc32(t + b) & 0xffffffff)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def crop(atlas_w, atlas_rgba, x, y, w, h):
    s = atlas_w * 4
    return b''.join(atlas_rgba[(y + r) * s + x * 4:(y + r) * s + (x + w) * 4] for r in range(h))


# --------------------------------------------------------------------------- meta / sprites.bin

def parse_meta(data):
    """Parse an AGTEXTUREPACKER .meta -> [(sprite_name, [(x, y, w, h), ...])]."""
    n = data[0]
    if data[1:1 + n] != b'AGTEXTUREPACKER':
        raise ValueError('not an AGTEXTUREPACKER meta')
    p = 1 + n + 8  # skip version, page count
    out = []
    while p < len(data):
        ln = data[p]
        name = data[p + 1:p + 1 + ln].decode('utf-8')
        p += 1 + ln
        fc, = struct.unpack_from('<I', data, p)
        p += 4
        rects = []
        for _ in range(fc):
            _page, w, h, x, y = struct.unpack_from('<5I', data, p)
            rects.append((x, y, w, h))
            p += 36
        out.append((name, rects))
    return out


def parse_sprites_bin(data):
    """Parse GL/hlm2_sprites.bin -> {name: dict(id, w, h, origin_x, origin_y, bbox, frames, flags)}."""
    n, = struct.unpack_from('<I', data, 0)
    p = 4 + 4 * n
    m, = struct.unpack_from('<I', data, p)
    p += 4
    recs = [struct.unpack_from('<16i', data, p + 64 * i) for i in range(m)]
    p += 64 * m
    sl, = struct.unpack_from('<I', data, p)
    st = data[p + 4:p + 4 + sl]
    out = {}
    for r in recs:
        name = st[r[14]:st.index(b'\0', r[14])].decode('utf-8')
        out[name] = dict(id=r[0], w=r[1], h=r[2], origin_x=r[3], origin_y=r[4],
                         bbox=dict(left=r[5], right=r[6], top=r[7], bottom=r[8]),
                         frames=r[9], flags=list(r[10:14]))
    return out


def _atlas_rank(meta_path):
    # Prefer character/enemy atlases, then single-sprite atlases, then per-level copies.
    if meta_path.count('/') == 1:
        return 0
    if meta_path.startswith('Atlases/Sprites/'):
        return 1
    return 2


def sprite_index(wad_path):
    """{sprite_name: dict(meta, png, rects, props)} for every sprite in every atlas (first/best copy)."""
    files = [n for n, _ in list_files(wad_path)]
    fset = set(files)
    pos = {n: i for i, n in enumerate(files)}
    try:
        props = parse_sprites_bin(read_file(wad_path, 'GL/hlm2_sprites.bin'))
    except KeyError:
        props = {}
    metas = sorted((n for n in files if n.endswith('.meta') and n[:-5] + '.png' in fset),
                   key=lambda n: (_atlas_rank(n), pos[n]))
    idx = {}
    for mp in metas:
        data = read_file(wad_path, mp)
        if not data[1:16] == b'AGTEXTUREPACKER':
            continue
        for name, rects in parse_meta(data):
            if name not in idx:
                idx[name] = dict(meta=mp, png=mp[:-5] + '.png', rects=rects, props=props.get(name))
    return idx


def _match(name, filters, excludes):
    low = name.lower()
    if filters and not any(f.lower() in low for f in filters):
        return False
    return not any(re.search(e, name, re.I) for e in excludes or [])


def extract_sprites(wad_path, name_filter=None, exclude=None):
    """Yield dicts for sprites whose name contains name_filter (str or list, case-insensitive):
       name, atlas, frames=[RGBA bytes...], w, h, origin_x, origin_y, bbox, rects."""
    if isinstance(name_filter, str):
        name_filter = [name_filter]
    idx = sprite_index(wad_path)
    atlases = {}
    for name in sorted(idx):
        if not _match(name, name_filter, exclude):
            continue
        e = idx[name]
        if e['png'] not in atlases:
            atlases[e['png']] = png_decode(read_file(wad_path, e['png']))
        aw, _ah, argba = atlases[e['png']]
        frames = [crop(aw, argba, *r) for r in e['rects']]
        w, h = e['rects'][0][2], e['rects'][0][3]
        pr = e['props'] or {}
        yield dict(name=name, atlas=e['png'], frames=frames, w=w, h=h,
                   origin_x=pr.get('origin_x'), origin_y=pr.get('origin_y'),
                   bbox=pr.get('bbox'), rects=e['rects'])


# --------------------------------------------------------------------------- CLI

def _export(wad, outdir, filters, exclude, strips):
    os.makedirs(outdir, exist_ok=True)
    info = []
    for s in extract_sprites(wad, filters, exclude):
        files = []
        for i, fr in enumerate(s['frames']):
            fn = '%s_%d.png' % (s['name'], i)
            with open(os.path.join(outdir, fn), 'wb') as f:
                f.write(png_encode(s['w'], s['h'], fr))
            files.append(fn)
        if strips:
            n = len(s['frames'])
            sw = s['w'] * n
            rows = []
            for y in range(s['h']):
                rows.append(b''.join(fr[y * s['w'] * 4:(y + 1) * s['w'] * 4] for fr in s['frames']))
            os.makedirs(os.path.join(outdir, '_strips'), exist_ok=True)
            with open(os.path.join(outdir, '_strips', s['name'] + '_strip.png'), 'wb') as f:
                f.write(png_encode(sw, s['h'], b''.join(rows)))
        info.append(dict(name=s['name'], frames=len(s['frames']), w=s['w'], h=s['h'],
                         origin_x=s['origin_x'], origin_y=s['origin_y'], bbox=s['bbox'],
                         atlas=s['atlas'],
                         frame_rects=[dict(x=r[0], y=r[1], w=r[2], h=r[3]) for r in s['rects']],
                         files=files))
        print('%-36s %3d frames %3dx%-3d origin %s,%s' % (s['name'], len(s['frames']), s['w'], s['h'],
                                                          s['origin_x'], s['origin_y']))
    with open(os.path.join(outdir, 'sprites.json'), 'w') as f:
        json.dump(info, f, indent=1)
    print('%d sprites -> %s' % (len(info), outdir))


def main(argv):
    import argparse
    ap = argparse.ArgumentParser(description='Extract sprites from a Hotline Miami 2 .wad')
    ap.add_argument('wad')
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument('--list-files', nargs='?', const='', metavar='SUBSTR')
    g.add_argument('--list-sprites', nargs='?', const='', metavar='SUBSTR')
    g.add_argument('--export', nargs='+', metavar=('OUTDIR', 'SUBSTR'))
    ap.add_argument('--exclude', action='append', default=[], metavar='REGEX',
                    help='skip sprite names matching this regex (repeatable)')
    ap.add_argument('--strips', action='store_true', help='also write one horizontal strip per sprite')
    a = ap.parse_args(argv)
    if a.list_files is not None:
        for n, s in list_files(a.wad):
            if a.list_files.lower() in n.lower():
                print('%10d  %s' % (s, n))
    elif a.list_sprites is not None:
        idx = sprite_index(a.wad)
        for name in sorted(idx):
            if _match(name, [a.list_sprites] if a.list_sprites else None, a.exclude):
                e = idx[name]
                pr = e['props'] or {}
                r = e['rects'][0]
                print('%-40s %3d frames %3dx%-3d origin %s,%s  [%s]' % (
                    name, len(e['rects']), r[2], r[3], pr.get('origin_x'), pr.get('origin_y'), e['meta']))
    else:
        if len(a.export) < 2:
            ap.error('--export needs OUTDIR and at least one SUBSTR')
        _export(a.wad, a.export[0], a.export[1:], a.exclude, a.strips)


if __name__ == '__main__':
    main(sys.argv[1:])
