from PIL import Image, ImageDraw

STRIDE = 17  # 16px tile + 1px margin

def grid(path, cols, rows, scale, out):
    img = Image.open(path).convert("RGBA")
    bg = Image.new("RGBA", img.size, (40, 40, 48, 255))
    bg.alpha_composite(img)
    crop_w = min(cols * STRIDE, img.width)
    crop_h = min(rows * STRIDE, img.height)
    bg = bg.crop((0, 0, crop_w, crop_h))
    big = bg.resize((bg.width * scale, bg.height * scale), Image.NEAREST).convert("RGB")
    d = ImageDraw.Draw(big)
    # gridlines + labels every column/row
    for c in range(cols + 1):
        x = c * STRIDE * scale
        d.line([(x, 0), (x, big.height)], fill=(255, 0, 0), width=1)
    for r in range(rows + 1):
        y = r * STRIDE * scale
        d.line([(0, y), (big.width, y)], fill=(255, 0, 0), width=1)
    for c in range(cols):
        d.text((c * STRIDE * scale + 2, 1), str(c), fill=(255, 255, 0))
    for r in range(rows):
        d.text((1, r * STRIDE * scale + 1), str(r), fill=(0, 255, 255))
    big.save(out)
    print(out, "size", img.size, "cols0..%d rows0..%d" % (cols - 1, rows - 1))

base = r"F:\Git\Uemantra\EndTimesTactical"
char = base + r"\_dl\chars\Spritesheet\roguelikeChar_transparent.png"
env = base + r"\assets\sprites\roguelike\roguelikeSheet_transparent.png"

# char sheet 918x203 = 54 cols x 11 rows. Split into two halves for legibility.
grid(char, 27, 12, 7, base + r"\_dl\char_L.png")
# right half: shift by cropping a sub-image first
img = Image.open(char).convert("RGBA")
right = img.crop((27 * STRIDE, 0, img.width, img.height))
right.save(base + r"\_dl\_char_right_raw.png")
grid(base + r"\_dl\_char_right_raw.png", 27, 12, 7, base + r"\_dl\char_R.png")
