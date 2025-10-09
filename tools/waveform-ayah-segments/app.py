import streamlit as st
import numpy as np
import librosa
import soundfile as sf
import io
import json
import math
import plotly.graph_objects as go
from scipy.ndimage import binary_closing, binary_opening
import tempfile, os, traceback
import pandas as pd
from datetime import datetime
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
import base64

# Try pydub for fallback mp3 -> wav conversion
try:
    from pydub import AudioSegment
    HAS_PYDUB = True
except Exception:
    HAS_PYDUB = False

# Optional webrtcvad
try:
    import webrtcvad
    HAS_VAD = True
except Exception:
    HAS_VAD = False

st.set_page_config(page_title="Ayah Silence Detector", layout="wide", page_icon="🎵")

# Custom CSS for better styling
st.markdown("""
<style>
    .main-header {
        font-size: 2.5rem;
        color: #1f77b4;
        text-align: center;
        margin-bottom: 1rem;
    }
    .section-header {
        font-size: 1.5rem;
        color: #1f77b4;
        border-bottom: 2px solid #1f77b4;
        padding-bottom: 0.3rem;
        margin-top: 1.5rem;
        margin-bottom: 1rem;
    }
    .info-box {
        background-color: #f0f8ff;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #1f77b4;
        margin-bottom: 1rem;
    }
    .stButton button {
        width: 100%;
        background-color: #1f77b4;
        color: white;
    }
    .stDownloadButton button {
        width: 100%;
        background-color: #2ca02c;
        color: white;
    }
    .ayah-table {
        font-size: 0.9rem;
    }
    .highlight {
        background-color: #ffffcc;
        padding: 0.2rem;
        border-radius: 0.3rem;
    }
    /* Fix for overlapping elements */
    .stApp [data-testid="stVerticalBlock"] {
        gap: 0.8rem;
    }
    /* Fix for plotly chart overlapping */
    .js-plotly-plot .plotly, .plotly-container {
        width: 100% !important;
    }
    /* Better spacing for columns */
    .stHorizontalBlock {
        gap: 1rem;
    }
    /* Adjust spacing for elements */
    .element-container {
        margin-bottom: 0.5rem;
    }
    /* Playback section styling */
    .playback-section {
        background-color: #f8f9fa;
        padding: 1rem;
        border-radius: 0.5rem;
        margin-top: 1rem;
        margin-bottom: 1rem;
    }
    /* Manual adjustment section */
    .manual-adjust-section {
        background-color: #fff3cd;
        padding: 1rem;
        border-radius: 0.5rem;
        margin-top: 1.5rem;
        margin-bottom: 1rem;
        border-left: 4px solid #ffc107;
    }
    /* Export section */
    .export-section {
        background-color: #d4edda;
        padding: 1rem;
        border-radius: 0.5rem;
        margin-top: 1.5rem;
        margin-bottom: 1rem;
        border-left: 4px solid #28a745;
    }
    /* Time selection section */
    .time-select-section {
        background-color: #e7f3ff;
        padding: 1rem;
        border-radius: 0.5rem;
        margin-top: 1.5rem;
        margin-bottom: 1rem;
        border-left: 4px solid #1f77b4;
    }
</style>
""", unsafe_allow_html=True)

# App header
st.markdown('<h1 class="main-header">🎵 Ayah Silence Detector</h1>', unsafe_allow_html=True)
st.markdown("""
<div class="info-box">
    Upload an audio file, adjust detection settings, and automatically detect ayah boundaries based on silence periods.
    The tool will identify each ayah's start time, end time, duration, and silence duration between ayahs.
</div>
""", unsafe_allow_html=True)

