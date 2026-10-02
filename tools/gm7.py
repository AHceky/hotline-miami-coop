"""GameMaker 7.0 executable gamedata reader/writer (Hotline Miami 1 "Original" exe).

Layout (see MODLOG.md):
  exe[...1980000)            runner
  @1980000                   magic, version 700, debug, settings (ver 702), D3DX8.dll
  u32 len + zlib stream       gamedata, to EOF
  inflated: g1, g2, garbage, seed, garbage, then the seed-encrypted asset stream.

Only code-bearing assets (scripts, objects, timelines, rooms) are parsed into fields; everything else
is kept as raw byte spans so a round trip reproduces the input exactly.
"""
import struct
import zlib

HEADER_POS = 1980000
MAGIC = 1234321


def seed_tables(seed):
    t = list(range(256))
    a = 6 + seed % 250
    b = seed // 250
    for i in range(1, 10001):
        j = 1 + ((i * a + b) % 254)
        t[j], t[j + 1] = t[j + 1], t[j]
    r = [0] * 256
    for i in range(1, 256):
        r[t[i]] = i
    return t, r


def _shift_tables(sign):
    return [bytes(((v + sign * o) & 0xFF) for v in range(256)) for o in range(256)]


def decrypt(buf, start, seed):
    """Decrypt buf[start:] in place-copy. Byte at `start` is plain."""
    _, rev = seed_tables(seed)
    out = bytearray(buf[start:].translate(bytes(rev)))
    sub = _shift_tables(-1)
    for o in range(256):
        k = (o - start) % 256
        out[k::256] = bytes(out[k::256]).translate(sub[o])
    out[0] = buf[start]
    return out


def encrypt(plain, start, seed):
    fwd, _ = seed_tables(seed)
    out = bytearray(plain)
    add = _shift_tables(+1)
    for o in range(256):
        k = (o - start) % 256
        out[k::256] = bytes(out[k::256]).translate(add[o])
    out = bytearray(bytes(out).translate(bytes(fwd)))
    out[0] = plain[0]
    return out


CODE_SEED = 12345  # runner: mov edx,0x3039 before decoding every code blob
_CODE_FWD, _CODE_REV = seed_tables(CODE_SEED)


def decode_code(blob):
    """Code blob = zlib(substitute_12345(u32 len + text)). Returns text bytes."""
    z = zlib.decompress(blob).translate(bytes(_CODE_REV))
    n = struct.unpack_from('<I', z, 0)[0]
    return z[4:4 + n]


def encode_code(text):
    if isinstance(text, str):
        text = text.encode('latin-1')
    z = (struct.pack('<I', len(text)) + text).translate(bytes(_CODE_FWD))
    return zlib.compress(z, 9)


class R:
    def __init__(self, data, pos=0):
        self.d = data
        self.p = pos

    def u32(self):
        v = struct.unpack_from('<I', self.d, self.p)[0]
        self.p += 4
        return v

    def i32(self):
        v = struct.unpack_from('<i', self.d, self.p)[0]
        self.p += 4
        return v

    def f64(self):
        v = struct.unpack_from('<d', self.d, self.p)[0]
        self.p += 8
        return v

    def raw(self, n):
        v = bytes(self.d[self.p:self.p + n])
        self.p += n
        return v

    def s(self):
        n = self.u32()
        return self.raw(n)

    def skip(self, n):
        self.p += n


class W:
    def __init__(self):
        self.b = bytearray()

    def u32(self, v):
        self.b += struct.pack('<I', v & 0xFFFFFFFF)

    def i32(self, v):
        self.b += struct.pack('<i', v)

    def f64(self, v):
        self.b += struct.pack('<d', v)

    def raw(self, v):
        self.b += v

    def s(self, v):
        if isinstance(v, str):
            v = v.encode('latin-1')
        self.u32(len(v))
        self.b += v


# ---------------------------------------------------------------- code actions / events

