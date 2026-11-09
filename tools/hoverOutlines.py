"""Generates the hover outlines (textures/outline-<cursor>.tga): a thin ring
around each hover cursor, drawn like the glove's own outline
(textures/point-outline.tga), hollow in the middle. The "Fill hover outlines"
setting uses the thicker band built in game from the cursor art instead.

Each texture covers twice the cursor, the cursor box in the middle, at 4 px
per cursor unit (the 128 px cell of the game's 2x cursor sheets). The greyed
out of range cursors have the same shapes, so they share the texture.

The sheets come from the game files (Interface/Cursor/<name>.blp, for example
from wago.tools):

    pip install pillow numpy scipy
    python tools/hoverOutlines.py <folder with the .blp sheets>
"""
import os
import struct
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
TEXTURES = os.path.join(HERE, "..", "textures")
# HOVER_SHEETS in CursorGlowForever.lua
SHEETS = {
	"Attack": "UIAttackCursor2x",
	"LootAll": "UILootAllCursor2x",
	"Pickup": "UIPickupCursor2x",
	"Skin": "UICursorSkin2x",
	"Mine": "UICursorMine2x",
	"GatherHerbs": "UICursorGather2x",
	"Mail": "UIMailCursor2x",
	"Buy": "UIBuyCursor2x",
	"RepairNPC": "UIRepairNPCCursor2x",
	"Taxi": "UITaxiCursor2x",
	"Innkeeper": "UIInnkeeperCursor2x",
	"Trainer": "UITrainerCursor2x",
	"StableMaster": "UIStableMasterCursor2x",
	"Repair": "UIRepairCursor2x",
}
CELL = (1, 1, 128)  # left, top, size of the largest cursor on a 512 x 256 sheet
SCALE = 4  # px per cursor unit (a cursor is 32 units)
WIDTH = 2  # ring width outside the cursor's edge, in units
INSIDE = .75  # how far it reaches under the cursor's edge, in units


def readBLP(path):
	"""The alpha of a BLP2 texture (Pillow reads the compressed ones, not raw or palette alpha)."""
	data = open(path, "rb").read()
	assert data[:4] == b"BLP2", path
	encoding, alphaDepth = data[8], data[9]
	width, height = struct.unpack_from("<II", data, 12)
	offset = struct.unpack_from("<16I", data, 20)[0]
	count = width * height
	if encoding == 3:
		alpha = np.frombuffer(data, np.uint8, count * 4, offset)[3::4]
	elif encoding == 1 and alphaDepth == 8:
		alpha = np.frombuffer(data, np.uint8, count, offset + count)
	else:
		return np.asarray(Image.open(path).getchannel("A"), dtype=float) / 255
	return alpha.reshape(height, width) / 255


def outline(alpha):
	"""A ring from INSIDE units under the cursor's edge to WIDTH units outside it, anti-aliased."""
	left, top, size = CELL
	scale = alpha.shape[1] / 512
	cell = alpha[int(top * scale):int((top + size) * scale), int(left * scale):int((left + size) * scale)]
	cell = np.asarray(Image.fromarray(np.uint8(cell * 255)).resize((size, size), Image.BICUBIC), dtype=float) / 255
	canvas = np.zeros((size * 2, size * 2))
	canvas[size // 2:size // 2 + size, size // 2:size // 2 + size] = cell
	solid = canvas >= .5
	outside = ndimage.distance_transform_edt(~solid) / SCALE
	inside = ndimage.distance_transform_edt(solid) / SCALE
	ring = np.where(solid, np.clip((INSIDE - inside) * SCALE + .5, 0, 1), np.clip((WIDTH - outside) * SCALE + .5, 0, 1))
	border = np.concatenate([ring[0], ring[-1], ring[:, 0], ring[:, -1]])
	assert border.max() == 0, "the ring reaches the texture's edge"
	return ring


def main():
	folder = sys.argv[1]
	for key, sheet in SHEETS.items():
		ring = outline(readBLP(os.path.join(folder, sheet + ".blp")))
		img = np.zeros(ring.shape + (4,), np.uint8)
		img[..., :3] = 255
		img[..., 3] = np.round(ring * 255)
		Image.fromarray(img, "RGBA").save(os.path.join(TEXTURES, "outline-%s.tga" % key))
		print("wrote outline-%s" % key)


if __name__ == "__main__":
	main()
