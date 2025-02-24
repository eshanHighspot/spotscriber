import sys
import os
import time
import json
import wave
import numpy as np
import scipy.spatial.distance as dist
from sklearn.cluster import KMeans
from resemblyzer import VoiceEncoder, preprocess_wav
from vosk import Model as VoskModel, KaldiRecognizer

# ------------------------------
# Initialize Models
# ------------------------------
vosk_model_path = "assets/models/vosk/vosk-model-small-en-us-0.15"
if not os.path.exists(vosk_model_path):
    raise FileNotFoundError(f"❌ Vosk model not found at {vosk_model_path}. Download it first!")
vosk_model = VoskModel(vosk_model_path)
encoder = VoiceEncoder()

# ------------------------------
# Transcribe Audio at Word Level using Vosk
# ------------------------------
def transcribe_audio_words(audio_path):
    """
    Transcribes the entire audio file using Vosk with word-level timestamps.
    Returns a list of dictionaries with keys: "word", "start", and "end".
    """
    wf = wave.open(audio_path, "rb")
    rec = KaldiRecognizer(vosk_model, wf.getframerate())
    rec.SetWords(True)
    words = []
    while True:
        data = wf.readframes(4000)
        if len(data) == 0:
            break
        if rec.AcceptWaveform(data):
            result = json.loads(rec.Result())
            if "result" in result:
                words.extend(result["result"])
    final_result = json.loads(rec.FinalResult())
    if "result" in final_result:
        words.extend(final_result["result"])
    wf.close()
    return words

# ------------------------------
# Compute Sliding Window Embeddings
# ------------------------------
def compute_sliding_window_embeddings(audio_path, window_length=1.5, hop_length=0.3):
    """
    Loads the full audio (assumed 16kHz mono) and computes embeddings for overlapping windows.
    Returns:
      - embeddings: list of embeddings (each as 1-D np.array).
      - times: list of (start, end) tuples (in seconds) for each window.
    """
    wav = preprocess_wav(audio_path)  # returns a 1-D np.array
    sr = 16000
    win_samples = int(window_length * sr)
    hop_samples = int(hop_length * sr)
    embeddings = []
    times = []
    for start in range(0, len(wav) - win_samples + 1, hop_samples):
        segment = wav[start : start + win_samples]
        emb = encoder.embed_utterance(segment)
        embeddings.append(emb)
        times.append((start / sr, (start + win_samples) / sr))
    return embeddings, times

# ------------------------------
# Cluster Window Embeddings to Get Speaker Labels
# ------------------------------
def cluster_window_embeddings(embeddings, n_speakers=2):
    """
    Clusters window embeddings using KMeans.
    Returns a list of speaker labels (one per window).
    """
    X = np.vstack(embeddings)
    kmeans = KMeans(n_clusters=n_speakers, random_state=42, n_init=10)
    labels = kmeans.fit_predict(X)
    return labels

# ------------------------------
# Assign Speaker to Each Word
# ------------------------------
def assign_speaker_to_words(words, window_times, window_labels):
    """
    For each word (with "start" and "end" timestamps), assign a speaker label based on
    the nearest sliding window center.
    Returns the list of words with an added "speaker" field.
    """
    assigned = []
    for word in words:
        mid = (word["start"] + word["end"]) / 2.0
        best_idx = None
        best_dist = float("inf")
        for i, (w_start, w_end) in enumerate(window_times):
            center = (w_start + w_end) / 2.0
            d = abs(mid - center)
            if d < best_dist:
                best_dist = d
                best_idx = i
        speaker_label = f"SPEAKER_{window_labels[best_idx]:02d}" if best_idx is not None else "UNKNOWN"
        word["speaker"] = speaker_label
        assigned.append(word)
    return assigned

# ------------------------------
# Group Consecutive Words with Same Speaker into Segments
# ------------------------------
def group_words_by_speaker(assigned_words):
    """
    Groups consecutive words (from the assigned word list) that share the same speaker label.
    Returns a list of segments, each a dict with keys: "speaker", "start", "end", and "text".
    """
    segments = []
    if not assigned_words:
        return segments
    current_speaker = assigned_words[0]["speaker"]
    current_words = [assigned_words[0]]
    for word in assigned_words[1:]:
        if word["speaker"] == current_speaker:
            current_words.append(word)
        else:
            seg_text = " ".join(w["word"] for w in current_words)
            seg_start = current_words[0]["start"]
            seg_end = current_words[-1]["end"]
            segments.append({
                "speaker": current_speaker,
                "start": seg_start,
                "end": seg_end,
                "text": seg_text
            })
            current_speaker = word["speaker"]
            current_words = [word]
    # add last segment
    if current_words:
        seg_text = " ".join(w["word"] for w in current_words)
        seg_start = current_words[0]["start"]
        seg_end = current_words[-1]["end"]
        segments.append({
            "speaker": current_speaker,
            "start": seg_start,
            "end": seg_end,
            "text": seg_text
        })
    return segments

# ------------------------------
# Merge/ Smooth Short Segments
# ------------------------------
def merge_short_segments(segments, min_duration=0.5):
    """
    Merges segments shorter than min_duration (in seconds) into the previous segment.
    This smoothing reduces spurious speaker cuts.
    """
    if not segments:
        return segments
    merged = [segments[0]]
    for seg in segments[1:]:
        duration = seg["end"] - seg["start"]
        if duration < min_duration:
            # Merge with the previous segment
            prev = merged[-1]
            # Extend the previous segment's end time and append text.
            prev["end"] = seg["end"]
            prev["text"] += " " + seg["text"]
        else:
            merged.append(seg)
    return merged

# ------------------------------
# Main Diarization Function (Embeddings + Word-level Assignment)
# ------------------------------
def diarize_audio(audio_path, window_length=1.5, hop_length=0.3, n_speakers=2):
    """
    Performs speaker diarization based on sliding window embeddings and word-level transcription.
      1. Computes overlapping window embeddings and clusters them to assign a speaker label per window.
      2. Transcribes the audio at the word level using Vosk.
      3. For each word, assigns a speaker label based on the nearest window.
      4. Groups consecutive words with the same speaker label into segments.
      5. Merges short segments to smooth out spurious speaker changes.
    Returns a list of segments with start, end, speaker, and text.
    """
    # Compute sliding window embeddings and get their time boundaries.
    embeddings, window_times = compute_sliding_window_embeddings(audio_path, window_length, hop_length)
    window_labels = cluster_window_embeddings(embeddings, n_speakers)
    
    # Get word-level transcript.
    words = transcribe_audio_words(audio_path)
    
    # Assign a speaker label to each word.
    assigned_words = assign_speaker_to_words(words, window_times, window_labels)
    
    # Group consecutive words with the same speaker.
    segments = group_words_by_speaker(assigned_words)
    
    # Merge short segments to reduce spurious cuts.
    smoothed_segments = merge_short_segments(segments, min_duration=0.5)
    
    return smoothed_segments

# ------------------------------
# Main Testing Block
# ------------------------------
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python diarization_by_words_smoothed.py <audio_file.wav>")
        sys.exit(1)
    audio_file = sys.argv[1]
    if not os.path.exists(audio_file):
        print(f"File not found: {audio_file}")
        sys.exit(1)
    
    start = time.time()
    results = diarize_audio(audio_file, window_length=1.5, hop_length=0.3, n_speakers=2)
    end = time.time()
    print(f"Processing time: {end - start:.2f} seconds")
    print(json.dumps(results, indent=2))