class Action:
    FIELDS = ('ver', 'lib_id', 'id', 'kind', 'can_rel', 'is_cond', 'applies_sth', 'exec_type')

    @classmethod
    def read(cls, r):
        a = cls()
        for f in cls.FIELDS:
            setattr(a, f, r.u32())
        a.fn_name = r.s()
        a.fn_code = r.s()
        a.argc = r.u32()
        n = r.u32()
        a.arg_types = [r.u32() for _ in range(n)]
        a.applies_to = r.i32()
        a.relative = r.u32()
        n = r.u32()
        a.args = [r.s() for _ in range(n)]
        a.invert = r.u32()
        return a

    def write(self, w):
        for f in self.FIELDS:
            w.u32(getattr(self, f))
        w.s(self.fn_name)
        w.s(self.fn_code)
        w.u32(self.argc)
        w.u32(len(self.arg_types))
        for t in self.arg_types:
            w.u32(t)
        w.i32(self.applies_to)
        w.u32(self.relative)
        w.u32(len(self.args))
        for s in self.args:
            w.s(s)
        w.u32(self.invert)

    @classmethod
    def code(cls, gml, template):
        """New 'execute code' action (lib 1, id 603) cloned from an existing one."""
        a = cls()
        a.__dict__.update(template.__dict__)
        a.args = list(template.args)
        a.args[0] = gml.encode('latin-1') if isinstance(gml, str) else gml
        return a


def read_actions(r):
    ver = r.u32()
    n = r.u32()
    return ver, [Action.read(r) for _ in range(n)]


def write_actions(w, ver, actions):
    w.u32(ver)
    w.u32(len(actions))
    for a in actions:
        a.write(w)


# ---------------------------------------------------------------- assets

class Script:
    @classmethod
    def read(cls, r):
        o = cls()
        o.name = r.s()
        o.ver = r.u32()
        o.code = r.s()
        return o

    def write(self, w):
        w.s(self.name)
        w.u32(self.ver)
        w.s(self.code)


class Object:
    @classmethod
    def read(cls, r):
        o = cls()
        o.name = r.s()
        o.ver = r.u32()
        o.sprite = r.i32()
        o.solid = r.u32()
        o.visible = r.u32()
        o.depth = r.i32()
        o.persistent = r.u32()
        o.parent = r.i32()
        o.mask = r.i32()
        o.nlists = r.u32()
        o.events = []  # list of lists of (sub, ver, actions)
        for _ in range(o.nlists + 1):
            lst = []
            while True:
                sub = r.i32()
                if sub < 0:
                    break
                ver, acts = read_actions(r)
                lst.append([sub, ver, acts])
            o.events.append(lst)
        return o

    def write(self, w):
        w.s(self.name)
        w.u32(self.ver)
        w.i32(self.sprite)
        w.u32(self.solid)
        w.u32(self.visible)
        w.i32(self.depth)
        w.u32(self.persistent)
        w.i32(self.parent)
        w.i32(self.mask)
        w.u32(self.nlists)
        for lst in self.events:
            for sub, ver, acts in lst:
                w.i32(sub)
                write_actions(w, ver, acts)
            w.i32(-1)

    def event(self, etype, sub=0):
        for e in self.events[etype]:
            if e[0] == sub:
                return e
        return None


class Timeline:
    @classmethod
    def read(cls, r):
        o = cls()
        o.name = r.s()
        o.ver = r.u32()
        n = r.u32()
        o.moments = []
        for _ in range(n):
            t = r.u32()
            ver, acts = read_actions(r)
            o.moments.append((t, ver, acts))
        return o

    def write(self, w):
        w.s(self.name)
        w.u32(self.ver)
        w.u32(len(self.moments))
        for t, ver, acts in self.moments:
            w.u32(t)
            write_actions(w, ver, acts)


# event type ids (GM7)
EV_CREATE, EV_DESTROY, EV_ALARM, EV_STEP, EV_COLLISION, EV_KEYBOARD, EV_MOUSE, EV_OTHER, EV_DRAW, \
    EV_KEYPRESS, EV_KEYRELEASE, EV_TRIGGER = range(12)


# ---------------------------------------------------------------- whole game

