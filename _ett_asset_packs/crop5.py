from PIL import Image, ImageDraw
STRIDE = 17
base = r"F:\Git\Uemantra\EndTimesTactical"
char = base + r"\_dl\chars\Spritesheet\roguelikeChar_transparent.png"
img = Image.open(char).convert("RGBA")
bg = Image.new("RGBA", img.size, (40, 40, 48, 255))
bg.alpha_composite(img)
sub = bg.crop((0, 0, 2 * STRIDE, 12 * STRIDE))
scale = 22
big = sub.resize((sub.width * scale, sub.height * scale), Image.NEAREST).convert("RGB")
d = ImageDraw.Draw(big)
for c in range(3):
    d.line([(c * STRIDE * scale, 0), (c * STRIDE * scale, big.height)], fill=(255, 0, 0))
    if c < 2:
        d.text((c * STRIDE * scale + 2, 1), str(c), fill=(255, 255, 0))
for r in range(13):
    d.line([(0, r * STRIDE * scale), (big.width, r * STRIDE * scale)], fill=(255, 0, 0))
    if r < 12:
        d.text((1, r * STRIDE * scale + 1), str(r), fill=(0, 255, 255))
big.save(base + r"\_dl\v_chars.png")
print("done")
