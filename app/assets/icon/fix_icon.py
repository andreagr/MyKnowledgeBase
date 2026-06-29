"""Ensure app_icon.png is a full-bleed 1024x1024 square for Windows/web icons.

AI-generated icons are often landscape with white side padding. Run after
replacing app_icon.png:

    python assets/icon/fix_icon.py
    dart run flutter_launcher_icons
"""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image

BRAND_BLUE = (0, 113, 227)
ICON_PATH = Path(__file__).with_name("app_icon.png")
OUTPUT_SIZE = 1024


def _is_padding_white(r: int, g: int, b: int) -> bool:
    return r > 235 and g > 235 and b > 235


def _center_square(image: Image.Image) -> Image.Image:
    width, height = image.size
    side = min(width, height)
    left = (width - side) // 2
    top = (height - side) // 2
    return image.crop((left, top, left + side, top + side))


def _fill_exterior_white(crop: Image.Image) -> None:
    pixels = crop.load()
    size = crop.size[0]
    queue: deque[tuple[int, int]] = deque()
    seen: set[tuple[int, int]] = set()

    for x in range(size):
        for y in (0, size - 1):
            if _is_padding_white(*pixels[x, y]):
                queue.append((x, y))
    for y in range(size):
        for x in (0, size - 1):
            if _is_padding_white(*pixels[x, y]):
                queue.append((x, y))

    while queue:
        x, y = queue.popleft()
        if (x, y) in seen or not (0 <= x < size and 0 <= y < size):
            continue
        if not _is_padding_white(*pixels[x, y]):
            continue
        seen.add((x, y))
        pixels[x, y] = BRAND_BLUE
        queue.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])


def main() -> None:
    image = Image.open(ICON_PATH).convert("RGB")
    square = _center_square(image)
    _fill_exterior_white(square)
    output = square.resize((OUTPUT_SIZE, OUTPUT_SIZE), Image.Resampling.LANCZOS)
    output.save(ICON_PATH, format="PNG", optimize=True)
    print(f"Updated {ICON_PATH} -> {output.size}")


if __name__ == "__main__":
    main()
