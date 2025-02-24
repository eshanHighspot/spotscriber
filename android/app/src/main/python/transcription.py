import time
import os
import shutil
import numpy as np
from pydub import AudioSegment
from faster_whisper import WhisperModel
from resemblyzer import VoiceEncoder, preprocess_wav
from sklearn.cluster import KMeans

# ✅ Initialize Models
whisper_model = WhisperModel("medium", device="cpu", compute_type="int8")
encoder = VoiceEncoder()

# ✅ Step 1: Audio Chunking
def chunk_audio(file_path, chunk_length_sec=30):
    """Split audio into smaller chunks for faster processing."""
    audio = AudioSegment.from_file(file_path)
    chunk_length = chunk_length_sec * 1000  # Convert to milliseconds
    chunks = [audio[i:i + chunk_length] for i in range(0, len(audio), chunk_length)]
    
    chunk_paths = []
    for i, chunk in enumerate(chunks):
        chunk_path = f"chunk_{i}.wav"
        chunk.export(chunk_path, format="wav")
        chunk_paths.append(chunk_path)
    return chunk_paths

# ✅ Step 2: Transcription
def transcribe_audio(audio_path):
    """Transcribes audio using Faster-Whisper."""
    segments, _ = whisper_model.transcribe(audio_path, beam_size=5, word_timestamps=True)
    return [{"start": s.start, "end": s.end, "text": s.text} for s in segments]

# ✅ Step 3: Extract Voice Embeddings
def get_embedding(audio_path):
    """Extracts voice embeddings from a given audio segment."""
    try:
        wav = preprocess_wav(audio_path)
        embedding = encoder.embed_utterance(wav)
        return embedding if embedding is not None else None
    except Exception as e:
        print(f"⚠️ Error processing {audio_path}: {str(e)}")
        return None

# ✅ Step 4: Speaker Diarization (Fixed to 2 Speakers)
def assign_speakers_fixed_2(audio_path, transcript):
    """Performs diarization using KMeans (fixed to 2 speakers)."""
    embeddings = []
    segment_times = []
    merged_transcript = []
    temp_segment = None
    min_segment_length_ms = 500  

    # Merge short consecutive segments
    for segment in transcript:
        if temp_segment is None:
            temp_segment = segment
        else:
            if (segment["end"] - temp_segment["end"]) * 1000 < min_segment_length_ms:
                temp_segment["text"] += " " + segment["text"]
                temp_segment["end"] = segment["end"]
            else:
                merged_transcript.append(temp_segment)
                temp_segment = segment

    if temp_segment:
        merged_transcript.append(temp_segment)

    # Process merged segments
    for segment in merged_transcript:
        start_ms = int(segment["start"] * 1000)
        end_ms = int(segment["end"] * 1000)

        segment_audio = AudioSegment.from_wav(audio_path)[start_ms:end_ms]
        segment_audio.export("temp_segment.wav", format="wav")

        embedding = get_embedding("temp_segment.wav")
        if embedding is not None:
            embeddings.append(embedding)
            segment_times.append(segment)

    if len(embeddings) == 0:
        print("❌ No valid embeddings found. Skipping speaker assignment.")
        return []

    embeddings = np.array(embeddings)
    if len(embeddings.shape) == 1:
        embeddings = embeddings.reshape(-1, 1)

    kmeans = KMeans(n_clusters=2, random_state=42, n_init=10)
    speaker_labels = kmeans.fit_predict(embeddings)

    results = []
    for i, segment in enumerate(segment_times):
        results.append({
            "time": f"{segment['start']:.2f} - {segment['end']:.2f}",
            "speaker": f"SPEAKER_{speaker_labels[i]:02d}",
            "content": segment["text"]
        })

    return results

# ✅ Step 5: Process Full Audio File Locally
def process_audio(file_path):
    """Processes an audio file: chunking, transcription, diarization."""
    start_time = time.time()
    chunk_paths = chunk_audio(file_path)
    results = []

    for chunk_path in chunk_paths:
        transcript = transcribe_audio(chunk_path)
        speaker_segments = assign_speakers_fixed_2(chunk_path, transcript)
        results.extend(speaker_segments)

    total_time = time.time() - start_time
    print(f"✅ Total processing time: {total_time:.4f} seconds")

    return {"results": results, "processing_time": total_time}
