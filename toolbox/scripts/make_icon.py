"""Generate the Windows app icon. Requires Pillow (python -m pip install pillow)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
ROOT = Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "resources"


def lerp(start: tuple[int, int, int], end: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(round(a + (b - a) * t) for a, b in zip(start, end))


def make_background() -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    pixels = image.load()
    start = (124, 156, 255)
    end = (76, 111, 232)
    for y in range(SIZE):
        for x in range(SIZE):
            diagonal = (x * 0.42 + y * 0.58) / SIZE
            t = min(max(diagonal, 0.0), 1.0)
            color = lerp(start, end, t)
            pixels[x, y] = (*color, 255)

    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=232, fill=255)
    image.putalpha(mask)

    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse([-260, -360, 720, 500], fill=(255, 255, 255, 46))
    glow = glow.filter(ImageFilter.GaussianBlur(110))
    glow.putalpha(Image.composite(glow.getchannel("A"), Image.new("L", (SIZE, SIZE), 0), mask))
    image = Image.alpha_composite(image, glow)
    return image


def make_toolbox() -> Image.Image:
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    # Handle
    draw.rounded_rectangle([378, 292, 646, 530], radius=96, outline=(255, 255, 255, 255), width=42)

    # Body
    draw.rounded_rectangle([222, 430, 802, 748], radius=68, fill=(255, 255, 255, 255))

    # Latch
    draw.rounded_rectangle([472, 568, 552, 626], radius=16, fill=(107, 128, 245, 255))
    draw.rounded_rectangle([494, 548, 530, 576], radius=12, fill=(107, 128, 245, 255))

    # Bottom seam
    draw.rounded_rectangle([282, 666, 742, 690], radius=12, fill=(107, 128, 245, 255))
    return layer


def main() -> None:
    RESOURCES.mkdir(parents=True, exist_ok=True)
    image = make_background()
    image = Image.alpha_composite(image, make_toolbox())
    image.save(RESOURCES / "icon.png")

    ico_source = image.resize((256, 256), Image.LANCZOS)
    ico_source.save(
        RESOURCES / "icon.ico",
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
    print(f"Wrote {RESOURCES / 'icon.png'} and {RESOURCES / 'icon.ico'}")


if __name__ == "__main__":
    main()
