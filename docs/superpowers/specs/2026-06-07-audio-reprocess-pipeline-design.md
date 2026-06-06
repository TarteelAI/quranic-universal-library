# Audio Reprocess Pipeline — Design

**Date:** 2026-06-07
**Status:** Approved (approach A)

## Problem

`rake audio:find_suspicious_durations` surfaced recitations whose audio was cut
off — the MP3 on the CDN and the stored `Audio::Segment` rows are truncated,
while the full-length WAV is still available from the QUL API. For each affected
reciter+surah we need to:

1. Download the full WAV from the QUL API.
2. Re-encode it to MP3 (re-uploaded to the CDN manually by the user).
3. Regenerate word-level segments from the WAV.

Segment generation is a two-step process: transcribe the audio (Tarteel STT
websocket), reconcile/fix the transcript against the canonical Quran text, then
run forced alignment (ctc-forced-aligner) to get precise word timestamps.

Today this is done by hand across two Colab notebooks
(`tools/transcribe_surah.py`, `tools/alignment.py`) plus the existing Ruby
reconciler (`lib/surah_transcript_aligner.rb` + `lib/transcript_splitter.rb`),
which operate on a whole reciter (114 surahs) using raw-text transcripts.

## Goal

A single rake task, parameterized by `RECITER=<id> SURAH=<n>`, that automates
everything except the manual MP3 upload and hands back two artifacts:

- the re-encoded **MP3** file, and
- the **flat forced-alignment JSON** (`[{word, start, end}]` per surah, matching
  the current `alignment.py` output 1:1).

Constraints (from the user):
- Do **not** modify existing code; implement a new, isolated pipeline.
- Reuse the existing reconciler (`SurahTranscriptAligner`) rather than
  reimplementing reconciliation.
- Alignment runs locally on CPU by default, but the Python alignment step must
  be a self-contained script that also runs unchanged on a GPU box / Colab with
  the same inputs (corrected transcript + WAV).

## Non-goals

- Writing regenerated segments back into the `Audio::Segment` table. The task
  only produces the alignment JSON + MP3; DB import is a later, separate step.
- Uploading the MP3 to the CDN (done manually).
- Batch processing many reciters/surahs in one invocation (single reciter+surah
  per run; looping can be layered on later).

## Architecture

A thin orchestrator rake task `audio:reprocess` runs five isolated stages. Each
stage has one job, reads/writes well-defined paths, and can be run or inspected
independently.

```
RECITER, SURAH
   │
   ▼
1. WavDownloader (Ruby)
   QUL API → data/audio/{reciter}/wav/{NNN}.wav
   │
   ▼
2. Mp3Encoder (Ruby, ffmpeg)
   wav → data/audio/{reciter}/mp3/{NNN}.mp3          ◄── DELIVERABLE 1
   │
   ▼
3. SttTranscriber (Ruby → Python subprocess)
   tools/pipeline/transcribe.py (websocket STT)
   wav → data/audio/{reciter}/transcript/{surah}.json   ({wordsList:[{word,startTime,endTime,confidence}]})
   │
   ▼
4. Reconciler (Ruby, reuses SurahTranscriptAligner verbatim)
   wordsList → data/stt/{reciter}/by_surah/{surah}.txt (joined words)
   SurahTranscriptAligner#export_aligned_ayahs / #export_fixed_stt
   → data/stt/{reciter}/fixed/by_surah/{surah}.txt   (corrected ground-truth text)
   │
   ▼
5. ForcedAligner (Ruby → Python subprocess)
   tools/pipeline/align.py (ctc-forced-aligner; CPU local / GPU-Colab)
   (wav + corrected text) → data/audio/{reciter}/alignment/{surah}.json  ◄── DELIVERABLE 2
```

### Components

**Rake task `audio:reprocess`** (`lib/tasks/audio_reprocess.rake`, new file)
- Reads `RECITER` and `SURAH` from ENV; validates both.
- Invokes the five stages in order, each idempotent (skips work whose output
  already exists, like the existing tasks do).
- Prints the two deliverable paths at the end.

**`AudioReprocess::WavDownloader`** (`lib/audio_reprocess/wav_downloader.rb`)
- What it does: fetches the QUL recitation index for `reciter_id`, finds the
  `audio_url` for `surah_number`, downloads the WAV.
- Interface: `new(reciter_id:, surah_number:).download → Pathname`.
- Depends on: QUL API (`https://qul.tarteel.ai/api/v1/audio/surah_recitations/{id}?audio_format=wav`), net/http.
- Output: `data/audio/{reciter}/wav/{NNN}.wav` (`NNN` = zero-padded surah, matching
  the convention `generate_wav_manifest` expects).

**`AudioReprocess::Mp3Encoder`** (`lib/audio_reprocess/mp3_encoder.rb`)
- What it does: WAV → MP3 via ffmpeg with Quran metadata, mirroring the
  `reencode_via_wav` / metadata approach in `lib/tasks/audio.rake`.
- Interface: `new(reciter_id:, surah_number:, wav_path:).encode → Pathname`.
- Output: `data/audio/{reciter}/mp3/{NNN}.mp3` (deliverable 1).

**`AudioReprocess::SttTranscriber`** (`lib/audio_reprocess/stt_transcriber.rb`)
- What it does: shells out to `tools/pipeline/transcribe.py` to stream the WAV to
  the Tarteel STT websocket and save the `wordsList` JSON.
