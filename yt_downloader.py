import threading
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
import os
import sys
from datetime import datetime

try:
    from yt_dlp import YoutubeDL
    from yt_dlp.utils import DownloadError
except ImportError:
    raise SystemExit("Instaleaza yt-dlp: pip install yt-dlp")

APP_NAME = "HyForce YT Downloader"


class YTDownloaderApp:
    def __init__(self, root):
        self.root = root
        self.root.title(APP_NAME)
        self.root.geometry("850x600")
        self.stop_flag = False
        self.worker = None

        self.theme = {
            "bg": "#0b0f14",
            "panel": "#111827",
            "text": "#E6EEF7",
            "accent": "#06b6d4",
        }

        self._build_style()
        self._build_ui()

    def _build_style(self):
        self.root.configure(bg=self.theme["bg"])
        style = ttk.Style()
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass

        style.configure("TFrame", background=self.theme["bg"])
        style.configure("Panel.TFrame", background=self.theme["panel"])
        style.configure(
            "Header.TLabel",
            background=self.theme["panel"],
            foreground=self.theme["text"],
            font=("Segoe UI", 14, "bold"),
        )
        style.configure(
            "TLabel", background=self.theme["bg"], foreground=self.theme["text"]
        )
        style.configure(
            "TCheckbutton", background=self.theme["bg"], foreground=self.theme["text"]
        )
        style.configure("TButton", padding=6)
        style.configure(
            "Horizontal.TProgressbar",
            background=self.theme["accent"],
            troughcolor=self.theme["panel"],
        )

    def _build_ui(self):
        header = ttk.Frame(self.root, style="Panel.TFrame")
        header.pack(fill=tk.X)
        ttk.Label(header, text=APP_NAME, style="Header.TLabel").pack(
            side=tk.LEFT, padx=15, pady=10
        )

        container = ttk.Frame(self.root)
        container.pack(fill=tk.BOTH, expand=True, padx=15, pady=15)

        ttk.Label(container, text="Link-uri YouTube (unul pe linie):").pack(anchor="w")
        self.txt_urls = tk.Text(
            container,
            height=4,
            bg=self.theme["panel"],
            fg=self.theme["text"],
            insertbackground=self.theme["text"],
            relief=tk.FLAT,
        )
        self.txt_urls.pack(fill=tk.X, pady=(5, 10))

        ttk.Label(container, text="Folder salvare:").pack(anchor="w")
        f_row = ttk.Frame(container)
        f_row.pack(fill=tk.X, pady=(5, 10))

        self.out_var = tk.StringVar(
            value=os.path.join(os.path.expanduser("~"), "Downloads")
        )
        self.out_entry = ttk.Entry(f_row, textvariable=self.out_var)
        self.out_entry.pack(side=tk.LEFT, fill=tk.X, expand=True)
        ttk.Button(f_row, text="Alege", command=self.choose_folder).pack(
            side=tk.LEFT, padx=5
        )
        ttk.Button(f_row, text="Deschide", command=self.open_folder).pack(side=tk.LEFT)

        opt_row = ttk.Frame(container)
        opt_row.pack(fill=tk.X, pady=10)

        ttk.Label(opt_row, text="Format:").pack(side=tk.LEFT)
        self.format_var = tk.StringVar(value="video_mp4")
        ttk.Combobox(
            opt_row,
            textvariable=self.format_var,
            values=["video_mp4", "audio_mp3"],
            state="readonly",
            width=12,
        ).pack(side=tk.LEFT, padx=(5, 15))

        ttk.Label(opt_row, text="Calitate:").pack(side=tk.LEFT)
        self.quality_var = tk.StringVar(value="best")
        ttk.Combobox(
            opt_row,
            textvariable=self.quality_var,
            values=[
                "best",
                "2160p",
                "1440p",
                "1080p",
                "720p",
                "audio_320k",
                "audio_128k",
            ],
            state="readonly",
            width=12,
        ).pack(side=tk.LEFT, padx=(5, 15))

        self.chk_playlist = tk.BooleanVar(value=True)
        ttk.Checkbutton(
            opt_row, text="Descarca playlist", variable=self.chk_playlist
        ).pack(side=tk.LEFT)

        btn_row = ttk.Frame(container)
        btn_row.pack(fill=tk.X, pady=10)
        ttk.Button(btn_row, text="Start Download", command=self.start_download).pack(
            side=tk.LEFT
        )
        ttk.Button(btn_row, text="Stop", command=self.stop_download).pack(
            side=tk.LEFT, padx=5
        )
        ttk.Button(btn_row, text="Curata Jurnal", command=self.clear_log).pack(
            side=tk.LEFT
        )

        prog_row = ttk.Frame(container)
        prog_row.pack(fill=tk.X, pady=5)
        self.progress = ttk.Progressbar(
            prog_row, orient=tk.HORIZONTAL, mode="determinate"
        )
        self.progress.pack(side=tk.LEFT, fill=tk.X, expand=True)

        # Eticheta pentru Procent
        self.lbl_percent = ttk.Label(prog_row, text="0%")
        self.lbl_percent.pack(side=tk.LEFT, padx=(10, 0))

        ttk.Label(container, text="Jurnal:").pack(anchor="w", pady=(10, 0))
        self.txt_log = tk.Text(
            container,
            height=10,
            bg=self.theme["panel"],
            fg=self.theme["text"],
            insertbackground=self.theme["text"],
            relief=tk.FLAT,
        )
        self.txt_log.pack(fill=tk.BOTH, expand=True, pady=(5, 0))

    def choose_folder(self):
        path = filedialog.askdirectory()
        if path:
            self.out_var.set(path)

    def open_folder(self):
        path = self.out_var.get()
        if not os.path.isdir(path):
            return
        if sys.platform.startswith("win"):
            os.startfile(path)
        elif sys.platform == "darwin":
            os.system(f'open "{path}"')
        else:
            os.system(f'xdg-open "{path}"')

    def clear_log(self):
        self.txt_log.delete("1.0", tk.END)

    def log(self, msg):
        self.txt_log.insert(tk.END, f"[{datetime.now().strftime('%H:%M:%S')}] {msg}\n")
        self.txt_log.see(tk.END)
        self.root.update_idletasks()

    def stop_download(self):
        self.stop_flag = True
        self.log("Oprire ceruta...")

    def start_download(self):
        if self.worker and self.worker.is_alive():
            return

        urls = [
            u.strip()
            for u in self.txt_urls.get("1.0", tk.END).splitlines()
            if u.strip()
        ]
        if not urls:
            messagebox.showwarning(APP_NAME, "Introdu un link valid!")
            return

        outdir = self.out_var.get().strip()

        # Verificam daca folderul exista (Nu il mai cream noi automat)
        if not os.path.isdir(outdir):
            messagebox.showerror(
                APP_NAME, "Folderul de salvare nu exista! Alege un folder valid."
            )
            return

        self.stop_flag = False
        self.progress["value"] = 0
        self.lbl_percent.config(text="0%")
        self.log("Pornesc descarcarea...")

        self.worker = threading.Thread(
            target=self._download_worker, args=(urls, outdir), daemon=True
        )
        self.worker.start()

    def _get_opts(self, outdir):
        fmt, q = self.format_var.get(), self.quality_var.get()
        opts = {
            "outtmpl": os.path.join(outdir, "%(title)s.%(ext)s"),
            "noplaylist": not self.chk_playlist.get(),
            "ignoreerrors": True,
            "quiet": True,
        }

        if fmt == "audio_mp3":
            br = "320" if "320" in q else "128"
            opts["format"] = "bestaudio/best"
            opts["postprocessors"] = [
                {
                    "key": "FFmpegExtractAudio",
                    "preferredcodec": "mp3",
                    "preferredquality": br,
                }
            ]
        else:
            if q == "best":
                opts["format"] = (
                    "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
                )
            else:
                h = "".join(filter(str.isdigit, q))
                opts["format"] = (
                    f"bestvideo[height<={h}][ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
                )

            opts["postprocessors"] = [
                {"key": "FFmpegVideoConvertor", "preferedformat": "mp4"}
            ]

        return opts

    def _download_worker(self, urls, outdir):
        def hook(d):
            if self.stop_flag:
                raise DownloadError("Oprit")

            if d.get("status") == "downloading":
                p_str = d.get("_percent_str", "0.0%").strip()
                # Extragem doar numerele si formatam procentajul (pentru a evita caractere ciudate in terminal)
                p_clean = "".join(c for c in p_str if c in "0123456789.%")
                if p_clean:
                    self.lbl_percent.config(text=p_clean)
                    try:
                        self.progress["value"] = float(p_clean.replace("%", ""))
                    except ValueError:
                        pass

            elif d.get("status") == "finished":
                self.progress["value"] = 100
                self.lbl_percent.config(text="100%")
                self.log("Procesare fisier...")

        opts = self._get_opts(outdir)
        opts["progress_hooks"] = [hook]

        try:
            with YoutubeDL(opts) as ydl:
                for url in urls:
                    if self.stop_flag:
                        break
                    self.log(f"Descarc: {url}")
                    try:
                        ydl.download([url])
                    except Exception as e:
                        self.log(f"Eroare: {e}")
        finally:
            self.progress["value"] = 0
            self.lbl_percent.config(text="0%")
            self.log(
                "Sesiune oprita."
                if self.stop_flag
                else "Toate linkurile au fost procesate."
            )


if __name__ == "__main__":
    root = tk.Tk()
    YTDownloaderApp(root)
    root.mainloop()
