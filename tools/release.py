"""Builds the CurseForge zip (next to the repo) and installs the addon into the
Forever client's AddOns folder. The version comes from the .toc.

    python tools/release.py [path to the game folder holding _classic_beta_]
"""
import glob
import os
import re
import shutil
import sys
import zipfile

REPO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
GAME = sys.argv[1] if len(sys.argv) > 1 else r"C:\Program Files (x86)\World of Warcraft"
INSTALL = os.path.join(GAME, "_classic_beta_", "Interface", "AddOns", "CursorGlowForever")
# what ships: the addon's files, not the repo's tools, tests or README
FILES = ["CHANGELOG.md", "CursorGlowForever.lua", "CursorGlowForever.toc", "LICENSE", "Locales.lua", "NPCServices.lua",
	"NPCTitles.lua", "Options.lua", "QuestGivers.lua", "Rings.lua"]


def main():
	with open(os.path.join(REPO, "CursorGlowForever.toc"), encoding="utf-8") as f:
		version = re.search(r"^## Version: (\S+)", f.read(), re.M).group(1)
	files = FILES + sorted("textures/" + os.path.basename(p) for p in glob.glob(os.path.join(REPO, "textures", "*.tga")))
	archive = os.path.join(REPO, "..", "CursorGlowForever-%s.zip" % version)
	with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
		for name in files:
			z.write(os.path.join(REPO, name), "CursorGlowForever/" + name)
			target = os.path.join(INSTALL, name)
			os.makedirs(os.path.dirname(target), exist_ok=True)
			shutil.copy2(os.path.join(REPO, name), target)
	print("version %s: %d files installed and zipped (%d KB)" % (version, len(files), os.path.getsize(archive) // 1024))


if __name__ == "__main__":
	main()
