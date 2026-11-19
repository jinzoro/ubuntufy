#!/usr/bin/env python3
"""Generate original Ubuntu-inspired artwork for Ubuntuify Fedora.

Nothing here is copied from Ubuntu: wallpapers and the Plymouth logo are
generated from scratch from the Yaru colour palette. PNG writing uses only the
Python standard library (zlib/struct), so no external image tools are needed.

Usage:
    artwork.py wallpaper OUT WIDTH HEIGHT light|dark
    artwork.py plymouth-logo OUT SIZE
    artwork.py plymouth-background OUT WIDTH HEIGHT
"""

from __future__ import annotations

import math
import os
import random
import struct
import sys
import zlib

Color = tuple[int, int, int]

AUBERGINE = (44, 0, 30)
PLUM = (94, 39, 80)
ORANGE = (233, 84, 32)
WARM_LIGHT = (250, 244, 238)
LIGHT_PLUM = (232, 215, 226)
IVORY = (250, 246, 240)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def blend(base: Color, tint: Color, alpha: float) -> Color:
    if alpha <= 0:
        return base
    if alpha > 1:
        alpha = 1
    return (
        int(lerp(base[0], tint[0], alpha)),
        int(lerp(base[1], tint[1], alpha)),
        int(lerp(base[2], tint[2], alpha)),
    )


def write_png(path: str, width: int, height: int, pixels: bytearray, channels: int = 3) -> None:
    stride = width * channels
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter type: none
        raw.extend(pixels[y * stride : (y + 1) * stride])

    def chunk(tag: bytes, payload: bytes) -> bytes:
        return (
            struct.pack(">I", len(payload))
            + tag
            + payload
            + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
        )

    color_type = 2 if channels == 3 else 6
    header = struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0)
    data = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 6))
        + chunk(b"IEND", b"")
    )
    directory = os.path.dirname(os.path.abspath(path))
    os.makedirs(directory, exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(data)


def glow_table(steps: int = 512) -> list[int]:
    """Alpha lookup for a smooth falloff, indexed by (1 - d2/r2)."""
    table = []
    for index in range(steps):
        t = index / (steps - 1)
        table.append(int(255 * (t * t * (3 - 2 * t))))
    return table


def apply_glow(
    pixels: bytearray,
    width: int,
    height: int,
    cx: float,
    cy: float,
    radius: float,
    color: Color,
    max_alpha: float,
    table: list[int],
) -> None:
    """Add a bounded radial glow to the pixel buffer (in place)."""
    x0 = max(0, int(cx - radius))
    x1 = min(width, int(cx + radius) + 1)
    y0 = max(0, int(cy - radius))
    y1 = min(height, int(cy + radius) + 1)
    radius_sq = radius * radius
    steps = len(table) - 1

    for y in range(y0, y1):
        dy = y - cy
        row = y * width * 3
        for x in range(x0, x1):
            dx = x - cx
            d2 = dx * dx + dy * dy
            if d2 > radius_sq:
                continue
            index = int(steps * (1.0 - d2 / radius_sq))
            alpha = table[index] / 255.0 * max_alpha
            if alpha <= 0.002:
                continue
            offset = row + x * 3
            pixels[offset], pixels[offset + 1], pixels[offset + 2] = blend(
                (pixels[offset], pixels[offset + 1], pixels[offset + 2]), color, alpha
            )


def generate_wallpaper(path: str, width: int, height: int, mode: str) -> None:
    if mode == "light":
        top, bottom = WARM_LIGHT, LIGHT_PLUM
        primary, secondary = ORANGE, PLUM
        max_alpha = 0.22
    else:
        top, bottom = AUBERGINE, PLUM
        primary, secondary = ORANGE, (150, 60, 100)
        max_alpha = 0.38

    pixels = bytearray(width * height * 3)
    rng = random.Random(20261119)
    inv_w = 1.0 / max(1, width - 1)
    inv_h = 1.0 / max(1, height - 1)

    for y in range(height):
        t_row = y * inv_h
        row = y * width * 3
        for x in range(width):
            t = 0.28 * (x * inv_w) + 0.72 * t_row
            base = (
                int(lerp(top[0], bottom[0], t)),
                int(lerp(top[1], bottom[1], t)),
                int(lerp(top[2], bottom[2], t)),
            )
            # Deterministic dithering hides 8-bit banding in the gradient.
            level = rng.randint(-2, 2)
            offset = row + x * 3
            pixels[offset] = max(0, min(255, base[0] + level))
            pixels[offset + 1] = max(0, min(255, base[1] + level))
            pixels[offset + 2] = max(0, min(255, base[2] + level))

    table = glow_table()
    apply_glow(pixels, width, height, width * 0.78, height * 0.86, min(width, height) * 0.72, primary, max_alpha, table)
    apply_glow(pixels, width, height, width * 0.10, height * 0.08, min(width, height) * 0.62, secondary, max_alpha * 0.8, table)
    apply_glow(pixels, width, height, width * 0.30, height * 0.72, min(width, height) * 0.45, primary, max_alpha * 0.35, table)

    write_png(path, width, height, pixels)


def generate_logo(path: str, size: int) -> None:
    """A simple original 'U' mark in Ubuntu colours, with transparency."""
    pixels = bytearray(size * size * 4)  # RGBA, fully transparent by default

    center_x = size / 2
    outer = size * 0.30
    inner = size * 0.21
    band_bottom = size * 0.58

    for y in range(size):
        for x in range(size):
            dx = x - center_x
            px = dx * dx
            py = (y - band_bottom) ** 2
            inside_ring = False
            if y >= band_bottom:
                distance_sq = px + py
                inside_ring = inner * inner <= distance_sq <= outer * outer
            else:
                # two vertical stems that join the half ring
                left = abs(dx + inner + (outer - inner) / 2) <= (outer - inner) / 2
                right = abs(dx - inner - (outer - inner) / 2) <= (outer - inner) / 2
                if y >= size * 0.20 and (left or right):
                    inside_ring = True
            if not inside_ring:
                continue
            offset = (y * size + x) * 4
            pixels[offset] = IVORY[0]
            pixels[offset + 1] = IVORY[1]
            pixels[offset + 2] = IVORY[2]
            pixels[offset + 3] = 255

    write_png(path, size, size, pixels, channels=4)


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    command = argv[0]
    output = argv[1]

    if command == "wallpaper":
        if len(argv) != 5:
            print(__doc__, file=sys.stderr)
            return 2
        width, height = int(argv[2]), int(argv[3])
        mode = argv[4]
        if mode not in ("light", "dark"):
            print("artwork: mode must be light or dark", file=sys.stderr)
            return 2
        generate_wallpaper(output, width, height, mode)
        return 0

    if command == "plymouth-logo":
        if len(argv) != 3:
            print(__doc__, file=sys.stderr)
            return 2
        generate_logo(output, int(argv[2]))
        return 0

    if command == "plymouth-background":
        if len(argv) != 4:
            print(__doc__, file=sys.stderr)
            return 2
        generate_wallpaper(output, int(argv[2]), int(argv[3]), "dark")
        return 0

    print(f"artwork: unknown command {command}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