# --- Helpers ---
def load_audio_file_from_bytes(file_bytes, filename_hint=None):
    """
    Robust loader:
      1) Write bytes to tmp file (keep extension if provided)
      2) Try librosa.load(tmp)  -- uses audioread/ffmpeg backend usually
      3) If fails and pydub available, transcode via pydub -> wav then librosa.load
      4) Fallback to soundfile.read (may fail for mp3)
    Returns mono float32 array and sample rate.
    """
    # keep extension if possible
    suffix = None
    if filename_hint and '.' in filename_hint:
        suffix = filename_hint[filename_hint.rfind('.'):]
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix or '.tmp')
    try:
        tmp.write(file_bytes.getbuffer())
        tmp.flush()
        tmp.close()
        # attempt 1: librosa
        try:
            y, sr = librosa.load(tmp.name, sr=None, mono=True)
            return y.astype(np.float32), sr
        except Exception as e1:
            # attempt 2: pydub (transcode -> wav) if available
            if HAS_PYDUB:
                try:
                    audio = AudioSegment.from_file(tmp.name)
                    wav_tmp = tempfile.NamedTemporaryFile(delete=False, suffix='.wav')
                    wav_tmp.close()
                    audio.export(wav_tmp.name, format='wav')
                    y, sr = librosa.load(wav_tmp.name, sr=None, mono=True)
                    try:
                        os.unlink(wav_tmp.name)
                    except Exception:
                        pass
                    return y.astype(np.float32), sr
                except Exception as e2:
                    # attempt 3: soundfile (may throw for mp3)
                    try:
                        data, sr = sf.read(tmp.name, dtype='float32')
                        if data.ndim > 1:
                            data = np.mean(data, axis=1)
                        return data.astype(np.float32), sr
                    except Exception as e3:
                        tb = traceback.format_exc()
                        raise RuntimeError(f"All loaders failed. librosa error: {e1}; pydub error: {e2}; soundfile error: {e3}. Traceback: {tb}")
            else:
                # no pydub installed, try soundfile then error
                try:
                    data, sr = sf.read(tmp.name, dtype='float32')
                    if data.ndim > 1:
                        data = np.mean(data, axis=1)
                    return data.astype(np.float32), sr
                except Exception as e3:
                    tb = traceback.format_exc()
                    raise RuntimeError(f"librosa failed: {e1}; soundfile failed: {e3}. Consider installing pydub + ffmpeg. Traceback: {tb}")
    finally:
        try:
            os.unlink(tmp.name)
        except Exception:
            pass

def compute_rms(y, sr, win_ms=800):  # Default window size changed to 800ms
    hop = max(1, int(sr * (win_ms/1000.0)))
    frame_len = hop
    nframes = math.ceil(len(y) / hop)
    rms = []
    for i in range(0, len(y), hop):
        frame = y[i:i+frame_len]
        if frame.size == 0:
            break
        rms_val = np.sqrt(np.mean(frame*frame)) if frame.size>0 else 0.0
        rms.append(rms_val)
    rms = np.array(rms, dtype=np.float32)
    maxv = rms.max() if rms.size and rms.max()>0 else 1.0
    rms_norm = rms / maxv
    times = np.arange(len(rms)) * (hop / sr)
    return rms_norm, times, hop

def detect_silences_energy(rms_norm, times, hop, sr, threshold=0.05, min_sil_ms=500, merge_ms=40):
    """
    Improved silence detection that properly implements the minimum silence duration requirement.
    When the RMS value drops below the threshold, it checks if it stays below for at least the minimum duration.
    """
    # Convert time durations to frames
    min_sil_frames = max(1, int((min_sil_ms/1000.0) * sr / hop))
    merge_frames = max(1, int((merge_ms/1000.0) * sr / hop))
    
    # Find all potential silence regions
    silences = []
    in_silence = False
    silence_start = 0
    
    for i, value in enumerate(rms_norm):
        if value < threshold and not in_silence:
            # Start of potential silence
            in_silence = True
            silence_start = i
        elif value >= threshold and in_silence:
            # End of potential silence
            in_silence = False
            silence_end = i - 1
            
            # Check if this silence meets the minimum duration requirement
            silence_duration = (silence_end - silence_start + 1) * (hop / sr) * 1000  # in ms
            if silence_duration >= min_sil_ms:
                silences.append({
                    "start_idx": silence_start,
                    "end_idx": silence_end,
                    "start_time": float(silence_start * (hop / sr)),
                    "end_time": float((silence_end + 1) * (hop / sr))
                })
    
    # Handle case where silence continues to the end
    if in_silence:
        silence_end = len(rms_norm) - 1
        silence_duration = (silence_end - silence_start + 1) * (hop / sr) * 1000  # in ms
        if silence_duration >= min_sil_ms:
            silences.append({
                "start_idx": silence_start,
                "end_idx": silence_end,
                "start_time": float(silence_start * (hop / sr)),
                "end_time": float((silence_end + 1) * (hop / sr))
            })
    
    # Merge silences that are close together
    if silences and merge_frames > 1:
        merged_silences = []
        current_silence = silences[0]
        
        for next_silence in silences[1:]:
            gap = next_silence["start_idx"] - current_silence["end_idx"]
            if gap <= merge_frames:
                # Merge the silences
                current_silence["end_idx"] = next_silence["end_idx"]
                current_silence["end_time"] = next_silence["end_time"]
            else:
                # Add the current silence and move to the next
                merged_silences.append(current_silence)
                current_silence = next_silence
        
        # Add the last silence
        merged_silences.append(current_silence)
        silences = merged_silences
    
    return silences

