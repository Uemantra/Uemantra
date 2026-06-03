from PIL import Image, ImageDraw
import os

terr = r"F:\Git\Uemantra\_ett_asset_packs\hexagon\PNG\Tiles\Terrain"
out = r"F:\Git\Uemantra\EndTimesTactical\assets\sprites\hex_terrain"
os.makedirs(out, exist_ok=True)

# (folder, file, opaque fallback bg, output name)
specs = [
    ("Mars", "mars_05", (214, 197, 158), "floor_a.png"),   # tan wasteland
    ("Sand", "sand_05", (196, 120, 78),  "floor_b.png"),   # rust/clay
]
BOX = (34, 50, 86, 90)  # 52 x 40 centre

made = []
for sub, name, bg, outname in specs:
    im = Image.open(os.path.join(terr, sub, name + ".png")).convert("RGBA").crop(BOX)
    flat = Image.new("RGBA", im.size, bg + (255,))
    flat.alpha_composite(im)            # kill any transparency
    flat = flat.convert("RGB")
    flat.save(os.path.join(out, outname))
    made.append((outname, flat))

# preview
w, h = made[0][1].size
scale = 6
sheet = Image.new("RGB", (w * scale * len(made) + 10, h * scale + 16), (30, 30, 36))
d = ImageDraw.Draw(sheet)
for i, (nm, im) in enumerate(made):
    sheet.paste(im.resize((w * scale, h * scale), Image.NEAREST), (i * w * scale + i * 10, 16))
    d.text((i * (w * scale + 10) + 2, 2), nm, fill=(255, 255, 0))
sheet.save(r"F:\Git\Uemantra\_ett_asset_packs\floor_preview.png")
print("saved swatches:", [m[0] for m in made], "size", made[0][1].size)
