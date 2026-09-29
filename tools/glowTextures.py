"""Generates the glow textures (textures/point-glow*.tga) around the classic
Interface/Cursor/Point glove, one per "Glow size" setting.

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


if __name__ == "__main__":
	main()