def build_ayahs_from_silences(silences, audio_duration):
    mapping = []
    if not silences:
        mapping.append({"ayah":1, "start":0.0, "end":float(audio_duration), "duration": float(audio_duration), "silence_duration": 0.0})
        return mapping
    sil = sorted(silences, key=lambda x: x["start_time"])
    
    # First ayah: from start to first silence
    mapping.append({
        "ayah": 1, 
        "start": 0.0, 
        "end": float(sil[0]["start_time"]),
        "duration": float(sil[0]["start_time"]),
        "silence_duration": 0.0
    })
    
    # Middle ayahs: between silences
    for i in range(1, len(sil)):
        s = sil[i-1]["end_time"]
        e = sil[i]["start_time"]
        silence_duration = sil[i]["start_time"] - sil[i-1]["end_time"]
        mapping.append({
            "ayah": len(mapping)+1, 
            "start": float(s), 
            "end": float(e),
            "duration": float(e - s),
            "silence_duration": float(silence_duration)
        })
    
    # Last ayah: from last silence to end - FIXED ISSUE 1
    # Check if there's audio after the last silence
    last_silence_end = sil[-1]["end_time"]
    if last_silence_end < audio_duration - 0.1:  # At least 100ms of audio after last silence
        mapping.append({
            "ayah": len(mapping)+1, 
            "start": float(last_silence_end), 
            "end": float(audio_duration),
            "duration": float(audio_duration - last_silence_end),
            "silence_duration": 0.0
        })
    
    # Ensure no invalid time ranges
    for m in mapping:
        if m["end"] <= m["start"]:
            m["end"] = min(audio_duration, m["start"] + 0.001)
            m["duration"] = m["end"] - m["start"]
    
    return mapping

def plot_waveform(rms_norm, rms_times, silences, ayahs, current_time=0, xaxis_interval=10, start_time=0, end_time=None):
    fig = go.Figure()
    
    # Add waveform with improved styling
    fig.add_trace(go.Scatter(
        x=rms_times, 
        y=rms_norm, 
        mode='lines', 
        name='Waveform', 
        line=dict(color='#1f77b4', width=1.5),
        fill='tozeroy',
        fillcolor='rgba(31, 119, 180, 0.2)',
        hovertemplate='Time: %{x:.2f}s<br>Amplitude: %{y:.3f}<extra></extra>'
    ))
    
    # Add silence regions with improved styling
    for s in silences:
        fig.add_vrect(
            x0=s['start_time'], 
            x1=s['end_time'], 
            fillcolor="rgba(255, 0, 0, 0.15)", 
            layer="below", 
            line_width=0,
            annotation_text="Silence" if (s['end_time'] - s['start_time']) > 1 else "",
            annotation_position="top left",
            annotation_font_size=10,
            annotation_font_color="red"
        )
    
    # Add ayah boundaries with improved styling
    for i, a in enumerate(ayahs):
        # Start line
        fig.add_vline(
            x=a['start'], 
            line_dash="solid", 
            line_color="green", 
            line_width=2,
            annotation_text=f"Ayah {i+1}", 
            annotation_position="top right",
            annotation_font_size=12,
            annotation_font_color="green"
        )
        
        # End line (except for last ayah)
        if i < len(ayahs) - 1:
            fig.add_vline(
                x=a['end'], 
                line_dash="solid", 
                line_color="red",
                line_width=2
            )
    
    # Add current time indicator with improved styling
    if current_time > 0:
        fig.add_vline(
            x=current_time, 
            line_width=3, 
            line_color="orange", 
            annotation_text="Current", 
            annotation_position="bottom right",
            annotation_font_size=12,
            annotation_font_color="orange"
        )
    
    # Add start and end time markers if specified
    if start_time > 0:
        fig.add_vline(
            x=start_time, 
            line_width=3, 
            line_dash="dash", 
            line_color="blue", 
            annotation_text="Start", 
            annotation_position="top left",
            annotation_font_size=12,
            annotation_font_color="blue"
        )
    
    if end_time and end_time < max(rms_times) if len(rms_times) > 0 else 1:
        fig.add_vline(
            x=end_time, 
            line_width=3, 
            line_dash="dash", 
            line_color="purple", 
            annotation_text="End", 
            annotation_position="top right",
            annotation_font_size=12,
            annotation_font_color="purple"
        )
    
    # Calculate x-axis tick values based on interval
    max_time = max(rms_times) if len(rms_times) > 0 else 1
    tickvals = list(np.arange(0, max_time + xaxis_interval, xaxis_interval))
    
    # Improved layout
    fig.update_layout(
        height=450,
        xaxis_title="Time (seconds)",
        yaxis_title="Normalized Amplitude",
        showlegend=False,
        hovermode='x unified',
        margin=dict(l=10, r=10, t=50, b=10),
        xaxis=dict(
            tickmode='array',
            tickvals=tickvals,
            tickformat='.0f',
            tickangle=0,
            showgrid=True,
            gridwidth=1,
            gridcolor='LightGray',
            rangeslider=dict(visible=True, thickness=0.05)
        ),
        yaxis=dict(
            fixedrange=False,
            showgrid=True,
            gridwidth=1,
            gridcolor='LightGray',
            zeroline=True,
            zerolinewidth=2,
            zerolinecolor='LightGray'
        ),
        plot_bgcolor='rgba(240, 240, 240, 0.1)'
    )
    
    return fig

