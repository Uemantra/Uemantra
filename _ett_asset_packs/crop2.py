from PIL import Image, ImageDraw

STRIDE = 17
base = r"F:\Git\Uemantra\EndTimesTactical"
char = base + r"\_dl\chars\Spritesheet\roguelikeChar_transparent.png"

def crop_abs(path, c0, c1, r0, r1, scale, out):
    img = Image.open(path).convert("RGBA")
    bg = Image.new("RGBA", img.size, (40, 40, 48, 255))
    bg.alpha_composite(img)
    box = (c0 * STRIDE, r0 * STRIDE, c1 * STRIDE, r1 * STRIDE)
    sub = bg.crop(box)
    big = sub.resize((sub.width * scale, sub.height * scale), Image.NEAREST).convert("RGB")
    d = ImageDraw.Draw(big)
    for c in range(c0, c1 + 1):
        x = (c - c0) * STRIDE * scale
        d.line([(x, 0), (x, big.height)], fill=(255, 0, 0), width=1)
        if c < c1:
            d.text((x + 2, 1), str(c), fill=(255, 255, 0))
    for r in range(r0, r1 + 1):
        y = (r - r0) * STRIDE * scale
        d.line([(0, y), (big.width, y)], fill=(255, 0, 0), width=1)
        if r < r1:
            d.text((1, y + 1), str(r), fill=(0, 255, 255))
    big.save(out)
    print(out)

# Gear/items region: abs cols 33..53, rows 0..9
crop_abs(char, 33, 54, 0, 10, 11, base + r"\_dl\gear.png")
