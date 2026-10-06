#!/bin/zsh
# usage: focus/encode.sh preview   → output/preview_v3.mp4 (720×1280, from JPEG frames)
#        focus/encode.sh final     → output/UniEnter-FOCUS-Opus55-12s.mp4 (1080×1920, from PNG frames)
# RGB (full range sRGB) → YUV BT.709 limited is converted by the scale filter, then tagged to match.
cd "${0:A:h}"
CONV="scale=in_range=full:out_range=limited:out_color_matrix=bt709:flags=lanczos+accurate_rnd+full_chroma_int"
TAGS=(-x264-params "colorprim=bt709:transfer=bt709:colormatrix=bt709:range=tv" -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv)
if [[ "$1" == "final" ]]; then
  ffmpeg -loglevel error -y -framerate 30 -i output/final_frames/f_%05d.png -vf "$CONV,format=yuv420p" \
    -c:v libx264 -preset slow -crf 16 -profile:v high -pix_fmt yuv420p $TAGS -r 30 -an -movflags +faststart \
    output/UniEnter-FOCUS-Opus55-12s.mp4
else
  ffmpeg -loglevel error -y -framerate 30 -i output/preview_frames/f_%05d.jpg -vf "scale=720:1280:flags=lanczos,$CONV,format=yuv420p" \
    -c:v libx264 -preset medium -crf 22 -profile:v high -pix_fmt yuv420p $TAGS -r 30 -an -movflags +faststart \
    output/preview_v3.mp4
fi
