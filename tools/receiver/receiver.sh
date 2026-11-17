#!/usr/bin/env bash
# CarMedia PoC receiver — runs on any machine with FFmpeg on the same LAN as
# the iPhone. It accepts the TCP H.264 Annex-B stream sent by the CarMedia
# Broadcast extension and plays it (or dumps it to stream.h264).
#
#   ./receiver.sh play      # ffplay window (default)
#   ./receiver.sh record    # saves stream.h264 (raw, decodable by VLC/FFmpeg)
#
# Then in the CarMedia app: Espelhamento > receptor = <this machine's IP> : 5555,
# start the system broadcast picker. Nothing is persisted on the phone.
set -euo pipefail
PORT="${PORT:-5555}"
MODE="${1:-play}"

if [ "$MODE" = record ]; then
  echo "listening :$PORT -> stream.h264 (Ctrl-C to stop)"
  nc -l -p "$PORT" > stream.h264 || ncat -l "$PORT" > stream.h264
else
  echo "listening :$PORT -> ffplay"
  if nc -h 2>&1 | grep -q '\-l'; then NC="nc -l -p $PORT"; else NC="ncat -l $PORT"; fi
  $NC | ffplay -nodisp -autoexit -loglevel info -f h264 - 2>/dev/null \
    || { echo "install ffmpeg (provides ffplay) or use: $0 record"; exit 1; }
fi
