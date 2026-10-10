"""Cut the cat sheets off their magenta backgrounds.

Sheets are the 1024px ChatGPT downloads. Cells are the empty magenta gutters
measured on those files. The breakthrough row has no gap between the young
cat and the adult cat, so that row is split at the thinnest part of the glow.
"""
import os

import numpy as np
from PIL import Image

src_dir = (
    r"C:\Users\cunuo\.cursor\projects"
    r"\c-Users-cunuo-MyAppFlutter-ai-game\assets"
)
out_dir = r"c:\Users\cunuo\MyAppFlutter\ai_game\assets\images\pets"

sheets = {
    "B_ng_m_o_kem___ng_y_u_3x3-8edc4799": {
        (19, 321, 94, 268): "meo_au_ngoi.png",
        (19, 321, 390, 654): "meo_lon_ngoi.png",
        (19, 321, 722, 1013): "meo_truong_ngoi.png",
        (345, 641, 87, 291): "meo_au_vuot.png",
        (345, 641, 388, 655): "meo_lon_vuot.png",
        (345, 641, 722, 1012): "meo_truong_vuot.png",
        (651, 1008, 69, 278): "meo_au_be.png",
        (651, 1008, 375, 637): "meo_lon_be.png",
        (651, 1008, 704, 1010): "meo_truong_be.png",
    },
    "M_o_tam_th____ng_y_u_b_n_b_t__n-789c80cc": {
        (140, 496, 32, 265): "meo_au_doi.png",
        (140, 496, 320, 593): "meo_lon_doi.png",
        (140, 496, 641, 1004): "meo_truong_doi.png",
        (595, 913, 0, 273): "meo_au_an.png",
        (595, 913, 303, 627): "meo_lon_an.png",
        (595, 913, 649, 1016): "meo_truong_an.png",
    },
    "B__s_u_m_o_chibi_ph_p_thu_t-42236e4f": {
        (96, 467, 45, 271): "meo_au_nang.png",
        (96, 467, 341, 622): "meo_lon_nang.png",
        (96, 467, 671, 1004): "meo_truong_nang.png",
        (534, 946, 0, 309): "meo_au_dotpha.png",
        (534, 946, 310, 636): "meo_lon_dotpha.png",
        (534, 946, 637, 1024): "meo_truong_dotpha.png",
    },
    "B_nh_m_t_ong_v__gi_t_h__ph_ch_hoa_c_c-eb0eb4a6": {
        (180, 820, 40, 430): "banh_mat.png",
        (140, 860, 560, 1024): "giat_hoa.png",
    },
}


def key_magenta(image):
    arr = np.array(image.convert("RGBA")).astype(np.float32)
    red, green, blue = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    dist = np.sqrt((red - 255) ** 2 + green**2 + (blue - 255) ** 2)
    alpha = np.clip((dist - 48) / 42 * 255, 0, 255)
    arr[:, :, 3] = alpha
    return Image.fromarray(arr.astype(np.uint8))


def trim(image, pad=4):
    alpha = np.array(image)[:, :, 3]
    ys, xs = np.where(alpha > 16)
    if len(xs) == 0:
        raise SystemExit("empty sprite")
    return image.crop((
        max(0, int(xs.min()) - pad),
        max(0, int(ys.min()) - pad),
        min(image.width, int(xs.max()) + 1 + pad),
        min(image.height, int(ys.max()) + 1 + pad),
    ))


def main():
    os.makedirs(out_dir, exist_ok=True)
    sources = {}
    for name in os.listdir(src_dir):
        for key in sheets:
            if key in name:
                sources[key] = os.path.join(src_dir, name)
    missing = [key for key in sheets if key not in sources]
    if missing:
        raise SystemExit(f"missing sheets: {missing}")
    for key, cells in sheets.items():
        sheet = Image.open(sources[key]).convert("RGB")
        for (top, bottom, left, right), filename in cells.items():
            cell = key_magenta(sheet.crop((left, top, right, bottom)))
            sprite = trim(cell)
            dest = os.path.join(out_dir, filename)
            sprite.save(dest, optimize=True)
            print(filename, sprite.size)


if __name__ == "__main__":
    main()
