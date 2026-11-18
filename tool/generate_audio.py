#!/usr/bin/env python3
"""
words.txt dosyasındaki tüm kelimeler, örnek cümleler (en-US-AriaNeural)
ve Türkçe anlamlar (tr-TR-EmelNeural) için MP3 ses dosyalarını üretir.

Kullanım:
  /tmp/worm_tts_venv/bin/python tool/generate_audio.py
"""

import asyncio
import re
from pathlib import Path

import edge_tts

EN_VOICE = "en-US-AriaNeural"
TR_VOICE = "tr-TR-EmelNeural"

ROOT = Path(__file__).resolve().parent.parent
WORDS_FILE = ROOT / "words.txt"
WORDS_AUDIO_DIR = ROOT / "assets" / "audio" / "words"
SENTENCES_AUDIO_DIR = ROOT / "assets" / "audio" / "sentences"
TR_AUDIO_DIR = ROOT / "assets" / "audio" / "tr"


def safe_slug(text: str) -> str:
    return re.sub(r"[^a-z0-9_]", "_", text.strip().lower())


def parse_words(path: Path) -> list[tuple[str, str, str, str]]:
    items: list[tuple[str, str, str, str]] = []
    seen: set[str] = set()
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        first_comma = line.index(",") if "," in line else -1
        if first_comma <= 0:
            continue
        second_comma = line.index(",", first_comma + 1) if "," in line[first_comma + 1 :] else -1
        if second_comma <= first_comma + 1:
            continue
        word = line[:first_comma].strip()
        meanings_raw = line[first_comma + 1 : second_comma].strip()
        meanings_text = ", ".join(m.strip() for m in meanings_raw.split("#") if m.strip())
        sentence = line[second_comma + 1 :].strip()
        slug = safe_slug(word)
        if slug and slug not in seen:
            seen.add(slug)
            items.append((slug, word, meanings_text, sentence))
    return items


async def synthesize(sem: asyncio.Semaphore, text: str, voice: str, out_path: Path) -> None:
    if out_path.exists() and out_path.stat().st_size > 0:
        return
    async with sem:
        last_err: Exception | None = None
        for attempt in range(3):
            try:
                communicate = edge_tts.Communicate(text=text, voice=voice)
                await communicate.save(str(out_path))
                return
            except Exception as exc:
                last_err = exc
                await asyncio.sleep(0.8 * (attempt + 1))
        raise RuntimeError(f"Ses üretilemedi ({text}): {last_err}")


async def main() -> None:
    WORDS_AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    SENTENCES_AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    TR_AUDIO_DIR.mkdir(parents=True, exist_ok=True)

    items = parse_words(WORDS_FILE)
    print(f"Toplam {len(items)} kelime bulundu. Eksik ses dosyaları üretiliyor...")

    sem = asyncio.Semaphore(6)
    tasks = []
    for slug, word, meanings_text, sentence in items:
        tasks.append(synthesize(sem, word, EN_VOICE, WORDS_AUDIO_DIR / f"{slug}.mp3"))
        if sentence:
            tasks.append(synthesize(sem, sentence, EN_VOICE, SENTENCES_AUDIO_DIR / f"{slug}.mp3"))
        if meanings_text:
            tasks.append(synthesize(sem, meanings_text, TR_VOICE, TR_AUDIO_DIR / f"{slug}.mp3"))

    await asyncio.gather(*tasks)

    word_count = len(list(WORDS_AUDIO_DIR.glob("*.mp3")))
    sent_count = len(list(SENTENCES_AUDIO_DIR.glob("*.mp3")))
    tr_count = len(list(TR_AUDIO_DIR.glob("*.mp3")))
    total_bytes = (
        sum(p.stat().st_size for p in WORDS_AUDIO_DIR.glob("*.mp3"))
        + sum(p.stat().st_size for p in SENTENCES_AUDIO_DIR.glob("*.mp3"))
        + sum(p.stat().st_size for p in TR_AUDIO_DIR.glob("*.mp3"))
    )
    print(
        f"Tamamlandı: {word_count} kelime (EN) + {sent_count} cümle (EN) + {tr_count} anlam (TR) "
        f"(Toplam boyut: {total_bytes / (1024 * 1024):.2f} MB)"
    )


if __name__ == "__main__":
    asyncio.run(main())
