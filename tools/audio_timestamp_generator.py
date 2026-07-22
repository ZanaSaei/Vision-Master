import os
import json
import librosa
import numpy as np
from pydub import AudioSegment
from pydub.silence import detect_nonsilent
import re

class AudioTimestampGenerator:
    def __init__(self, audio_folder="assets/audio", data_folder="data"):
        self.audio_folder = audio_folder
        self.data_folder = data_folder
        
    def analyze_audio(self, audio_path, sentences, output_path=None):
        """
        Analyze audio file and generate timestamps for each sentence.
        
        Args:
            audio_path: Path to the audio file
            sentences: List of sentences to timestamp
            output_path: Where to save the timestamps (optional)
        """
        print(f"Analyzing: {audio_path}")
        
        # Load audio
        try:
            y, sr = librosa.load(audio_path, sr=16000)
            duration = librosa.get_duration(y=y, sr=sr)
        except Exception as e:
            print(f"Error loading audio: {e}")
            return None
        
        # Get total duration
        total_duration = duration
        
        # Calculate approximate duration per sentence
        total_chars = sum(len(s) for s in sentences)
        sentences_data = []
        
        # Use energy-based segmentation
        # Calculate energy of the audio
        energy = librosa.feature.rms(y=y, frame_length=2048, hop_length=512)[0]
        energy = energy / np.max(energy)  # Normalize
        
        # Convert frames to time
        hop_length = 512
        frame_times = np.arange(len(energy)) * hop_length / sr
        
        # Find speech segments (where energy is above threshold)
        threshold = 0.05  # Adjust based on audio
        speech_segments = []
        in_speech = False
        start_time = 0
        
        for i, e in enumerate(energy):
            if e > threshold and not in_speech:
                in_speech = True
                start_time = frame_times[i]
            elif e <= threshold and in_speech:
                in_speech = False
                end_time = frame_times[i]
                if end_time - start_time > 0.5:  # Minimum 0.5 second segment
                    speech_segments.append((start_time, end_time))
        
        # If we have fewer segments than sentences, use even distribution
        if len(speech_segments) < len(sentences):
            print(f"Found only {len(speech_segments)} speech segments for {len(sentences)} sentences.")
            print("Using even distribution instead...")
            
            # Use character-based distribution
            chars_per_sentence = [len(s) for s in sentences]
            total_chars = sum(chars_per_sentence)
            current_time = 0.0
            
            # Add small padding at start and end
            padding = 0.2
            
            for i, sent in enumerate(sentences):
                char_ratio = chars_per_sentence[i] / total_chars if total_chars > 0 else 1.0 / len(sentences)
                duration_for_sentence = (total_duration * char_ratio) * 0.9
                
                sentences_data.append({
                    "en": sent,
                    "start": current_time + padding,
                    "end": current_time + duration_for_sentence + padding
                })
                current_time += duration_for_sentence
        
        else:
            # Map sentences to speech segments
            # Calculate character-based distribution within segments
            chars_per_sentence = [len(s) for s in sentences]
            
            # Distribute speech segments among sentences
            if len(speech_segments) >= len(sentences):
                # Use first N segments
                segment_index = 0
                for i, sent in enumerate(sentences):
                    if segment_index < len(speech_segments):
                        start, end = speech_segments[segment_index]
                        sentences_data.append({
                            "en": sent,
                            "start": start,
                            "end": end
                        })
                        segment_index += 1
                    else:
                        # Use last segment for remaining sentences
                        start, end = speech_segments[-1]
                        sentences_data.append({
                            "en": sent,
                            "start": start,
                            "end": end
                        })
        
        # Refine timestamps - ensure no overlap and proper ordering
        for i in range(1, len(sentences_data)):
            if sentences_data[i]["start"] < sentences_data[i-1]["end"]:
                sentences_data[i]["start"] = sentences_data[i-1]["end"] + 0.1
        
        # Save timestamps if output path provided
        if output_path:
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(sentences_data, f, indent=2, ensure_ascii=False)
            print(f"Saved timestamps to: {output_path}")
        
        return sentences_data
    
    def process_all_conversations(self):
        """Process all conversation JSON files and generate timestamp files."""
        # Find all conversation JSON files
        conversation_files = []
        for root, dirs, files in os.walk(self.data_folder):
            for file in files:
                if file.startswith("v") and file.endswith("_conversations.json"):
                    conversation_files.append(os.path.join(root, file))
        
        for file_path in conversation_files:
            self._process_conversation_file(file_path)
    
    def process_all_readings(self):
        """Process all reading JSON files and generate timestamp files."""
        reading_files = []
        for root, dirs, files in os.walk(self.data_folder):
            for file in files:
                if file.startswith("v") and file.endswith("_readings.json"):
                    reading_files.append(os.path.join(root, file))
        
        for file_path in reading_files:
            self._process_reading_file(file_path)
    
    def _process_conversation_file(self, json_path):
        """Process a conversation JSON file."""
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        for lesson_data in data:
            book = lesson_data.get("book")
            lesson = lesson_data.get("lesson")
            audio = lesson_data.get("audio", "")
            
            if not audio:
                continue
            
            # Get all sentences from intro and lines
            all_sentences = []
            
            # Intro sentences
            intro = lesson_data.get("intro", {})
            intro_sentences = intro.get("sentences", [])
            for s in intro_sentences:
                all_sentences.append(s.get("en", ""))
            
            # Line sentences
            lines = lesson_data.get("lines", [])
            for line in lines:
                line_sentences = line.get("sentences", [])
                for s in line_sentences:
                    all_sentences.append(s.get("en", ""))
            
            if not all_sentences:
                continue
            
            # Determine audio path
            audio_path = os.path.join(self.audio_folder, audio)
            if not os.path.exists(audio_path):
                # Try to find the audio file
                audio_filename = os.path.basename(audio)
                audio_path = os.path.join(self.audio_folder, f"v{book}", f"l{lesson}", audio_filename)
                
                if not os.path.exists(audio_path):
                    print(f"Audio not found for book {book}, lesson {lesson}: {audio_path}")
                    continue
            
            # Generate timestamps
            output_path = os.path.join(self.data_folder, f"v{book}_l{lesson}_timestamps.json")
            timestamps = self.analyze_audio(audio_path, all_sentences, output_path)
            
            if timestamps:
                print(f"✅ Generated timestamps for Book {book}, Lesson {lesson}")
            else:
                print(f"❌ Failed to generate timestamps for Book {book}, Lesson {lesson}")
    
    def _process_reading_file(self, json_path):
        """Process a reading JSON file."""
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        for lesson_data in data:
            book = lesson_data.get("book")
            lesson = lesson_data.get("lesson")
            audio = lesson_data.get("audio", "")
            
            if not audio:
                continue
            
            # Get all sentences from paragraphs
            all_sentences = []
            
            paragraphs = lesson_data.get("paragraphs", [])
            for para in paragraphs:
                para_sentences = para.get("sentences", [])
                for s in para_sentences:
                    all_sentences.append(s.get("en", ""))
            
            if not all_sentences:
                continue
            
            # Determine audio path
            audio_path = os.path.join(self.audio_folder, audio)
            if not os.path.exists(audio_path):
                # Try to find the audio file
                audio_filename = os.path.basename(audio)
                audio_path = os.path.join(self.audio_folder, f"v{book}", f"l{lesson}", audio_filename)
                
                if not os.path.exists(audio_path):
                    print(f"Audio not found for book {book}, lesson {lesson}: {audio_path}")
                    continue
            
            # Generate timestamps
            output_path = os.path.join(self.data_folder, f"v{book}_l{lesson}_timestamps.json")
            timestamps = self.analyze_audio(audio_path, all_sentences, output_path)
            
            if timestamps:
                print(f"✅ Generated timestamps for Book {book}, Lesson {lesson}")
            else:
                print(f"❌ Failed to generate timestamps for Book {book}, Lesson {lesson}")

# Run the script
if __name__ == "__main__":
    generator = AudioTimestampGenerator()
    
    print("=" * 50)
    print("Generating timestamps for all conversations...")
    print("=" * 50)
    generator.process_all_conversations()
    
    print("\n" + "=" * 50)
    print("Generating timestamps for all readings...")
    print("=" * 50)
    generator.process_all_readings()
    
    print("\n✅ Done!")