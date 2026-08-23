#!/usr/bin/env python3
"""Bakes the in-game greyscale textures in assets/textures/ from the source assets.

The game is monochrome, dithered to 5 levels at 0.4x resolution, so the 2048^2 RGB albedos
embedded in the Tripo .glb exports are wasted; this writes small greyscale PNGs instead and
lifts the very dark ones so they survive the black crush. The materials in the scenes point
at these files. Re-run after replacing a .glb or the floor source:

    tools/bake_textures.py                 # bake everything
    tools/bake_textures.py weeper floor    # bake named entries only

Names: weeper, mourner, lament, vesper, glutton, gem, dagger, hand, floor.

ImageMagick 7 (`magick`) does the decode/encode; every pixel operation happens here on raw
8-bit grey bytes so a re-run is byte-for-byte reproducible (no repeated re-quantisation and
no date chunks in the PNGs). Only the Python standard library is used.
"""
from __future__ import annotations

import json
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODELS = ROOT / "assets" / "models"
SOURCE = ROOT / "assets" / "source"
OUT = ROOT / "assets" / "textures"

GLTF_MAGIC = 0x46546C67
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942

# name -> (source, size, target mean luminance or None to keep the source levels)
MODEL_TEXTURES = {
    "weeper": ("weeper.glb", 1024, 0.50),
    "mourner": ("mourner.glb", 1024, 0.40),
    "lament": ("lament.glb", 1024, 0.38),
    "vesper": ("vesper.glb", 1024, None),  # near-black rags with white highlights by design
    "glutton": ("glutton.glb", 1024, 0.45),
    "gem": ("gem.glb", 512, None),
    "dagger": ("dagger-projectile.glb", 512, None),
    "hand": ("hand.glb", 1024, None),
}
FLOOR = ("floor1.jpg", 1024, 0.42)


def magick(*args: str) -> bytes:
    if shutil.which("magick") is None:
        raise SystemExit("error: ImageMagick 7 is required (`magick` not found on PATH)")
    try:
        return subprocess.run(["magick", *args], check=True, capture_output=True).stdout
    except subprocess.CalledProcessError as err:
        raise SystemExit("error: magick %s failed:\n%s" % (" ".join(args), err.stderr.decode(errors="replace")))


def to_grey(source: Path | bytes, size: int, suffix: str = "") -> bytes:
    """Decodes an image (path or in-memory bytes) to `size`^2 raw 8-bit grey pixels."""
    with tempfile.TemporaryDirectory() as tmp:
        if isinstance(source, bytes):
            src = Path(tmp) / ("src" + suffix)
            src.write_bytes(source)
        else:
            src = source
        raw = magick(str(src), "-colorspace", "Gray", "-resize", "%dx%d!" % (size, size), "-depth", "8", "gray:-")
    if len(raw) != size * size:
        raise SystemExit("error: %s decoded to %d bytes, expected %d" % (source, len(raw), size * size))
    return raw


def write_png(pixels: bytes, size: int, out: Path) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        raw = Path(tmp) / "out.gray"
        raw.write_bytes(pixels)
        magick("-size", "%dx%d" % (size, size), "-depth", "8", "gray:%s" % raw,
               "-define", "png:color-type=0", "-strip", str(out))


def mean_luma(pixels: bytes) -> float:
    return sum(pixels) / len(pixels) / 255.0


