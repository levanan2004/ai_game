"""Cut the five event scenes off their magenta backgrounds."""
import os

import numpy as np
from PIL import Image

base = r"C:\Users\cunuo\.cursor\projects\c-Users-cunuo-MyAppFlutter-ai-game\assets"
out_dir = r"c:\Users\cunuo\MyAppFlutter\ai_game\assets\images\events"
names = {
    "77d539cc": "power.png",
    "f7f9d324": "rain.png",
    "41ef0921": "grandma.png",
    "bfb9d37b": "wholesale.png",
    "49cb038d": "theft.png",
}

def cut(src, dest):
    im = Image.open(src).convert("RGBA")
    arr = np.array(im).astype(np.float32)
    red, green, blue = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    dist = np.sqrt((red - 255) ** 2 + green**2 + (blue - 255) ** 2)
    alpha = arr[:, :, 3]
    alpha = np.where(dist < 90, 0, alpha)
    band = (dist >= 90) & (dist < 160)
    alpha = np.where(band, np.minimum(alpha, (dist - 90) / 70 * 255), alpha)
    # Feather keeps a pink edge. Tint it cream so it sits on the popup.
    feather = (alpha > 0) & (alpha < 230)
    arr[feather, 0] = 248
    arr[feather, 1] = 245
    arr[feather, 2] = 234
    arr[:, :, 3] = np.clip(alpha, 0, 255)
    image = Image.fromarray(arr.astype(np.uint8))
    ys, xs = np.where(np.array(image)[:, :, 3] > 16)
    pad = 12
    image = image.crop((
        max(0, int(xs.min()) - pad),
        max(0, int(ys.min()) - pad),
        min(image.width, int(xs.max()) + 1 + pad),
        min(image.height, int(ys.max()) + 1 + pad),
    ))
    image.thumbnail((640, 640), Image.Resampling.LANCZOS)
    image.save(dest, optimize=True)
    print(dest, image.size)

os.makedirs(out_dir, exist_ok=True)
for name in os.listdir(base):
    for key, filename in names.items():
        if key in name:
            cut(os.path.join(base, name), os.path.join(out_dir, filename))
