"""Cut homepage art into web/images/home. One-off helper."""
import os

import numpy as np
from PIL import Image

base = r"C:\Users\cunuo\.cursor\projects\c-Users-cunuo-MyAppFlutter-ai-game\assets"
out = r"c:\Users\cunuo\MyAppFlutter\ai_game\web\images\home"
os.makedirs(out, exist_ok=True)

def find(fragment):
    for name in os.listdir(base):
        if fragment in name:
            return os.path.join(base, name)
    raise SystemExit("missing " + fragment)


def key_magenta(image):
    arr = np.array(image.convert("RGBA")).astype(np.float32)
    red, green, blue = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    dist = np.sqrt((red - 255) ** 2 + green**2 + (blue - 255) ** 2)
    alpha = arr[:, :, 3]
    alpha = np.where(dist < 80, 0, alpha)
    band = (dist >= 80) & (dist < 150)
    alpha = np.where(band, np.minimum(alpha, (dist - 80) / 70 * 255), alpha)
    arr[:, :, 3] = np.clip(alpha, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def crop_alpha(image, pad=12):
    arr = np.array(image)
    ys, xs = np.where(arr[:, :, 3] > 12)
    if len(xs) == 0:
        return image
    x0 = max(0, int(xs.min()) - pad)
    x1 = min(image.width, int(xs.max()) + 1 + pad)
    y0 = max(0, int(ys.min()) - pad)
    y1 = min(image.height, int(ys.max()) + 1 + pad)
    return image.crop((x0, y0, x1, y1))


hero = Image.open(find("72d0f167")).convert("RGB")
hero.save(os.path.join(out, "hero.jpg"), quality=88, optimize=True)
print("hero", hero.size)

sheet = Image.open(find("615eeff0"))
width, height = sheet.size
for index, name in enumerate(["market", "bouquet", "counter"]):
    cell = sheet.crop((index * width // 3, 0, (index + 1) * width // 3, height))
    cut = crop_alpha(key_magenta(cell), 8)
    cut.save(os.path.join(out, name + ".png"))
    print(name, cut.size)

cursor_sheet = Image.open(find("743ffe41"))
cw, ch = cursor_sheet.size
for index, name in enumerate(["cursor", "cursor-down"]):
    cell = cursor_sheet.crop((index * cw // 2, 0, (index + 1) * cw // 2, ch))
    cut = crop_alpha(key_magenta(cell), 2)
    scale = 64 / cut.height
    cut = cut.resize((max(1, round(cut.width * scale)), 64), Image.Resampling.LANCZOS)
    arr = np.array(cut)
    red, green, blue, alpha = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    yellow = (red > 190) & (green > 150) & (blue < 140)
    ys, xs = np.where((alpha > 140) & ~yellow)
    top = int(ys.min())
    tip = xs[ys <= top + 2]
    print(name, cut.size, "hotspot", int(round(tip.mean())), top)
    cut.save(os.path.join(out, name + ".png"))
