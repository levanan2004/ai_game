"""Cut the upgrade scene and copy the game's full-body customers for the landing."""
import json
import os

import numpy as np
from PIL import Image

root = r"c:\Users\cunuo\MyAppFlutter\ai_game"
sheet_dir = r"C:\Users\cunuo\.cursor\projects\c-Users-cunuo-MyAppFlutter-ai-game\assets"
home = os.path.join(root, "web", "images", "home")
src = next(os.path.join(sheet_dir, n) for n in os.listdir(sheet_dir) if "a3f008fe" in n)
im = Image.open(src).convert("RGBA")
arr = np.array(im).astype(np.float32)
red, green, blue = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
dist = np.sqrt((red - 255) ** 2 + green**2 + (blue - 255) ** 2)
alpha = arr[:, :, 3]
alpha = np.where(dist < 90, 0, alpha)
band = (dist >= 90) & (dist < 160)
alpha = np.where(band, np.minimum(alpha, (dist - 90) / 70 * 255), alpha)
arr[:, :, 3] = np.clip(alpha, 0, 255)
cut = Image.fromarray(arr.astype(np.uint8))
ys, xs = np.where(np.array(cut)[:, :, 3] > 16)
pad = 12
cut = cut.crop((
    max(0, int(xs.min()) - pad),
    max(0, int(ys.min()) - pad),
    min(cut.width, int(xs.max()) + 1 + pad),
    min(cut.height, int(ys.max()) + 1 + pad),
))
cut.thumbnail((720, 720), Image.Resampling.LANCZOS)
out = os.path.join(home, "upgrade.png")
cut.save(out, optimize=True)
print("upgrade", cut.size, os.path.getsize(out))

cast_dir = os.path.join(home, "customers")
os.makedirs(cast_dir, exist_ok=True)
index = json.load(open(os.path.join(root, "assets", "images", "customers", "index.json"), encoding="utf-8"))
full = os.path.join(root, "assets", "images", "customers_full")
for person in index:
    avatar = person["avatarId"]
    portrait = Image.open(os.path.join(full, avatar + ".png")).convert("RGBA")
    portrait.thumbnail((220, 420), Image.Resampling.LANCZOS)
    dest = os.path.join(cast_dir, avatar + ".png")
    portrait.save(dest, optimize=True)
print("customers", len(index))