def create_audio_player(audio_data, sample_rate, start_time, end_time, key_suffix=""):
    """Create an audio player for a segment of audio"""
    start_sample = int(start_time * sample_rate)
    end_sample = int(end_time * sample_rate)
    segment = audio_data[start_sample:end_sample]
    
    with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as tmp:
        sf.write(tmp.name, segment, sample_rate)
        with open(tmp.name, 'rb') as f:
            audio_bytes = f.read()
    
    # Encode audio to base64 for HTML audio player
    audio_base64 = base64.b64encode(audio_bytes).decode()
    audio_html = f'''
    <audio controls style="width: 100%" id="audio-player-{key_suffix}">
        <source src="data:audio/wav;base64,{audio_base64}" type="audio/wav">
        Your browser does not support the audio element.
    </audio>
    <script>
        document.getElementById('audio-player-{key_suffix}').addEventListener('play', function() {{
            this.currentTime = 0;
        }});
    </script>
    '''
    return audio_html

# Initialize session state
if 'audio_segments' not in st.session_state:
    st.session_state.audio_segments = {}
if 'current_ayah_index' not in st.session_state:
    st.session_state.current_ayah_index = 0
if 'audio_updated' not in st.session_state:
    st.session_state.audio_updated = False
if 'detection_done' not in st.session_state:
    st.session_state.detection_done = False
if 'audio_player_key' not in st.session_state:
    st.session_state.audio_player_key = 0
if 'last_played_ayah' not in st.session_state:
    st.session_state.last_played_ayah = -1
if 'manual_adjustments' not in st.session_state:
    st.session_state.manual_adjustments = {}
if 'xaxis_interval' not in st.session_state:
    st.session_state.xaxis_interval = 10
if 'process_start_time' not in st.session_state:
    st.session_state.process_start_time = 0.0
if 'process_end_time' not in st.session_state:
    st.session_state.process_end_time = None
if 'time_range_updated' not in st.session_state:
    st.session_state.time_range_updated = False
if 'full_audio_loaded' not in st.session_state:
    st.session_state.full_audio_loaded = False
if 'settings_changed' not in st.session_state:
    st.session_state.settings_changed = False
if 'current_settings' not in st.session_state:
    st.session_state.current_settings = {
        'win_ms': 102,
        'threshold': 0.18,
        'min_sil_ms': 100,
        'merge_ms': 10
    }

# Callback function for settings changes
def on_setting_change():
    st.session_state.settings_changed = True

# --- UI Layout ---
col1, col2 = st.columns([1, 2])

