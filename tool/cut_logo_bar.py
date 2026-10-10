"""Cut the horizontal header logo off its magenta sheet."""
import os

import numpy as np
from PIL import Image

base = r"C:\Users\cunuo\.cursor\projects\c-Users-cunuo-MyAppFlutter-ai-game\assets"
out = r"c:\Users\cunuo\MyAppFlutter\ai_game\web\images\home\logo-bar.png"
src = next(os.path.join(base, n) for n in os.listdir(base) if "de6f4ddf" in n)
im = Image.open(src).convert("RGBA")
arr = np.array(im).astype(np.float32)
red, green, blue = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
dist = np.sqrt((red - 255) ** 2 + green**2 + (blue - 255) ** 2)
alpha = arr[:, :, 3]
alpha = np.where(dist < 80, 0, alpha)
band = (dist >= 80) & (dist < 150)
alpha = np.where(band, np.minimum(alpha, (dist - 80) / 70 * 255), alpha)
arr[:, :, 3] = np.clip(alpha, 0, 255)
cut = Image.fromarray(arr.astype(np.uint8))
ys, xs = np.where(np.array(cut)[:, :, 3] > 12)
pad = 8
cut = cut.crop((
    max(0, int(xs.min()) - pad),
    max(0, int(ys.min()) - pad),
    min(cut.width, int(xs.max()) + 1 + pad),
    min(cut.height, int(ys.max()) + 1 + pad),
))
cut.thumbnail((1200, 280), Image.Resampling.LANCZOS)
os.makedirs(os.path.dirname(out), exist_ok=True)
cut.save(out, optimize=True)
print(cut.size)
