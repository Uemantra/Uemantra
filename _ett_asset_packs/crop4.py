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
    print(out)

# trees/cactus/dead-tree band
crop_abs(env, 14, 28, 9, 12, 18, base + r"\_dl\v_trees.png")
# barrels/crates band (top) + chests area (mid)
crop_abs(env, 23, 40, 0, 2, 18, base + r"\_dl\v_crates.png")
crop_abs(env, 34, 41, 8, 12, 18, base + r"\_dl\v_chests.png")