def embedded_albedo(glb: Path) -> tuple[bytes, str]:
    """Returns (bytes, file suffix) of the albedo image embedded in a .glb."""
    data = glb.read_bytes()
    if len(data) < 12 or struct.unpack_from("<III", data, 0)[0] != GLTF_MAGIC:
        raise SystemExit("error: %s is not a binary glTF" % glb)
    offset, doc, binary = 12, None, b""
    while offset + 8 <= len(data):
        chunk_len, chunk_type = struct.unpack_from("<II", data, offset)
        chunk = data[offset + 8 : offset + 8 + chunk_len]
        if len(chunk) != chunk_len:
            raise SystemExit("error: %s is truncated" % glb)
        if chunk_type == CHUNK_JSON:
            doc = json.loads(chunk)
        elif chunk_type == CHUNK_BIN:
            binary = chunk
        offset += 8 + chunk_len
    if doc is None or not doc.get("images"):
        raise SystemExit("error: %s embeds no image" % glb)
    # Prefer the image the first material actually samples; fall back to the first one.
    index = 0
    try:
        texture = doc["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
        index = doc["textures"][texture]["source"]
    except (KeyError, IndexError):
        pass
    image = doc["images"][index]
    if "bufferView" not in image:
        raise SystemExit("error: %s image %d is a URI reference, not embedded" % (glb, index))
    view = doc["bufferViews"][image["bufferView"]]
    start = view.get("byteOffset", 0)
    payload = binary[start : start + view["byteLength"]]
    if len(payload) != view["byteLength"]:
        raise SystemExit("error: %s image %d runs past the binary chunk" % (glb, index))
    return payload, ".jpg" if image.get("mimeType") == "image/jpeg" else ".png"


def lift_to_mean(pixels: bytes, target: float) -> bytes:
    """Applies the gamma that puts the mean luminance on `target`, in one pass through a LUT."""
    histogram = [0] * 256
    for value in pixels:
        histogram[value] += 1
    total = len(pixels)

    def mean_for(gamma: float) -> float:
        return sum(count * (i / 255.0) ** (1.0 / gamma) for i, count in enumerate(histogram) if count) / total

    low, high = 0.25, 4.0
    if not mean_for(low) <= target <= mean_for(high):
        return pixels  # target out of reach; leave the source levels alone
    for _ in range(40):
        mid = (low + high) / 2.0
        if mean_for(mid) < target:
            low = mid
        else:
            high = mid
    gamma = (low + high) / 2.0
    lut = bytes(min(255, max(0, round(255.0 * (i / 255.0) ** (1.0 / gamma)))) for i in range(256))
    return pixels.translate(lut)


def _roll_x(pixels: bytes, size: int, shift: int) -> bytes:
    out = bytearray(size * size)
    for y in range(size):
        row = pixels[y * size : (y + 1) * size]
        out[y * size : (y + 1) * size] = row[shift:] + row[:shift]
    return bytes(out)


def _transpose(pixels: bytes, size: int) -> bytes:
    out = bytearray(size * size)
    for y in range(size):
        out[y::size] = pixels[y * size : (y + 1) * size]
    return bytes(out)


def _band(size: int) -> list[float]:
    """Smoothstep weights: 1 across the middle seam, 0 well before the tile border."""
    inner, outer = size // 16, size // 5
    weights = []
    for x in range(size):
        distance = abs(x - size // 2)
        if distance <= inner:
            weights.append(1.0)
        elif distance >= outer:
            weights.append(0.0)
        else:
            t = (outer - distance) / float(outer - inner)
            weights.append(t * t * (3.0 - 2.0 * t))
    return weights


def _patch_seam(pixels: bytes, size: int, weights: list[float]) -> bytes:
    """Rolls the tile half a turn (moving the mismatched borders to the middle) and cross-fades a
    quarter-turn copy over the resulting middle seam. The band never reaches the tile border, so
    the border stays exactly the rolled — and therefore continuous — pixels."""
    rolled = _roll_x(pixels, size, size // 2)
    patch = _roll_x(rolled, size, size // 4)
    out = bytearray(size * size)
    for x, weight in enumerate(weights):
        if weight <= 0.0:
            out[x::size] = rolled[x::size]
        elif weight >= 1.0:
            out[x::size] = patch[x::size]
        else:
            keep = 1.0 - weight
            out[x::size] = bytes(
                round(a * keep + b * weight) for a, b in zip(rolled[x::size], patch[x::size])
            )
    return bytes(out)


def make_seamless(pixels: bytes, size: int) -> bytes:
    """Makes a tile wrap in both axes: patch the vertical seam, then the horizontal one on the
    transpose (rolling and blending whole rows keeps the columns' continuity intact)."""
    weights = _band(size)
    horizontal = _patch_seam(pixels, size, weights)
    vertical = _patch_seam(_transpose(horizontal, size), size, weights)
    return _transpose(vertical, size)


def bake_model(name: str, source: str, size: int, target: float | None) -> None:
    payload, suffix = embedded_albedo(MODELS / source)
    pixels = to_grey(payload, size, suffix)
    if target is not None:
        pixels = lift_to_mean(pixels, target)
    out = OUT / ("%s.png" % name)
    write_png(pixels, size, out)
    print("%s  %d^2  mean=%.3f" % (out.relative_to(ROOT), size, mean_luma(pixels)))


def bake_floor(source: str, size: int, target: float) -> None:
    pixels = lift_to_mean(make_seamless(to_grey(SOURCE / source, size), size), target)
    out = OUT / "floor_bone.png"
    write_png(pixels, size, out)
    print("%s  %d^2  mean=%.3f (seamless)" % (out.relative_to(ROOT), size, mean_luma(pixels)))


def main(argv: list[str]) -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    known = set(MODEL_TEXTURES) | {"floor"}
    wanted = set(argv) or known
    unknown = wanted - known
    if unknown:
        raise SystemExit("error: unknown texture(s): %s\nknown: %s"
                         % (", ".join(sorted(unknown)), ", ".join(sorted(known))))
    for name, (source, size, target) in MODEL_TEXTURES.items():
        if name in wanted:
            bake_model(name, source, size, target)
    if "floor" in wanted:
        bake_floor(*FLOOR)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
