#!/usr/bin/env bash
# Rebuilds the 16:9 music edit from the original track (CC BY 4.0, Kevin MacLeod, incompetech.com).
# usage: tools/make_music.sh <out dir>   → <out>/builder.wav, <out>/builder_edit_16x9.wav (78.37 s, -14 LUFS)
# Edit: 5.62–62.47 s (one quiet bar, then the band at 1.98 s) + 93.66–115.2 s (break 3, the final section and the
# hard stop at 76.38 s), joined on the bar-12 downbeats of two identical sections with a 20 ms crossfade.
set -euo pipefail
O=${1:?out dir}; mkdir -p "$O"
curl -sS -m 120 -A 'Mozilla/5.0' -o "$O/The_Builder.mp3" "https://incompetech.com/music/royalty-free/mp3-royaltyfree/The%20Builder.mp3"
ffmpeg -v error -y -i "$O/The_Builder.mp3" -ar 48000 -ac 2 "$O/builder.wav"
ffmpeg -v error -y -i "$O/builder.wav" -filter_complex "[0:a]atrim=start=5.62:end=62.47,asetpts=PTS-STARTPTS[a];[0:a]atrim=start=93.66:end=115.2,asetpts=PTS-STARTPTS,afade=t=out:st=20.3:d=1.2[b];[a][b]acrossfade=d=0.02:c1=tri:c2=tri,loudnorm=I=-14:TP=-1.5:LRA=11[o]" -map "[o]" -ar 48000 "$O/builder_edit_16x9.wav"
ffprobe -v error -show_entries format=duration -of csv=p=0 "$O/builder_edit_16x9.wav"
