# Renders the Cursor Glow Forever logo. Run: python make_logo.py
# The mark: a pointer cursor with the addon's glow and outline, inside a cast ring.
import math, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
TEXTURES = os.path.join(HERE, "..", "textures")
FONT = r"C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\EllesmereUI\media\fonts\Barlow Condensed.ttf"
S = 2048                     # draw big, downsample for clean edges
BG_TOP, BG_BOT = (22, 26, 31), (11, 13, 16)
GLOW = (255, 150, 30)        # the glow: warm orange
GLOW_LIGHT = (255, 205, 110)
EDGE = (20, 16, 10)
STEEL_TOP, STEEL_BOT = (246, 248, 252), (170, 178, 190)
# the pointer, tip at (0, 0), in units of its height
ARROW = [(0, 0), (0, .80), (.19, .62), (.33, .94), (.47, .88), (.33, .57), (.58, .57)]


def background(d):
    for y in range(S):  # vertical gradient
        t = y / (S - 1)
        d.line([(0, y), (S, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOT)) + (255,))


def arrow_mask(cx, cy, h):
    """The pointer as a mask, its box centred on (cx, cy), h tall."""
    w = .58 * h
    x0, y0 = cx - w / 2, cy - h * .47
    m = Image.new("L", (S, S))
    ImageDraw.Draw(m).polygon([(x0 + x * h, y0 + y * h) for x, y in ARROW], fill=255)
    return m


def grow(mask, r):
    """The mask grown by r px (a blur, then a hard threshold)."""
    return mask.filter(ImageFilter.GaussianBlur(r / 2)).point(lambda v: 255 if v > 8 else 0).filter(ImageFilter.GaussianBlur(1.5))


def solid(color, mask, alpha=1):
    layer = Image.new("RGBA", (S, S), color + (0,))
    layer.putalpha(mask.point(lambda v: int(v * alpha)))
    return layer


def mark(img, cx, cy, R):
    """Ring and pointer, centred on (cx, cy), about 2R across."""
    # the cast ring: a faint track, two thirds filled from the top
    rr, rw = R * .92, R * .075
    box = [cx - rr, cy - rr, cx + rr, cy + rr]
    track = Image.new("RGBA", (S, S))
    ImageDraw.Draw(track).ellipse(box, outline=(255, 255, 255, 30), width=int(rw))
    img.alpha_composite(track)
    arc = Image.new("RGBA", (S, S))
    ImageDraw.Draw(arc).arc(box, -90, 150, fill=GLOW + (255,), width=int(rw))
    img.alpha_composite(arc.filter(ImageFilter.GaussianBlur(R * .06)))
    img.alpha_composite(arc)
    # the pointer: soft glow, bright outline, dark edge, steel body
    h = R * 1.2
    body = arrow_mask(cx + R * .02, cy, h)
    img.alpha_composite(solid(GLOW, grow(body, R * .2).filter(ImageFilter.GaussianBlur(R * .18)), .7))
    img.alpha_composite(solid(GLOW, grow(body, R * .12).filter(ImageFilter.GaussianBlur(R * .05)), .8))
    img.alpha_composite(solid(GLOW_LIGHT, grow(body, R * .11)))
    img.alpha_composite(solid(EDGE, grow(body, R * .045)))
    steel = Image.new("RGBA", (S, S))
    sd = ImageDraw.Draw(steel)
    top, bot = cy - h * .47, cy + h * .47
    for y in range(int(top), int(bot) + 1):
        t = (y - top) / (bot - top)
        sd.line([(0, y), (S, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(STEEL_TOP, STEEL_BOT)) + (255,))
    steel.putalpha(body)
    img.alpha_composite(steel)


def render(size, wordmark=True):
    img = Image.new("RGBA", (S, S))
    background(ImageDraw.Draw(img))
    if wordmark:
        mark(img, S / 2, S * 0.40, S * 0.30)
        d = ImageDraw.Draw(img)
        f = ImageFont.truetype(FONT, int(S * 0.15))
        pre, post = "CURSOR", "GLOW"
        tw = d.textlength(pre + post, font=f)
        x, ty = (S - tw) / 2, S * 0.83
        d.text((x, ty), pre, font=f, fill=(236, 239, 242, 255), anchor="ls")
        d.text((x + d.textlength(pre, font=f), ty), post, font=f, fill=GLOW + (255,), anchor="ls")
        d.rectangle([S * 0.40, S * 0.875, S * 0.60, S * 0.882], fill=GLOW + (255,))
    else:
        mark(img, S / 2, S * 0.5, S * 0.42)
    return img.resize((size, size), Image.LANCZOS)


render(512).save(os.path.join(HERE, "logo-512.png"))
render(400).save(os.path.join(HERE, "logo-400.png"))
# In-game add-on list icon: the mark only (text is unreadable that small).
icon = render(64, wordmark=False).convert("RGBA")
icon.save(os.path.join(HERE, "icon-64.png"))
icon.save(os.path.join(TEXTURES, "icon.tga"))
print("done")