- Interface: `new(reciter_id:, surah_number:, wav_path:).transcribe → Pathname`.
- Output: `data/audio/{reciter}/transcript/{surah}.json`.

**`AudioReprocess::Reconciler`** (`lib/audio_reprocess/reconciler.rb`)
- What it does (approach A): reads the STT `wordsList` JSON, joins the word
  strings into one line, writes it to `data/stt/{reciter}/by_surah/{surah}.txt`
  (the path `SurahTranscriptAligner` already reads), then instantiates
  `SurahTranscriptAligner.new(surah_number:, recitation_id:)` and calls its
  public `export_aligned_ayahs`, `export_ayahs_bundle`, `export_fixed_stt`. The
  corrected transcript is read back from
  `data/stt/{reciter}/fixed/by_surah/{surah}.txt`.
- Interface: `new(reciter_id:, surah_number:, transcript_json:).reconcile → String` (corrected text).
- Depends on: existing `SurahTranscriptAligner` (unchanged), DB canonical text.
- Note: this reuses the tested reconciler exactly. Known edge cases in
  `SurahTranscriptAligner` are accepted for now and will be addressed later.

**`AudioReprocess::ForcedAligner`** (`lib/audio_reprocess/forced_aligner.rb`)
- What it does: shells out to `tools/pipeline/align.py` with the WAV and the
  corrected transcript; the script loads ctc-forced-aligner (CUDA if available,
  else CPU) and writes the flat `[{word, start, end}]` JSON.
- Interface: `new(reciter_id:, surah_number:, wav_path:, transcript_text:).align → Pathname`.
- Output: `data/audio/{reciter}/alignment/{surah}.json` (deliverable 2).

**Python scripts** (`tools/pipeline/`)
- `transcribe.py` — distilled from `tools/transcribe_surah.py`; CLI args:
  `--wav <path> --out <path>` (no Colab/`await` top-level, no QUL download — the
  Ruby stage already downloaded the WAV). Connects to the STT websocket
  (dev URI, as in the source), writes `{audioProcessed, wordsList}` JSON.
- `align.py` — distilled from `tools/alignment.py`; CLI args:
  `--wav <path> --text <path|string> --out <path>`. Loads the alignment model,
  aligns one file, writes flat `[{word, start, end}]`. Self-contained: same
  invocation works on a GPU box / Colab.
- `requirements.txt` — `aiohttp`, `torch`, `ctc-forced-aligner` (+ transitive).

### Python environment resolution

The rake task resolves the Python interpreter in this order:
1. `ENV['PYTHON']` if set,
2. `tools/pipeline/.venv/bin/python` if present,
3. otherwise fail fast with a clear message instructing the user to create the
   venv and `pip install -r tools/pipeline/requirements.txt`.

The STT stage needs only `aiohttp`; the alignment stage needs `torch` +
`ctc-forced-aligner`. Each Python script checks its own imports and exits with a
descriptive error if a dependency is missing.

### Directory conventions (reuse existing)

- WAV: `data/audio/{reciter}/wav/{NNN}.wav`
- MP3: `data/audio/{reciter}/mp3/{NNN}.mp3`
- STT raw transcript JSON: `data/audio/{reciter}/transcript/{surah}.json`
- STT joined text (aligner input): `data/stt/{reciter}/by_surah/{surah}.txt`
- Corrected text (aligner output): `data/stt/{reciter}/fixed/by_surah/{surah}.txt`
- Alignment result: `data/audio/{reciter}/alignment/{surah}.json`

### Error handling

- Each stage validates its inputs and raises a clear, actionable error
  (missing reciter in QUL response, missing WAV, ffmpeg failure non-zero exit,
  Python subprocess non-zero exit with stderr surfaced, missing Python deps).
- Stages are idempotent: existing outputs are reused/skipped so a re-run after a
  mid-pipeline failure resumes cheaply (matching existing task conventions).
- Subprocess stdout/stderr are streamed so long-running STT/alignment progress
  is visible.

### Testing

- Ruby: unit-test `WavDownloader` URL/path resolution (stub the QUL API),
  `Mp3Encoder` command construction, `Reconciler` JSON→text extraction and the
  hand-off to `SurahTranscriptAligner` (stub the aligner / use a fixture surah),
  and Python-interpreter resolution logic.
- Integration smoke: surah 1 (Al-Fatiha, ~35s) end-to-end is small enough to run
  locally and is the canonical manual verification path. The STT websocket was
  already verified working locally during design (28 words returned for surah 1).
- Python scripts: a `--help`/import-check path and a manual run against the
  surah-1 WAV fixture.

## Risks

- **ctc-forced-aligner local install on Python 3.12 / torch 2.2.2 (Mac CPU)** —
  may have build issues; verify early in implementation. GPU/Colab fallback (same
  script) is the mitigation.
- **Long-surah CPU alignment** — could be slow/memory-heavy; acceptable per the
  user (short cut-off surahs locally, long ones on GPU).
- **`SurahTranscriptAligner` edge cases** — known and accepted; out of scope for
  this pass.

## Out of scope / later

- Writing alignment results back into `Audio::Segment`.
- Batch/looping over many reciter+surah pairs.
- Fixing reconciler edge cases.