with col1:
    st.markdown('<div class="section-header">Upload Audio</div>', unsafe_allow_html=True)
    uploaded = st.file_uploader("Choose an audio file", type=['wav','mp3','ogg','flac','m4a'], label_visibility="collapsed")

    if uploaded is not None:
        # Check if this is a new upload
        current_name = st.session_state.get('upload_name', '')
        if current_name != uploaded.name:
            st.session_state.audio_updated = True
            st.session_state.detection_done = False
            # Clear previous audio segments
            st.session_state.audio_segments = {}
            st.session_state.last_played_ayah = -1
            st.session_state.manual_adjustments = {}
            st.session_state.process_start_time = 0.0
            st.session_state.process_end_time = None
            st.session_state.time_range_updated = False
            st.session_state.full_audio_loaded = False
            st.session_state.settings_changed = False

        # read into BytesIO and load audio using robust loader
        bytesio = io.BytesIO(uploaded.read())
        try:
            y, sr = load_audio_file_from_bytes(io.BytesIO(bytesio.getvalue()), filename_hint=uploaded.name)
            duration = librosa.get_duration(y=y, sr=sr)

            # Store in session state
            st.session_state['audio_data'] = y
            st.session_state['sample_rate'] = sr
            st.session_state['audio_duration'] = duration
            st.session_state['audio_bytes'] = bytesio.getvalue()
            st.session_state['upload_name'] = uploaded.name
            st.session_state.full_audio_loaded = True

            st.success(f"✅ Audio loaded successfully")
            st.info(f"**Duration:** {duration:.2f} seconds\n\n**Sample rate:** {sr} Hz")

            # Audio player
            st.audio(st.session_state['audio_bytes'])

        except Exception as e:
            st.error(f"Error loading audio: {str(e)}")

    # Time selection for processing (only show if audio is loaded)
    if st.session_state.get('full_audio_loaded', False):
        st.markdown('<div class="time-select-section">', unsafe_allow_html=True)
        st.markdown('<div class="section-header">Processing Time Range</div>', unsafe_allow_html=True)
        st.markdown("Select the time range to process (leave empty to process entire audio):")

        col_start, col_end = st.columns(2)
        with col_start:
            start_time = st.number_input("Start time (seconds)",
                                       min_value=0.0,
                                       max_value=float(st.session_state['audio_duration']),
                                       value=st.session_state.process_start_time,
                                       step=0.1,
                                       key="start_time_input")

        with col_end:
            end_time = st.number_input("End time (seconds)",
                                     min_value=0.0,
                                     max_value=float(st.session_state['audio_duration']),
                                     value=st.session_state.process_end_time or float(st.session_state['audio_duration']),
                                     step=0.1,
                                     key="end_time_input")

        # Validate time range
        if start_time >= end_time:
            st.error("End time must be greater than start time")
        else:
            st.session_state.process_start_time = start_time
            st.session_state.process_end_time = end_time
            st.info(f"Will process audio from {start_time:.2f}s to {end_time:.2f}s")

        # Update time range button
        if st.button("Update Time Range", key="update_time_range", use_container_width=True):
            st.session_state.time_range_updated = True
            st.session_state.detection_done = False
            st.session_state.audio_updated = True
            st.session_state.settings_changed = False
            st.rerun()

        st.markdown('</div>', unsafe_allow_html=True)

    st.markdown('<div class="section-header">Detection Settings</div>', unsafe_allow_html=True)

    # Settings with new defaults
    win_ms = st.slider("Window size (ms)", min_value=0, max_value=2000,
                      value=st.session_state.current_settings['win_ms'], step=1,
                      help="Size of the analysis window in milliseconds. Larger values provide smoother RMS calculation.",
                      on_change=on_setting_change)

    threshold = st.slider("Silence threshold", min_value=0.0, max_value=1.0,
                         value=st.session_state.current_settings['threshold'], step=0.005,
                         help="Threshold below which audio is considered silence. Lower values are more sensitive.",
                         on_change=on_setting_change)

    min_sil_ms = st.slider("Minimum silence duration (ms)", min_value=10, max_value=5000,
                          value=st.session_state.current_settings['min_sil_ms'], step=10,
                          help="Minimum duration of silence to be considered a valid silence period.",
                          on_change=on_setting_change)

    merge_ms = st.slider("Merge gaps (ms)", min_value=0, max_value=1000,
                        value=st.session_state.current_settings['merge_ms'], step=10,
                        help="Merge silence periods separated by gaps smaller than this value.",
                        on_change=on_setting_change)

    # X-axis interval setting
    xaxis_interval = st.slider("X-axis time interval (seconds)", min_value=1, max_value=60,
                              value=st.session_state.xaxis_interval, step=1,
                              help="Set the time interval for x-axis ticks (e.g., 10 = 0,10,20,...)")

    # Update session state with new interval
    if xaxis_interval != st.session_state.xaxis_interval:
        st.session_state.xaxis_interval = xaxis_interval

    # Show warning if settings have changed
    if st.session_state.settings_changed:
        st.warning("Settings have been changed. Click 'Detect Ayahs' to apply the new settings.")

    detect_button = st.button("Detect Ayahs", type="primary", use_container_width=True,
                             disabled=not st.session_state.get('time_range_updated', False))

