#!/usr/bin/env python3
"""Compose 1320x2868 App Store screenshots from 9:16 Wimmelbild art."""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "AppStore" / "screenshots" / "raw"
OUT_DIR_69 = ROOT / "AppStore" / "screenshots" / "iphone-6.9"
OUT_DIR_65 = ROOT / "AppStore" / "screenshots" / "iphone-6.5"
OUT_DIR = OUT_DIR_69

TARGET_W = 1320
TARGET_H = 2868
SIZE_65 = (1284, 2778)
GRASS = (92, 158, 74)
CHARCOAL = (44, 24, 16)
RED = (217, 69, 69)
CREAM = (251, 249, 247)
WARM_GRAY = (140, 123, 115)

SLIDES = [
    {
        "src": "01-coach-locale-raw.png",
        "dst": "01-coach-locale.png",
        "kicker": "RUN WITH BOBBY",
        "title": "Il coach vive\nsul tuo iPhone",
        "subtitle": "L'agente gira on-device con MLX.",
    },
    {
        "src": "02-privacy-raw.png",
        "dst": "02-privacy.png",
        "kicker": "MODALITÀ LOCALE",
        "title": "I dati restano\nsul telefono",
        "subtitle": "Niente cloud, a meno che lo attivi tu.",
    },
    {
        "src": "03-offline-raw.png",
        "dst": "03-offline.png",
        "kicker": "SENZA RETE",
        "title": "Funziona anche\noffline",
        "subtitle": "Dopo il download del modello, Bobby allena senza segnale.",
    },
    {
        "src": "04-gratis-raw.png",
        "dst": "04-gratis.png",
        "kicker": "SENZA PAYWALL",
        "title": "Gratis, senza\nabbonamento",
        "subtitle": "Il coaching locale non chiede API key né StoreKit.",
    },
    {
        "src": "05-salute-raw.png",
        "dst": "05-salute.png",
        "kicker": "APPLE HEALTH",
        "title": "Salute e km\nrestano sul device",
        "subtitle": "HealthKit letto sul telefono, scritto solo se registri una corsa.",
    },
]


def load_font(size: int, weight: str = "regular") -> ImageFont.FreeTypeFont:
    candidates = []
    if weight == "bold":
        candidates.extend(
            [
                "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
                "/Library/Fonts/Arial Bold.ttf",
                "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
                "/System/Library/Fonts/Helvetica.ttc",
            ]
        )
    else:
        candidates.extend(
            [
                "/System/Library/Fonts/Supplemental/Arial.ttf",
                "/Library/Fonts/Arial.ttf",
                "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
                "/System/Library/Fonts/Helvetica.ttc",
            ]
        )
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size=size, index=0)
            except OSError:
                continue
    return ImageFont.load_default()


def flatten_rgb(image: Image.Image) -> Image.Image:
    if image.mode == "RGB":
        return image
    background = Image.new("RGB", image.size, (168, 216, 240))
    if image.mode in ("RGBA", "LA"):
        background.paste(image, mask=image.split()[-1])
        return background
    return image.convert("RGB")


def fit_canvas(image: Image.Image) -> Image.Image:
    image = flatten_rgb(image)
    scale = max(TARGET_W / image.width, TARGET_H / image.height)
    resized = image.resize(
        (max(1, int(round(image.width * scale))), max(1, int(round(image.height * scale)))),
        Image.Resampling.LANCZOS,
    )
    left = max(0, (resized.width - TARGET_W) // 2)
    top = max(0, (resized.height - TARGET_H) // 8)
    return resized.crop((left, top, left + TARGET_W, top + TARGET_H))


def wrap_text(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, max_width: int) -> str:
    if "\n" in text:
        return text
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        trial = word if not current else f"{current} {word}"
        if draw.textbbox((0, 0), trial, font=font)[2] <= max_width:
            current = trial
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return "\n".join(lines)


def draw_overlay(canvas: Image.Image, kicker: str, title: str, subtitle: str) -> Image.Image:
    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    kicker_font = load_font(28, "bold")
    title_font = load_font(64, "bold")
    subtitle_font = load_font(30, "regular")

    margin = 72
    max_width = TARGET_W - margin * 2
    title = wrap_text(draw, title, title_font, max_width)
    subtitle = wrap_text(draw, subtitle, subtitle_font, max_width)

    kicker_box = draw.textbbox((0, 0), kicker, font=kicker_font)
    title_box = draw.textbbox((0, 0), title, font=title_font, spacing=8)
    subtitle_box = draw.textbbox((0, 0), subtitle, font=subtitle_font, spacing=6)

    content_h = (
        (kicker_box[3] - kicker_box[1])
        + 18
        + (title_box[3] - title_box[1])
        + 22
        + (subtitle_box[3] - subtitle_box[1])
    )
    pad_y = 36
    pad_x = 40
    card_w = max_width + pad_x * 2
    card_h = content_h + pad_y * 2
    card_x = (TARGET_W - card_w) // 2
    card_y = 78

    card = Image.new("RGBA", (card_w, card_h), (0, 0, 0, 0))
    card_draw = ImageDraw.Draw(card)
    card_draw.rounded_rectangle(
        (0, 0, card_w - 1, card_h - 1),
        radius=36,
        fill=(*CREAM, 230),
    )
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (card_x + 6, card_y + 10, card_x + card_w + 6, card_y + card_h + 10),
        radius=36,
        fill=(44, 24, 16, 50),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(12))
    overlay = Image.alpha_composite(overlay, shadow)
    overlay.paste(card, (card_x, card_y), card)

    text_draw = ImageDraw.Draw(overlay)
    x = card_x + pad_x
    y = card_y + pad_y
    text_draw.text((x, y), kicker, font=kicker_font, fill=RED)
    y += (kicker_box[3] - kicker_box[1]) + 18
    text_draw.multiline_text((x, y), title, font=title_font, fill=CHARCOAL, spacing=8)
    y += (title_box[3] - title_box[1]) + 22
    text_draw.multiline_text((x, y), subtitle, font=subtitle_font, fill=WARM_GRAY, spacing=6)

    return Image.alpha_composite(canvas.convert("RGBA"), overlay).convert("RGB")


def save_appstore_png(image: Image.Image, destination: Path) -> None:
    rgb = flatten_rgb(image)
    destination.parent.mkdir(parents=True, exist_ok=True)
    rgb.save(destination, format="PNG", optimize=True)
    print(f"wrote {destination} {rgb.size} {rgb.mode}")


def export_display_sizes(image: Image.Image, filename: str) -> None:
    image_69 = flatten_rgb(image)
    if image_69.size != (TARGET_W, TARGET_H):
        image_69 = image_69.resize((TARGET_W, TARGET_H), Image.Resampling.LANCZOS)
    save_appstore_png(image_69, OUT_DIR_69 / filename)
    image_65 = image_69.resize(SIZE_65, Image.Resampling.LANCZOS)
    save_appstore_png(image_65, OUT_DIR_65 / filename)


def resize_ui_screenshot(path: Path, destination: Path) -> None:
    export_display_sizes(Image.open(path), destination.name)


def main() -> None:
    OUT_DIR_69.mkdir(parents=True, exist_ok=True)
    OUT_DIR_65.mkdir(parents=True, exist_ok=True)
    for slide in SLIDES:
        source = RAW_DIR / slide["src"]
        if not source.exists():
            raise FileNotFoundError(source)
        canvas = fit_canvas(Image.open(source))
        final = draw_overlay(canvas, slide["kicker"], slide["title"], slide["subtitle"])
        export_display_sizes(final, slide["dst"])


if __name__ == "__main__":
    main()
