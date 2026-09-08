# UniEnter app icon

Flat macOS-style rounded-square tile (Claude/Obsidian-like), reusing the same
return-arrow "↵" glyph geometry as `site/public/favicon.svg` — no photo
texture, no bevels, no drop shadows.

- **Variant A (mono)**: white tile `#ffffff`, ink glyph `#37352f`. Matches the
  LP favicon exactly. Preview: `preview-a-1024.png`.
- **Variant B (accent)**: teal tile `#0f7b6c` with a very subtle top-to-bottom
  lightening (~6% mix toward white at the top, flat-looking), white glyph
  `#ffffff`. **This is the variant installed into the app.**
  Preview: `preview-b-1024.png`.

Source SVGs (`icon-a.svg`, `icon-b.svg`) are design references at 1024x1024
showing the exact geometry. The installed PNGs are rendered by
`render.swift` directly with CoreGraphics for pixel-exact control (no SVG
rasterizer was available on this machine — no `rsvg-convert`/`magick`/
`inkscape`).

## Geometry

Standard macOS icon grid, computed at any canvas size:

- Tile: rounded square, `824/1024` of the canvas, centered (`100px` margin at
  1024x1024).
- Corner radius: `185/1024` of the canvas.
- Glyph: the favicon's 64x64-box path (`M45 21 V35 H19` + arrowhead
  `M27 27 19 35 27 43`, stroke 6, round caps/joins), scaled by `tileSize/64`
  and centered in the tile. Stroke scales proportionally (6/64 of the tile,
  ≈77px at an 824px tile).
- At `<=32px` canvas sizes, the glyph and stroke are boosted slightly
  (glyph x1.15/stroke x1.30 at `<=32px`, x1.25/x1.45 at `<=16px`) so the
  arrow stays legible at menu-bar/dock scale.

## Re-rendering

No dependencies beyond the Swift toolchain (Xcode command line tools).

```bash
cd design/app-icon

# One PNG:
swift render.swift <canvasSize> <tileHex> <glyphHex> <outPath> [gradient: 0|1]

# All installed sizes (variant B, accent, into the asset catalog):
APPICON=../../UniEnter/Assets.xcassets/AppIcon.appiconset
for sz in 16 32 64 128 256 512 1024; do
  swift render.swift "$sz" "#0f7b6c" "#ffffff" "$APPICON/icon_${sz}.png" 1
done

# 1024 previews of both variants:
swift render.swift 1024 "#ffffff" "#37352f" preview-a-1024.png 0
swift render.swift 1024 "#0f7b6c" "#ffffff" preview-b-1024.png 1
```

## Switching variants

To install variant A (mono) instead of B, re-run the loop above with
`"#ffffff" "#37352f" ... 0` (no gradient) in place of the teal/white/gradient
args. `Contents.json` filenames/sizes don't need to change — only the pixel
content of each `icon_*.png` does.

## Files

| File | Purpose |
| --- | --- |
| `icon-a.svg` | Variant A source geometry (reference) |
| `icon-b.svg` | Variant B source geometry (reference) |
| `render.swift` | CoreGraphics rasterizer, any size/colors/gradient |
| `preview-a-1024.png` | Variant A full-size preview |
| `preview-b-1024.png` | Variant B full-size preview (= installed `icon_1024.png`) |
