"""Generates the glow textures (textures/point-glow*.tga) around the classic
Interface/Cursor/Point glove, one per "Glow size" setting, and the ring used
by the cast and global cooldown rings and the click ripple (textures/ring.tga).

The glow's falloff by distance from the glove's edge was measured from
CursorMod's midnight glow. Wider or tighter glows stretch that falloff; the
glove-shaped middle stays the same, so it keeps lining up with the cursor.

    pip install pillow numpy scipy
    python tools/glowTextures.py <Point.png, the game's Interface/Cursor/Point>
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
TEXTURES = os.path.join(HERE, "..", "textures")

# glow falloff by distance (px at 4 px per cursor unit) from the cursor edge
GLOW_PROFILE = ([0, .5, 1, 2, 4, 8, 12, 16, 20, 24, 32, 40, 48, 56, 64, 80, 96],
	[0, .43, .6, .97, .96, .92, .85, .78, .70, .63, .48, .36, .25, .17, .11, .03, 0])
EDGE = 2  # the anti-aliased edge keeps its width
# "Glow size" settings and their files (1 is the original point-glow)
SIZES = {.5: "point-glow-50", .75: "point-glow-75", 1: "point-glow", 1.25: "point-glow-125",
	1.5: "point-glow-150", 1.75: "point-glow-175", 2: "point-glow-200"}


def ring():
	"""A thin anti-aliased ring touching the texture's edge, with a faint glow inside."""
	size = 128
	y, x = np.mgrid[0:size, 0:size] + .5
	radius = np.hypot(x - size / 2, y - size / 2)
	outer, width, glow = 62, 7, 10
	band = np.clip(outer - radius + .5, 0, 1) * np.clip(radius - (outer - width) + .5, 0, 1)
	inner_glow = np.clip(1 - (outer - width - radius) / glow, 0, 1) ** 2 * .35 * (radius < outer - width)
	img = np.zeros((size, size, 4), np.uint8)
	img[..., :3] = 255
	img[..., 3] = np.round(np.maximum(band, inner_glow) * 255)
	Image.fromarray(img, "RGBA").save(os.path.join(TEXTURES, "ring.tga"))
	print("wrote ring")


def main():
	# 256 px covering 128 cursor units (2 px per unit), the cursor box in the centre
	point = Image.open(sys.argv[1]).convert("RGBA")
	alpha = np.asarray(point.getchannel("A").resize((64, 64), Image.BICUBIC), dtype=float) / 255
	canvas = np.zeros((256, 256))
	canvas[96:160, 96:160] = alpha
	dist = ndimage.distance_transform_edt(canvas < .5) * 2  # to the profile's 4 px/unit scale
	distances, values = GLOW_PROFILE
	for size, name in SIZES.items():
		stretched = [d if d <= EDGE else EDGE + (d - EDGE) * size for d in distances]
		img = np.zeros((256, 256, 4), np.uint8)
		img[..., :3] = 255
		img[..., 3] = np.round(np.interp(dist, stretched, values) * 255)
		border = np.concatenate([img[0, :, 3], img[-1, :, 3], img[:, 0, 3], img[:, -1, 3]])
		assert border.max() == 0, name + " reaches the texture's edge"
		Image.fromarray(img, "RGBA").save(os.path.join(TEXTURES, name + ".tga"))
		print("wrote", name)
	ring()


if __name__ == "__main__":
	main()
