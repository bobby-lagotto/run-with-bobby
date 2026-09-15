#!/usr/bin/env python3
"""Compress brand and screenshot assets for the GitHub Pages landing."""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "assets"
OUT.mkdir(parents=True, exist_ok=True)

SCREENS = [
    "01-coach-locale.png",
    "02-privacy.png",
    "03-offline.png",
    "04-gratis.png",
    "05-salute.png",
    "06-chat.png",
    "07-oggi.png",
    "08-piani.png",
]


def save_jpeg(image: Image.Image, destination: Path, size: tuple[int, int] | None = None, quality: int = 82) -> None:
    rgb = image.convert("RGB")
    if size:
        rgb.thumbnail(size, Image.Resampling.LANCZOS)
    destination.parent.mkdir(parents=True, exist_ok=True)
    rgb.save(destination, format="JPEG", quality=quality, optimize=True)
    print(f"wrote {destination} {rgb.size}")


def main() -> None:
    hero = Image.open(ROOT / "run_wall_bobby.png")
    save_jpeg(hero, OUT / "hero.jpg", size=(2000, 1200), quality=84)

    icon = Image.open(ROOT / "RunWithBobby/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png")
    icon.convert("RGBA").resize((256, 256), Image.Resampling.LANCZOS).save(OUT / "icon.png", format="PNG", optimize=True)
    print(f"wrote {OUT / 'icon.png'}")

    source_dir = ROOT / "AppStore" / "screenshots" / "iphone-6.5"
    for index, name in enumerate(SCREENS, start=1):
        image = Image.open(source_dir / name)
        save_jpeg(image, OUT / f"screen-{index:02d}.jpg", size=(720, 1560), quality=80)


if __name__ == "__main__":
    main()