with col2:
    if 'audio_data' in st.session_state and st.session_state.get('time_range_updated', False):
        st.markdown('<div class="section-header">Waveform Visualization</div>', unsafe_allow_html=True)

        # Calculate RMS if not already calculated or if settings changed
        if ('rms_norm' not in st.session_state or
            st.session_state.get('win_ms', 0) != win_ms or
            st.session_state.audio_updated or
            st.session_state.settings_changed):
            with st.spinner("Calculating waveform..."):
                # Apply time range if specified
                start_sample = int(st.session_state.process_start_time * st.session_state['sample_rate'])
                end_sample = int(st.session_state.process_end_time * st.session_state['sample_rate']) if st.session_state.process_end_time else None

                audio_data_to_process = st.session_state['audio_data'][start_sample:end_sample]
                rms_norm, rms_times, hop = compute_rms(audio_data_to_process, st.session_state['sample_rate'], max(1, win_ms))

                # Adjust times to account for start time offset
                if st.session_state.process_start_time > 0:
                    rms_times = rms_times + st.session_state.process_start_time

                st.session_state['rms_norm'] = rms_norm
                st.session_state['rms_times'] = rms_times
                st.session_state['hop'] = hop
                st.session_state['win_ms'] = win_ms
                st.session_state.audio_updated = False

        # Detect silences if button clicked
        if detect_button:
            # Update current settings
            st.session_state.current_settings = {
                'win_ms': win_ms,
                'threshold': threshold,
                'min_sil_ms': min_sil_ms,
                'merge_ms': merge_ms
            }
            st.session_state.settings_changed = False

            with st.spinner("Detecting silences and ayahs..."):
                # Apply time range if specified
                start_time = st.session_state.process_start_time
                end_time = st.session_state.process_end_time or st.session_state['audio_duration']

                # Filter RMS data to only include the selected time range
                if start_time > 0 or end_time < st.session_state['audio_duration']:
                    time_mask = (st.session_state['rms_times'] >= start_time) & (st.session_state['rms_times'] <= end_time)
                    rms_norm_filtered = st.session_state['rms_norm'][time_mask]
                    rms_times_filtered = st.session_state['rms_times'][time_mask]
                else:
                    rms_norm_filtered = st.session_state['rms_norm']
                    rms_times_filtered = st.session_state['rms_times']

                silences = detect_silences_energy(
                    rms_norm_filtered,
                    rms_times_filtered,
                    st.session_state['hop'],
                    st.session_state['sample_rate'],
                    threshold=threshold,
                    min_sil_ms=min_sil_ms,
                    merge_ms=merge_ms
                )

                # Filter silences to only include those within the selected time range
                silences = [s for s in silences if s['start_time'] >= start_time and s['end_time'] <= end_time]

                ayahs = build_ayahs_from_silences(silences, end_time)

                st.session_state['silences'] = silences
                st.session_state['ayahs'] = ayahs
                st.session_state.audio_segments = {}  # Clear previous segments
                st.session_state.current_ayah_index = 0
                st.session_state.detection_done = True
                st.session_state.last_played_ayah = -1
                st.session_state.manual_adjustments = {}

                st.success(f"Detected {len(silences)} silence periods and {len(ayahs)} ayahs")

        # Plot waveform
        if 'rms_norm' in st.session_state:
            silences = st.session_state.get('silences', [])
            ayahs = st.session_state.get('ayahs', [])

            # Time slider for navigation
            current_time = st.slider("Navigate to time (seconds)", 0.0, st.session_state['audio_duration'],
                                    st.session_state.get('current_time', 0.0), 0.1,
                                    key="time_slider")

            # Update current time in session state
            st.session_state['current_time'] = current_time

            fig = plot_waveform(
                st.session_state['rms_norm'],
                st.session_state['rms_times'],
                silences,
                ayahs,
                current_time,
                st.session_state.xaxis_interval,
                st.session_state.process_start_time,
                st.session_state.process_end_time
            )

            st.plotly_chart(fig, use_container_width=True, config={'displayModeBar': True})

            # Playback section - positioned right below the graph
            if st.session_state.get('detection_done', False) and st.session_state.get('ayahs'):
                st.markdown('<div class="playback-section">', unsafe_allow_html=True)
                st.markdown('<div class="section-header">Ayah Playback</div>', unsafe_allow_html=True)

                ayah_options = [f"Ayah {a['ayah']} ({a['start']:.2f}s - {a['end']:.2f}s)" for a in st.session_state['ayahs']]
                selected_ayah = st.selectbox("Select an ayah to play", options=ayah_options,
                                           index=st.session_state.current_ayah_index,
                                           key="ayah_selector")

                if selected_ayah:
                    ayah_index = ayah_options.index(selected_ayah)
                    st.session_state.current_ayah_index = ayah_index
                    ayah = st.session_state['ayahs'][ayah_index]

                    # Check if we need to regenerate the audio segment
                    if (ayah_index not in st.session_state.audio_segments or
                        st.session_state.last_played_ayah != ayah_index or
                        ayah_index in st.session_state.manual_adjustments):
                        with st.spinner("Preparing audio..."):
                            audio_html = create_audio_player(
                                st.session_state['audio_data'],
                                st.session_state['sample_rate'],
                                ayah['start'],
                                ayah['end'],
                                f"ayah_{ayah_index}_{st.session_state.audio_player_key}"
                            )
                            st.session_state.audio_segments[ayah_index] = audio_html
                            st.session_state.last_played_ayah = ayah_index
                            st.session_state.audio_player_key += 1
                            # Remove from manual adjustments if exists
                            if ayah_index in st.session_state.manual_adjustments:
                                del st.session_state.manual_adjustments[ayah_index]

                    # Display the audio player
                    st.markdown(st.session_state.audio_segments[ayah_index], unsafe_allow_html=True)

                    col7, col8 = st.columns(2)
                    with col7:
                        st.write(f"**Start:** {ayah['start']:.3f}s")
                        st.write(f"**End:** {ayah['end']:.3f}s")
                    with col8:
                        st.write(f"**Duration:** {ayah['duration']:.3f}s")
                        st.write(f"**Silence after:** {ayah.get('silence_duration', 0)*1000:.0f}ms")

                st.markdown('</div>', unsafe_allow_html=True)

            # Manual time adjustment section
            if st.session_state.get('detection_done', False) and st.session_state.get('ayahs'):
                st.markdown('<div class="manual-adjust-section">', unsafe_allow_html=True)
                st.markdown('<div class="section-header">Manual Time Adjustment</div>', unsafe_allow_html=True)

                ayah_options = [f"Ayah {a['ayah']}" for a in st.session_state['ayahs']]
                selected_ayah_idx = st.selectbox("Select ayah to adjust", range(len(ayah_options)),
                                               format_func=lambda x: ayah_options[x],
                                               key="manual_adj_select")

                if selected_ayah_idx is not None:
                    ayah = st.session_state['ayahs'][selected_ayah_idx]
                    col3, col4 = st.columns(2)

                    with col3:
                        new_start = st.number_input("Start time (s)", value=float(ayah['start']), min_value=0.0,
                                                   max_value=st.session_state['audio_duration'], step=0.1,
                                                   key="start_time_input_manual")

                    with col4:
                        new_end = st.number_input("End time (s)", value=float(ayah['end']), min_value=0.0,
                                                 max_value=st.session_state['audio_duration'], step=0.1,
                                                 key="end_time_input_manual")

                    if st.button("Update Ayah Time", key="update_ayah"):
                        if new_start < new_end:
                            # Store the manual adjustment
                            st.session_state.manual_adjustments[selected_ayah_idx] = {
                                'start': new_start,
                                'end': new_end
                            }

                            # Update the ayah
                            st.session_state['ayahs'][selected_ayah_idx]['start'] = new_start
                            st.session_state['ayahs'][selected_ayah_idx]['end'] = new_end
                            st.session_state['ayahs'][selected_ayah_idx]['duration'] = new_end - new_start

                            # Update silence durations for adjacent ayahs
                            if selected_ayah_idx > 0:
                                # Update previous ayah's silence duration
                                prev_ayah = st.session_state['ayahs'][selected_ayah_idx-1]
                                prev_ayah['silence_duration'] = new_start - prev_ayah['end']

                            if selected_ayah_idx < len(st.session_state['ayahs']) - 1:
                                # Update current ayah's silence duration
                                next_ayah = st.session_state['ayahs'][selected_ayah_idx+1]
                                st.session_state['ayahs'][selected_ayah_idx]['silence_duration'] = next_ayah['start'] - new_end
                            else:
                                # This is the last ayah, no silence after
                                st.session_state['ayahs'][selected_ayah_idx]['silence_duration'] = 0.0

                            # Force UI update
                            st.session_state.last_played_ayah = -1
                            st.session_state.audio_player_key += 1

                            st.success("Ayah time updated successfully!")
                            st.rerun()
                        else:
                            st.error("End time must be greater than start time")

                st.markdown('</div>', unsafe_allow_html=True)

        # Show ayah table if available
        if st.session_state.get('detection_done', False) and st.session_state.get('ayahs'):
            st.markdown('<div class="section-header">Detected Ayahs</div>', unsafe_allow_html=True)

            # Create dataframe for display
            ayah_data = []
            for ayah in st.session_state['ayahs']:
                ayah_data.append({
                    'Ayah': ayah['ayah'],
                    'Start (s)': f"{ayah['start']:.3f}",
                    'End (s)': f"{ayah['end']:.3f}",
                    'Duration (s)': f"{ayah['duration']:.3f}",
                    'Silence (ms)': f"{ayah.get('silence_duration', 0) * 1000:.0f}"
                })

            df = pd.DataFrame(ayah_data)
            st.dataframe(df, use_container_width=True, height=300)

            # Export options - moved to the bottom
            st.markdown('<div class="export-section">', unsafe_allow_html=True)
            st.markdown('<div class="section-header">Export Results</div>', unsafe_allow_html=True)

            col5, col6 = st.columns(2)

            with col5:
                # JSON export
                json_data = json.dumps(st.session_state['ayahs'], indent=2)
                st.download_button(
                    label="Download JSON",
                    data=json_data,
                    file_name="ayah_mapping.json",
                    mime="application/json",
                    use_container_width=True
                )

            with col6:
                # CSV export
                csv_data = df.to_csv(index=False)
                st.download_button(
                    label="Download CSV",
                    data=csv_data,
                    file_name="ayah_mapping.csv",
                    mime="text/csv",
                    use_container_width=True
                )
            st.markdown('</div>', unsafe_allow_html=True)
    elif 'audio_data' in st.session_state:
        st.info("Please set the time range and click 'Update Time Range' to begin processing.")
    else:
        st.info("Please upload an audio file to begin.")

