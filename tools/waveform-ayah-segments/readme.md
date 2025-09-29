# Ayah Silence Detector

Two tools to find silences(ayah boundaries) in audio:

* `app.py` — Streamlit web app: upload audio, detect ayahs, play segments, export JSON/CSV.
* `silence_detector.py` — Command-line tool: analyze an audio file and save detected silences to a JSON file.

## Requirements

* Python 3.9+.
* System: install `libsndfile1` and `ffmpeg` (Linux example below).
* Python packages: install from `requirements.txt`.

Linux (Debian/Ubuntu) example:

```bash
sudo apt-get update
sudo apt-get install -y libsndfile1 ffmpeg
```

## Install Python deps

```bash
python -m venv venv
source venv/bin/activate    # Windows: venv\Scripts\activate
pip install --upgrade pip
pip install -r requirements.txt
```

## Run the Streamlit web app

```bash
streamlit run app.py
# open http://localhost:8501 in your browser
```

## Run the CLI tool

```bash
python detect_silences.py /Volumes/Data/qul-segments/audio/65/mp3/114.mp3 \
  --threshold 0.18 --min_silence 400 --merge_gap 140 -o output.json
```

### Key options

* `--threshold` : RMS threshold (0..1). Lower = more sensitive.
* `--min_silence` : Minimum silence in ms.
* `--merge_gap` : Merge close silence segments (ms).
* `--window` : RMS window size in ms.

## Output

* Web app: download detected ayahs as JSON or CSV.
* CLI: JSON file with silence times (in ms).

## Troubleshooting

* If audio fails to load, install `ffmpeg` and `libsndfile`.
* For MP3 issues, ensure `pydub` and `ffmpeg` are available.
* Adjust `threshold` and `min_silence` if detection is too many/few.

## Quick steps

1. Install system packages.
2. Create and activate venv.
3. `pip install -r requirements.txt`.
4. Run the Streamlit app or use the CLI.

If you want, I can also create a short English README file you can download — say the word and I will add it.
## Install dependencies
```
pip install -r requirements.txt
```

### Run the web
```
streamlit run app.py
```

### CLI
```
python detect_silences.py audio/1.mp3 --threshold 0.18 --output audio/1.json
```