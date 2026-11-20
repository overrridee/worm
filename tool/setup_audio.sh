#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_FILE="$ROOT_DIR/assets/worm.db"
AUDIO_DIR="$ROOT_DIR/assets/audio"
STAMP_FILE="$AUDIO_DIR/.stamp"
VENV_DIR="$ROOT_DIR/.venv_tts"

mkdir -p "$AUDIO_DIR/words" "$AUDIO_DIR/sentences" "$AUDIO_DIR/tr"

# Eğer stamp dosyası worm.db'den yeniyse ve ses klasörleri doluysa tekrar çalıştırma.
if [[ -f "$STAMP_FILE" && "$STAMP_FILE" -nt "$DB_FILE" ]]; then
  if compgen -G "$AUDIO_DIR/words/*.mp3" > /dev/null && \
     compgen -G "$AUDIO_DIR/sentences/*.mp3" > /dev/null && \
     compgen -G "$AUDIO_DIR/tr/*.mp3" > /dev/null; then
    echo "[Worm Audio] Ses dosyaları güncel, atlanıyor."
    exit 0
  fi
fi

if ! command -v python3 > /dev/null 2>&1; then
  echo "[Worm Audio] Uyarı: python3 bulunamadı, ses dosyaları üretilemedi (TTS fallback kullanılacak)."
  exit 0
fi

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  echo "[Worm Audio] Sanal ortam (.venv_tts) hazırlanıyor..."
  python3 -m venv "$VENV_DIR"
fi

if ! "$VENV_DIR/bin/python" -c "import edge_tts" > /dev/null 2>&1; then
  echo "[Worm Audio] edge-tts kuruluyor..."
  "$VENV_DIR/bin/pip" install --quiet edge-tts
fi

echo "[Worm Audio] words.txt için ses dosyaları üretiliyor..."
"$VENV_DIR/bin/python" "$ROOT_DIR/tool/generate_audio.py"
touch "$STAMP_FILE"