# Instructions and information
with st.expander("How to use this tool"):
    st.markdown("""
    ### Step-by-Step Guide

    1. **Upload Audio**: Use the file uploader to select an audio file (WAV, MP3, OGG, FLAC, or M4A)
    2. **Select Time Range**: Choose the start and end time for processing and click "Update Time Range"
    3. **Adjust Settings**:
       - **Window Size**: 800ms by default - larger values provide smoother analysis
       - **Silence Threshold**: 0.05 by default - lower values detect more silences
       - **Min Silence Duration**: 500ms by default - only silences longer than this are considered
       - **Merge Gaps**: 40ms by default - silence periods closer than this are merged
       - **X-axis Interval**: Set the time interval for x-axis ticks (default: 10 seconds)
    4. **Detect Ayahs**: Click the "Detect Ayahs" button to analyze the audio
    5. **Review Results**:
       - The waveform visualization shows silences (red areas) and ayah boundaries (green lines)
       - The table displays detailed timing information for each ayah
    6. **Playback**: Select an ayah from the dropdown to listen to it individually
    7. **Manual Adjustment**: You can manually adjust the start and end times of any ayah
    8. **Export**: Download the results as JSON or CSV for further analysis

    ### Tips for Best Results

    - For Quranic recitations, the default settings usually work well
    - If too many silences are detected, increase the threshold or minimum silence duration
    - If too few silences are detected, decrease the threshold
    - Use the merge gaps setting to handle brief interruptions in silence periods
    - Use the manual adjustment feature to fine-tune the ayah boundaries
    - Use the X-axis interval setting to adjust the time scale for better visualization
    - Use the time range selection to process only a specific part of long audio files
    """)

# Footer
st.markdown("---")
st.markdown(
    "<div style='text-align: center; color: #777;'>Ayah Silence Detector • Created with Streamlit</div>",
    unsafe_allow_html=True
)