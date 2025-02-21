# Save as assets/python/transcriber.py
import os
import time
import numpy as np
import json
from pydub import AudioSegment
from faster_whisper import WhisperModel
from resemblyzer import VoiceEncoder, preprocess_wav
from sklearn.cluster import KMeans

class MobileTranscriber:
    def __init__(self, model_path):
        # Initialize with model files in app storage
        self.whisper_model = WhisperModel("tiny", device="cpu", compute_type="int8", 
                                         download_root=model_path)
        self.encoder = VoiceEncoder(device="cpu", 
                                   model_fpath=os.path.join(model_path, "encoder.pt"))
        
    def chunk_audio(self, file_path, chunk_length_sec=15):
        """Split audio into smaller chunks for processing on mobile."""
        audio = AudioSegment.from_file(file_path)
        chunk_length = chunk_length_sec * 1000  # milliseconds
        chunks = [audio[i:i + chunk_length] for i in range(0, len(audio), chunk_length)]
        
        chunk_dir = os.path.dirname(file_path)
        chunk_paths = []
        for i, chunk in enumerate(chunks):
            chunk_path = os.path.join(chunk_dir, f"chunk_{i}.wav")
            chunk.export(chunk_path, format="wav")
            chunk_paths.append(chunk_path)
        return chunk_paths

    def transcribe_audio(self, audio_path):
        """Lightweight transcription for mobile."""
        segments, _ = self.whisper_model.transcribe(audio_path, beam_size=1, word_timestamps=True)
        transcript = []
        for segment in segments:
            transcript.append({
                "start": segment.start,
                "end": segment.end,
                "text": segment.text
            })
        return transcript

    def get_embedding(self, audio_path):
        """Extract voice embeddings with mobile optimization."""
        try:
            wav = preprocess_wav(audio_path)
            embedding = self.encoder.embed_utterance(wav)
            return embedding
        except Exception as e:
            print(f"Error processing segment {audio_path}: {str(e)}")
            return None

    def assign_speakers(self, audio_path, transcript):
        """Optimized speaker diarization for mobile."""
        embeddings = []
        segment_times = []
        
        # Reduced segment length for mobile processing
        min_segment_length_ms = 200
        merged_transcript = []

        # Merge short segments
        temp_segment = None
        for segment in transcript:
            start_ms = int(segment["start"] * 1000)
            end_ms = int(segment["end"] * 1000)

            if temp_segment is None:
                temp_segment = segment
            else:
                if (end_ms - start_ms) < min_segment_length_ms:
                    temp_segment["text"] += " " + segment["text"]
                    temp_segment["end"] = segment["end"]
                else:
                    merged_transcript.append(temp_segment)
                    temp_segment = segment

        if temp_segment:
            merged_transcript.append(temp_segment)

        # Process merged segments
        temp_dir = os.path.dirname(audio_path)
        for segment in merged_transcript:
            start_ms = int(segment["start"] * 1000)
            end_ms = int(segment["end"] * 1000)

            segment_audio = AudioSegment.from_wav(audio_path)[start_ms:end_ms]
            temp_segment_path = os.path.join(temp_dir, "temp_segment.wav")
            segment_audio.export(temp_segment_path, format="wav")
            
            embedding = self.get_embedding(temp_segment_path)

            if embedding is not None:
                embeddings.append(embedding)
                segment_times.append(segment)

        # Handle empty embeddings
        if len(embeddings) == 0:
            return []

        # Convert to NumPy array
        embeddings = np.array(embeddings)
        
        # Ensure proper shape for KMeans
        if len(embeddings.shape) == 1:
            embeddings = embeddings.reshape(-1, 1)

        # Default to 2 speakers
        num_speakers = min(2, len(embeddings))
        kmeans = KMeans(n_clusters=num_speakers, random_state=42, n_init=10)
        speaker_labels = kmeans.fit_predict(embeddings)

        # Assign speakers
        results = []
        for i, segment in enumerate(segment_times):
            speaker_id = f"SPEAKER_{speaker_labels[i]}"
            results.append({
                "start": segment['start'],
                "end": segment['end'],
                "speaker": speaker_id,
                "text": segment["text"]
            })

        return results

    def process_audio(self, file_path):
        """Main processing function for mobile."""
        try:
            chunk_paths = self.chunk_audio(file_path)
            all_results = []

            for chunk_path in chunk_paths:
                transcript = self.transcribe_audio(chunk_path)
                speaker_segments = self.assign_speakers(chunk_path, transcript)
                all_results.extend(speaker_segments)
                
                # Clean up chunks as we go to save space
                os.remove(chunk_path)

            # Sort by start time
            all_results.sort(key=lambda x: x["start"])
            
            return all_results
            
        except Exception as e:
            return {"error": str(e)}

# Interface function to be called from Flutter
def transcribe_file(file_path, model_dir):
    transcriber = MobileTranscriber(model_dir)
    results = transcriber.process_audio(file_path)
    return json.dumps({"results": results})
