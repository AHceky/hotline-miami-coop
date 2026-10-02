"""Recolour Jacket's HM1 player frames (BGRA) into another character's palette.

Used for the animations the HM2 characters have no equivalent of (ground executions with the victim
baked into Jacket's sprite, human shields, climbing...)."""

# Jacket-only colours: letterman jacket (c0c000 light, 808000 dark) and hair (golds, light to dark).
JACKET, JACKET_DARK = 0xc0c000, 0x808000
HAIR = (0xdec169, 0xd2ab33, 0xb08e26, 0xc29c29)
# Sleeves are white with grey shading, the same white as the mobsters' suits, so a white blob is
# recoloured only when most of it lies next to Jacket's body.
WHITE, GREY = 0xffffff, 0x808080
NEAR = 5        # px from a Jacket-only pixel
SHARE = 0.6     # fraction of a white blob that must be near

# skin -> (jacket, jacket dark, sleeve, sleeve shade, hair light, hair mid, hair dark, hair darkest)
PALETTES = {
    'beard':   (0x2b4d2d, 0x142315, 0x2b4d2d, 0x142315, 0xa27c4a, 0xa27c4a, 0x804000, 0x9f5000),
    'richter': (0x80ff80, 0x429d59, 0x80ff80, 0x429d59, 0x404040, 0x404040, 0x202020, 0x202020),
    'corey':   (0x218d47, 0x155b2e, 0x2dbc8d, 0x218d47, 0xffffff, 0x202020, 0x080808, 0x080808),
    'jake':    (0x252525, 0x1a1a1a, 0x252525, 0x1a1a1a, 0xffe4bf, 0xffba5e, 0xdd8d3e, 0xdd8d3e),
    'son':     (0xffffff, 0xa2a2a2, 0xffffff, 0xa2a2a2, 0xa27c4a, 0xa27c4a, 0x634d2e, 0x634d2e),
    'writer':  (0xff8040, 0xb14e34, 0xff8040, 0xb14e34, 0x643200, 0x643200, 0x1a0d00, 0x1a0d00),
    'pardo':   (0x493a25, 0x2b2215, 0x493a25, 0x2b2215, 0xa27c4a, 0x6a5435, 0x6a5435, 0x2b2215),
    'henchman': (0xffffff, 0xa2a2a2, 0xffffff, 0xa2a2a2, 0xc77945, 0xc77945, 0x895029, 0x895029),
}


def recolor(w, h, px, skin='beard'):
    p = PALETTES[skin]
    body = {JACKET: p[0], JACKET_DARK: p[1], HAIR[0]: p[4], HAIR[1]: p[5], HAIR[2]: p[6], HAIR[3]: p[7]}
    sleeve = {WHITE: p[2], GREY: p[3]}
    px = bytearray(px)
    rgb = lambda i: (px[i*4+2] << 16) | (px[i*4+1] << 8) | px[i*4]
    n = w * h
    opaque = [px[i*4+3] != 0 for i in range(n)]
    seeds = [i for i in range(n) if opaque[i] and rgb(i) in body]
    if not seeds:
        return bytes(px), False
    near = [False] * n
    for i in seeds:
        x, y = i % w, i // w
        for yy in range(max(0, y - NEAR), min(h, y + NEAR + 1)):
            row = yy * w
            for xx in range(max(0, x - NEAR), min(w, x + NEAR + 1)):
                near[row + xx] = True
    # white/grey blobs (4-connected)
    seen = [False] * n
    out = {}
    for i in range(n):
        if seen[i] or not opaque[i] or rgb(i) not in sleeve:
            continue
        blob, stack = [], [i]
        seen[i] = True
        while stack:
            j = stack.pop()
            blob.append(j)
            x = j % w
            for k in ((j - 1) if x > 0 else -1, (j + 1) if x < w - 1 else -1, j - w, j + w):
                if 0 <= k < n and not seen[k] and opaque[k] and rgb(k) in sleeve:
                    seen[k] = True
                    stack.append(k)
        if sum(near[j] for j in blob) >= SHARE * len(blob):
            for j in blob:
                out[j] = sleeve[rgb(j)]
    for i in seeds:
        out[i] = body[rgb(i)]
    for i, c in out.items():
        px[i*4:i*4+3] = bytes((c & 255, (c >> 8) & 255, c >> 16))
    return bytes(px), True
