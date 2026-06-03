from PIL import Image
import os

terr = r"F:\Git\Uemantra\_ett_asset_packs\hexagon\PNG\Tiles\Terrain"
# center crop box for the 120x140 pointy hex (avoid the colored rim)
BOX = (32, 46, 88, 94)  # 56 x 48 flat-ish center

cands = [
    ("Sand", "sand_01"), ("Sand", "sand_03"), ("Sand", "sand_05"),
    ("Dirt", "dirt_01"), ("Dirt", "dirt_03"),
    ("Stone", "stone_01"), ("Stone", "stone_03"),
    ("Mars", "mars_01"), ("Mars", "mars_05"),
]
imgs = []
for sub, name in cands:
    fp = os.path.join(terr, sub, name + ".png")
    im = Image.open(fp).convert("RGBA").crop(BOX)
    imgs.append((name, im))

# preview montage, scaled up 3x with labels
from PIL import ImageDraw
w, h = imgs[0][1].size
scale = 4
sheet = Image.new("RGBA", (w * scale * len(imgs), h * scale + 16), (30, 30, 36, 255))
d = ImageDraw.Draw(sheet)
for i, (name, im) in enumerate(imgs):
    big = im.resize((w * scale, h * scale), Image.NEAREST)
    sheet.alpha_composite(big, (i * w * scale, 16))
    d.text((i * w * scale + 2, 2), name, fill=(255, 255, 0))
sheet.convert("RGB").save(r"F:\Git\Uemantra\_ett_asset_packs\swatch_preview.png")
print("saved", sheet.size)
