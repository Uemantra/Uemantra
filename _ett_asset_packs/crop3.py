from PIL import Image, ImageDraw

STRIDE = 17
base = r"F:\Git\Uemantra\EndTimesTactical"
env = base + r"\assets\sprites\roguelike\roguelikeSheet_transparent.png"

def crop_abs(path, c0, c1, r0, r1, scale, out):
    img = Image.open(path).convert("RGBA")
    bg = Image.new("RGBA", img.size, (40, 40, 48, 255))
    bg.alpha_composite(img)
    box = (c0 * STRIDE, r0 * STRIDE, min(c1 * STRIDE, img.width), min(r1 * STRIDE, img.height))
    sub = bg.crop(box)
    big = sub.resize((sub.width * scale, sub.height * scale), Image.NEAREST).convert("RGB")
    d = ImageDraw.Draw(big)
    cc = (box[2] - box[0]) // STRIDE
    rr = (box[3] - box[1]) // STRIDE
    for c in range(cc + 1):
        x = c * STRIDE * scale
        d.line([(x, 0), (x, big.height)], fill=(255, 0, 0), width=1)
        if c < cc:
            d.text((x + 2, 1), str(c0 + c), fill=(255, 255, 0))
    for r in range(rr + 1):
        y = r * STRIDE * scale
        d.line([(0, y), (big.width, y)], fill=(255, 0, 0), width=1)
        if r < rr:
            d.text((1, y + 1), str(r0 + r), fill=(0, 255, 255))
    big.save(out)
    print(out, "abs cols %d-%d rows %d-%d" % (c0, c0 + cc - 1, r0, r0 + rr - 1))

# env 968x526 = 57c x 31r. Two halves.
crop_abs(env, 0, 29, 0, 31, 5, base + r"\_dl\env_L.png")
crop_abs(env, 29, 57, 0, 31, 5, base + r"\_dl\env_R.png")