class Game:
    """Parsed HM GM7 exe. Raw spans are kept for everything we don't edit."""

    def __init__(self, path):
        exe = open(path, 'rb').read()
        r = R(exe, HEADER_POS)
        assert r.u32() == MAGIC and r.u32() == 700, 'not a GM7 exe'
        i = exe.find(b'D3DX8.dll', HEADER_POS) - 4
        r.p = i
        r.s()
        r.skip(r.u32())
        self.exe_head = exe[:r.p]
        zlen = r.u32()
        infl = zlib.decompress(exe[r.p:r.p + zlen])
        g = R(infl)
        g1, g2 = g.u32(), g.u32()
        g.skip(g1 * 4)
        self.seed = g.u32()
        g.skip(g2 * 4)
        self.data_pos = g.p
        self.infl_head = infl[:g.p]
        plain = decrypt(infl, g.p, self.seed)
        self._parse(plain)

    def _parse(self, d):
        r = R(d)
        r.skip(24)                       # flag, game id, guid
        assert r.u32() == 700 and r.u32() == 0  # extensions
        # sounds
        assert r.u32() == 400
        for _ in range(r.u32()):
            if not r.u32():
                continue
            r.s(); r.u32(); r.u32(); r.s(); r.s()
            if r.u32():
                r.skip(r.u32())
            r.skip(4 + 8 + 8 + 4)
        # sprites
        self.pre_sprites = d[:r.p]
        assert r.u32() == 400
        self.sprite_count = r.u32()
        spr_start = r.p
        self._sprite_names = set()
        for _ in range(self.sprite_count):
            if not r.u32():
                continue
            self._sprite_names.add(r.s().decode('latin-1')); r.u32()
            nf = [r.i32() for _ in range(14)][-1]
            for _ in range(nf):
                r.u32()
                if r.i32() != -1:
                    r.skip(8)
                    r.skip(r.u32())
        self.sprite_raw = d[spr_start:r.p]
        self.new_sprites = []
        bg_start = r.p
        # backgrounds
        assert r.u32() == 400
        for _ in range(r.u32()):
            if not r.u32():
                continue
            r.s(); r.u32(); r.skip(24); r.u32()
            if r.i32() != -1:
                r.skip(8)
                r.skip(r.u32())
        # paths
        assert r.u32() == 420
        for _ in range(r.u32()):
            if not r.u32():
                continue
            r.s(); r.u32(); r.skip(12)
            r.skip(24 * r.u32())
        self.pre_scripts = d[bg_start:r.p]  # backgrounds + paths
        assert r.u32() == 400
        self.scripts = [Script.read(r) if r.u32() else None for _ in range(r.u32())]
        a = r.p
        assert r.u32() == 540            # fonts
        for _ in range(r.u32()):
            if not r.u32():
                continue
            r.s(); r.u32(); r.s(); r.skip(20 + 0x600 * 4 + 8)
            r.skip(r.u32())
        assert r.u32() == 500            # timelines
        for _ in range(r.u32()):
            if r.u32():
                Timeline.read(r)
        self.mid = d[a:r.p]
        assert r.u32() == 400
        self.objects = [Object.read(r) if r.u32() else None for _ in range(r.u32())]
        self.tail = d[r.p:]

    # raw GM7 settings dwords after magic, version, debug, settings-version (702) at HEADER_POS
    SET_FULLSCREEN = 1
    SET_FREEZE_ON_LOSE_FOCUS = 22

    def _set_setting(self, index, value):
        h = bytearray(self.exe_head)
        assert struct.unpack_from('<I', h, HEADER_POS + 12)[0] == 702
        struct.pack_into('<i', h, HEADER_POS + 12 + 4 * index, value)
        self.exe_head = bytes(h)

    def set_fullscreen(self, on):
        self._set_setting(self.SET_FULLSCREEN, 1 if on else 0)

    def set_freeze_on_lose_focus(self, on):
        self._set_setting(self.SET_FREEZE_ON_LOSE_FOCUS, 1 if on else 0)

    # --- lookups
    def script(self, name):
        for i, s in enumerate(self.scripts):
            if s and s.name == name.encode():
                return i, s
        raise KeyError(name)

    def obj(self, name):
        for i, o in enumerate(self.objects):
            if o and o.name == name.encode():
                return i, o
        raise KeyError(name)

    def script_text(self, name):
        return decode_code(self.script(name)[1].code).decode('latin-1')

    def set_script_text(self, name, text):
        self.script(name)[1].code = encode_code(text)

    def add_script(self, name, text):
        s = Script()
        s.name, s.ver, s.code = name.encode(), 400, encode_code(text)
        self.scripts.append(s)
        return len(self.scripts) - 1

    def add_object(self, name, template_code_action, events, depth=0, visible=1, persistent=0):
        """events: {(etype, sub): gml}"""
        o = Object()
        o.name, o.ver, o.sprite, o.solid, o.visible = name.encode(), 430, -1, 0, visible
        o.depth, o.persistent, o.parent, o.mask, o.nlists = depth, persistent, -1, -1, 10
        o.events = [[] for _ in range(11)]
        for (et, sub), gml in sorted(events.items()):
            o.events[et].append([sub, 400, [Action.code(gml, template_code_action)]])
        self.objects.append(o)
        return len(self.objects) - 1

    # --- output
    def sprite_names(self):
        return set(self._sprite_names)

    def sprite_frames(self, wanted):
        """{name: (origin_x, origin_y, [(w, h, BGRA bytes), ...])} for the game's own sprites in wanted."""
        d, p, out = self.sprite_raw, 0, {}
        def i32():
            nonlocal p
            v = struct.unpack_from('<i', d, p)[0]
            p += 4
            return v
        for _ in range(self.sprite_count):
            if not i32():
                continue
            n = i32()
            name = d[p:p + n].decode('latin-1')
            p += n
            i32()
            hdr = [i32() for _ in range(14)]
            frames = []
            for _ in range(hdr[-1]):
                i32()
                if i32() != -1:
                    w, h, ln = i32(), i32(), i32()
                    if name in wanted:
                        frames.append((w, h, zlib.decompress(d[p:p + ln])))
                    p += ln
            if name in wanted:
                out[name] = (hdr[11], hdr[12], frames)
        return out

    def add_sprite(self, name, frames, origin_x, origin_y):
        """frames: list of (w, h, rgba bytes), all the same size. Returns the new sprite index.

        GM7 frames are 32-bit BGRA like the game's own: opaque pixels need alpha 255 (0 draws
        nothing), transparency is the colour of the bottom-left pixel. Frames get a 1 px transparent
        border so that pixel is always the key colour.
        """
        key = (0x00, 0x80, 0x40)  # the key colour the game's own sprites use (B, G, R)
        fw, fh = frames[0][0] + 2, frames[0][1] + 2
        out = W()
        out.u32(1)
        out.s(name)
        out.u32(542)
        for v in (fw, fh, 0, fw - 1, fh - 1, 0,   # w, h, bbox left, right, bottom, top
                  1, 0, 0, 0, 0,                  # transparent, smooth, preload (no: textures made on first draw), bbox mode, precise
                  origin_x + 1, origin_y + 1, len(frames)):
            out.i32(v)
        for w, h, rgba in frames:
            assert (w + 2, h + 2) == (fw, fh)
            px = bytearray((bytes(key) + b'\x00') * (fw * fh))
            for yy in range(h):
                row = (yy + 1) * fw
                for xx in range(w):
                    i = (yy * w + xx) * 4
                    if rgba[i + 3] >= 128:
                        o = (row + xx + 1) * 4
                        px[o:o + 4] = bytes((rgba[i + 2], rgba[i + 1], rgba[i], 255))
                        # never collide with the key colour by accident
                        if px[o:o + 3] == bytes(key):
                            px[o] = 1
            out.u32(540)
            out.i32(1)
            out.u32(fw)
            out.u32(fh)
            z = zlib.compress(bytes(px), 9)
            out.u32(len(z))
            out.raw(z)
        self.new_sprites.append(bytes(out.b))
        return self.sprite_count + len(self.new_sprites) - 1

    def build_plain(self):
        w = W()
        w.raw(self.pre_sprites)
        w.u32(400)
        w.u32(self.sprite_count + len(self.new_sprites))
        w.raw(self.sprite_raw)
        for s in self.new_sprites:
            w.raw(s)
        w.raw(self.pre_scripts)
        w.u32(400)
        w.u32(len(self.scripts))
        for s in self.scripts:
            w.u32(1 if s else 0)
            if s:
                s.write(w)
        w.raw(self.mid)
        w.u32(400)
        w.u32(len(self.objects))
        for o in self.objects:
            w.u32(1 if o else 0)
            if o:
                o.write(w)
        w.raw(self.tail)
        return bytes(w.b)

    def save(self, path):
        plain = self.build_plain()
        infl = bytes(self.infl_head) + bytes(encrypt(plain, self.data_pos, self.seed))
        z = zlib.compress(infl, 6)
        open(path, 'wb').write(self.exe_head + struct.pack('<I', len(z)) + z)
