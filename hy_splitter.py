import customtkinter as ctk
from tkinter import filedialog, messagebox
import threading
import subprocess
import os
import sys
import math
import pygame
import time
import re
from pydub import AudioSegment

# --- SETĂRI TEMĂ ---
ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")


class HYSplitterCV(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("HY Splitter AI ")
        self.geometry("750x750")  # Am mărit puțin fereastra
        self.resizable(False, False)

        # --- MOTOR AUDIO ---
        pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=4096)
        self.channels = {
            "vocals": pygame.mixer.Channel(0),
            "drums": pygame.mixer.Channel(1),
            "bass": pygame.mixer.Channel(2),
            "other": pygame.mixer.Channel(3),
        }
        self.sounds = {}

        self.is_playing = False
        self.is_paused = False
        self.current_time = 0.0
        self.total_length = 0.0
        self.last_time = 0.0

        self.file_path = ""
        self.original_filename = ""
        self.output_dir = os.path.join(os.getcwd(), "HY_Stems")
        os.makedirs(self.output_dir, exist_ok=True)
        self.stems_paths = {}

        self.build_ui()

    # 1. INTERFAȚA GRAFICĂ (UI)

    def build_ui(self):
        # --- HEADER ---
        header = ctk.CTkFrame(self, fg_color="#18181b", corner_radius=0)
        header.pack(fill="x", ipady=15)
        ctk.CTkLabel(
            header,
            text="HY SPLITTER AI",
            font=ctk.CTkFont(size=28, weight="bold"),
            text_color="#00f2fe",
        ).pack()
        ctk.CTkLabel(
            header,
            text="Separare audio de studio & Multi-Track Player",
            text_color="gray",
        ).pack()

        # --- SECȚIUNEA 1: UPLOAD ---
        self.upload_frame = ctk.CTkFrame(self, fg_color="transparent")
        self.upload_frame.pack(pady=40, padx=20, fill="both", expand=True)

        self.lbl_file = ctk.CTkLabel(
            self.upload_frame, text="Nicio melodie selectată", font=ctk.CTkFont(size=14)
        )
        self.lbl_file.pack(pady=10)

        self.btn_load = ctk.CTkButton(
            self.upload_frame,
            text="1. Alege Melodia",
            command=self.load_file,
            height=45,
            width=250,
        )
        self.btn_load.pack(pady=10)

        self.btn_process = ctk.CTkButton(
            self.upload_frame,
            text="2. Pornește Splitter AI",
            command=self.process_ai,
            state="disabled",
            fg_color="#b829ea",
            hover_color="#9119bd",
            height=45,
            width=250,
        )
        self.btn_process.pack(pady=10)

        self.progress_bar = ctk.CTkProgressBar(
            self.upload_frame, width=300, mode="determinate", progress_color="#00f2fe"
        )
        self.lbl_percentage = ctk.CTkLabel(
            self.upload_frame,
            text="0%",
            font=ctk.CTkFont(size=14, weight="bold"),
            text_color="#00f2fe",
        )

        # --- SECȚIUNEA 2: MIXER ---
        self.mixer_frame = ctk.CTkFrame(self, fg_color="#18181b", corner_radius=15)

        self.player_deck = ctk.CTkFrame(
            self.mixer_frame, fg_color="#121215", corner_radius=10
        )
        self.player_deck.pack(fill="x", padx=20, pady=20, ipady=10)

        self.lbl_track_name = ctk.CTkLabel(
            self.player_deck,
            text="Nume Melodie",
            font=ctk.CTkFont(size=18, weight="bold"),
            text_color="#ffffff",
        )
        self.lbl_track_name.pack(pady=(10, 5))

        self.lbl_time = ctk.CTkLabel(
            self.player_deck,
            text="00:00 / 00:00",
            font=ctk.CTkFont(family="Consolas", size=16, weight="bold"),
            text_color="#00f2fe",
        )
        self.lbl_time.pack(pady=5)

        controls_row = ctk.CTkFrame(self.player_deck, fg_color="transparent")
        controls_row.pack(pady=10)

        self.btn_play = ctk.CTkButton(
            controls_row,
            text="▶ PLAY",
            command=self.play_audio,
            width=90,
            fg_color="#28a745",
            hover_color="#218838",
        )
        self.btn_play.pack(side="left", padx=10)

        self.btn_pause = ctk.CTkButton(
            controls_row,
            text="⏸ PAUSE",
            command=self.pause_audio,
            width=90,
            fg_color="#ffc107",
            text_color="black",
            hover_color="#e0a800",
        )
        self.btn_pause.pack(side="left", padx=10)

        self.btn_stop = ctk.CTkButton(
            controls_row,
            text="⏹ STOP",
            command=self.stop_audio,
            width=90,
            fg_color="#dc3545",
            hover_color="#c82333",
        )
        self.btn_stop.pack(side="left", padx=10)

        self.sliders = {}
        stems_info = [
            ("vocals", "🎤 Voce", "#b829ea"),
            ("drums", "🥁 Tobe", "#ff9800"),
            ("bass", "🎸 Bass", "#e91e63"),
            ("other", "🎹 Restul (Melodie)", "#4facfe"),
        ]

        for stem_key, label_text, color in stems_info:
            row = ctk.CTkFrame(self.mixer_frame, fg_color="transparent")
            row.pack(fill="x", padx=40, pady=5)

            ctk.CTkLabel(
                row,
                text=label_text,
                width=150,
                anchor="w",
                font=ctk.CTkFont(weight="bold"),
            ).pack(side="left")
            slider = ctk.CTkSlider(
                row, from_=0, to=1, command=self.update_volumes, progress_color=color
            )
            slider.set(1.0)
            slider.pack(side="left", fill="x", expand=True, padx=10)
            self.sliders[stem_key] = slider

        # Butoane Jos (Export & Reset)
        bottom_btns = ctk.CTkFrame(self.mixer_frame, fg_color="transparent")
        bottom_btns.pack(pady=20)

        self.btn_export = ctk.CTkButton(
            bottom_btns,
            text="💾 EXPORT CA MP3",
            command=self.export_mp3,
            height=45,
            width=180,
            fg_color="#00c9ff",
            text_color="black",
            font=ctk.CTkFont(weight="bold"),
        )
        self.btn_export.pack(side="left", padx=10)

        self.btn_new_song = ctk.CTkButton(
            bottom_btns,
            text="🔙 ALTĂ MELODIE",
            command=self.reset_app,
            height=45,
            width=180,
            fg_color="#333",
            hover_color="#555",
            font=ctk.CTkFont(weight="bold"),
        )
        self.btn_new_song.pack(side="left", padx=10)

    # 2. LOGICA DE PROCESARE AI & PROGRES
    def load_file(self):
        self.file_path = filedialog.askopenfilename(
            filetypes=[("Audio Files", "*.mp3 *.wav *.flac")]
        )
        if self.file_path:
            self.original_filename = os.path.splitext(os.path.basename(self.file_path))[
                0
            ]
            self.lbl_file.configure(
                text=f"Melodie: {self.original_filename}", text_color="#00ffcc"
            )
            self.btn_process.configure(state="normal")

    def process_ai(self):
        self.btn_process.configure(state="disabled")
        self.btn_load.configure(state="disabled")
        self.lbl_file.configure(
            text="AI-ul descompune melodia... ⏳", text_color="#ffeb3b"
        )

        self.progress_bar.pack(pady=(10, 0))
        self.lbl_percentage.pack(pady=(0, 10))
        self.progress_bar.set(0)
        self.lbl_percentage.configure(text="0%")

        threading.Thread(target=self._demucs_worker, daemon=True).start()

    def update_ui_progress(self, percent):
        self.progress_bar.set(percent / 100.0)
        self.lbl_percentage.configure(text=f"{percent}%")

    def _demucs_worker(self):
        try:
            creation_flags = 0x08000000 if sys.platform == "win32" else 0
            process = subprocess.Popen(
                [sys.executable, "-m", "demucs", "-o", self.output_dir, self.file_path],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                creationflags=creation_flags,
            )

            for line in process.stdout:
                match = re.search(r"(\d+)%", line)
                if match:
                    percent = int(match.group(1))
                    self.after(0, lambda p=percent: self.update_ui_progress(p))

            process.wait()
            if process.returncode != 0:
                raise Exception("Eroare în procesul AI.")

            self.after(0, lambda: self.update_ui_progress(100))

            folder = os.path.join(self.output_dir, "htdemucs", self.original_filename)
            for stem in ["vocals", "drums", "bass", "other"]:
                self.stems_paths[stem] = os.path.join(folder, f"{stem}.wav")
                self.sounds[stem] = pygame.mixer.Sound(self.stems_paths[stem])

            self.after(500, self.setup_player)

        except Exception as e:
            self.after(
                0,
                lambda: self.lbl_file.configure(
                    text="Eroare la procesare. ❌", text_color="red"
                ),
            )
            self.after(0, lambda: self.btn_load.configure(state="normal"))
            print(f"Eroare AI: {e}")

    # 3. REDARE AUDIO & PLAYER ENGINE
    def setup_player(self):
        self.upload_frame.pack_forget()
        self.mixer_frame.pack(pady=20, padx=20, fill="both", expand=True)

        self.lbl_track_name.configure(text=self.original_filename)
        self.total_length = self.sounds["vocals"].get_length()
        self.current_time = 0.0
        self.update_time_ui()

        for slider in self.sliders.values():
            slider.set(1.0)
        self.update_volumes()

    def format_time(self, seconds):
        mins = int(seconds // 60)
        secs = int(seconds % 60)
        return f"{mins:02d}:{secs:02d}"

    def update_time_ui(self):
        cur_str = self.format_time(self.current_time)
        tot_str = self.format_time(self.total_length)
        self.lbl_time.configure(text=f"{cur_str} / {tot_str}")

    def timer_loop(self):
        if self.is_playing:
            now = time.time()
            self.current_time += now - self.last_time
            self.last_time = now

            if self.current_time >= self.total_length:
                self.stop_audio()
            else:
                self.update_time_ui()
                self.after(100, self.timer_loop)

    def play_audio(self):
        if self.is_playing:
            return
        if self.is_paused:
            for channel in self.channels.values():
                channel.unpause()
        else:
            for stem, channel in self.channels.items():
                channel.play(self.sounds[stem])
            self.current_time = 0.0

        self.is_playing = True
        self.is_paused = False
        self.last_time = time.time()
        self.timer_loop()

    def pause_audio(self):
        if self.is_playing:
            for channel in self.channels.values():
                channel.pause()
            self.is_playing = False
            self.is_paused = True

    def stop_audio(self):
        for channel in self.channels.values():
            channel.stop()
        self.is_playing = False
        self.is_paused = False
        self.current_time = 0.0
        self.update_time_ui()

    def update_volumes(self, _=None):
        for stem, channel in self.channels.items():
            if stem in self.sliders:
                channel.set_volume(self.sliders[stem].get())

    # 4. EXPORT & RESET APP

    def export_mp3(self):
        save_path = filedialog.asksaveasfilename(
            initialfile=f"{self.original_filename}_HY_Mix.mp3",
            defaultextension=".mp3",
            filetypes=[("MP3 Audio", "*.mp3")],
        )
        if not save_path:
            return

        self.btn_export.configure(text="SE EXPORTĂ... ⏳", state="disabled")
        self.btn_new_song.configure(state="disabled")
        self.update()
        threading.Thread(
            target=self._export_worker, args=(save_path,), daemon=True
        ).start()

    def _export_worker(self, save_path):
        try:
            mixed_audio = None
            for stem, path in self.stems_paths.items():
                vol_ratio = self.sliders[stem].get()
                audio_segment = AudioSegment.from_wav(path)

                if vol_ratio <= 0.01:
                    audio_segment = audio_segment - 120
                else:
                    db_change = 20 * math.log10(vol_ratio)
                    audio_segment = audio_segment + db_change

                if mixed_audio is None:
                    mixed_audio = audio_segment
                else:
                    mixed_audio = mixed_audio.overlay(audio_segment)

            mixed_audio.export(save_path, format="mp3", bitrate="320k")

            self.after(
                0,
                lambda: self.btn_export.configure(
                    text="💾 EXPORTAT CU SUCCES ✅", state="normal", fg_color="#28a745"
                ),
            )
            self.after(0, lambda: self.btn_new_song.configure(state="normal"))
            self.after(
                3000,
                lambda: self.btn_export.configure(
                    text="💾 EXPORT CA MP3", fg_color="#00c9ff"
                ),
            )

        except Exception as e:
            self.after(
                0,
                lambda: self.btn_export.configure(
                    text="EROARE LA EXPORT ❌", state="normal", fg_color="red"
                ),
            )
            self.after(0, lambda: self.btn_new_song.configure(state="normal"))
            print(f"Eroare Export: {e}")

    def reset_app(self):
        """Funcția de Undo / New Song: Oprește muzica și resetează interfața la starea inițială"""
        # 1. Oprim tot
        self.stop_audio()

        # 2. Ștergem datele din memorie
        self.sounds.clear()
        self.stems_paths.clear()
        self.file_path = ""
        self.original_filename = ""

        # 3. Resetăm interfața de Upload
        self.lbl_file.configure(text="Nicio melodie selectată", text_color="white")
        self.btn_process.configure(state="disabled")
        self.btn_load.configure(state="normal")

        self.progress_bar.set(0)
        self.lbl_percentage.configure(text="0%")
        self.progress_bar.pack_forget()
        self.lbl_percentage.pack_forget()

        # 4. Schimbăm ecranele
        self.mixer_frame.pack_forget()
        self.upload_frame.pack(pady=40, padx=20, fill="both", expand=True)


if __name__ == "__main__":
    app = HYSplitterCV()
    app.mainloop()
