"""Assemble the 15 s promo from recorded gameplay clips with ffmpeg.

    python tools/promo/build_trailer.py [--clips output/promo/clips_v4]

Outputs (output/promo/final/): trailer_16x9.mp4 and trailer_9x16.mp4.
Timeline numbers live in TIMELINE below; every cut sits on the 180 BPM grid of
the CC0 fight track (beat = 1/3 s, music offset MUSIC_START puts a beat on t=0).
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import overlays as ov  # noqa: E402
from PIL import Image  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output" / "promo"
MUSIC = ROOT / "assets" / "audio" / "music" / "fight.ogg"
MUSIC_START = 3.4958  # 180 BPM, first beat at 0.1625 s + 10 beats
URL = "roee030.github.io/world-fight-election"
FFMPEG = "ffmpeg"
BEAT = 1.0 / 3.0

# name, clip, in-point (s into the clip), duration (s), slow factor (1 = realtime)
TIMELINE = json.loads((Path(__file__).parent / "timeline.json").read_text(encoding="utf-8"))


def run(cmd: list[str]) -> None:
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        print(" ".join(cmd))
        print(proc.stderr[-3000:])
        raise SystemExit(proc.returncode)


def make_segment(clips: Path, seg: dict, out: Path) -> None:
    slow = float(seg.get("slow", 1.0))
    src_dur = float(seg["dur"]) * slow  # source seconds consumed
    punch = float(seg.get("punch", 0.07))
    vf = ["fps=60"]
    if seg.get("crop"):
        cw, ch, cx, cy = seg["crop"].split(":")
        vf.append(f"crop={cw}:{ch}:{cx}:{cy}")
    vf.append("scale=1920:1080:flags=lanczos")
    if slow != 1.0:
        vf.append(f"setpts={1.0 / slow:.5f}*PTS")
    if punch > 0:
        z = f"(1+{punch}*pow(max(0\\,1-t/0.16)\\,2))"
        vf.append(f"scale=w='trunc(1920*{z}/2)*2':h='trunc(1080*{z}/2)*2':eval=frame:flags=bilinear")
        vf.append("crop=1920:1080")
    if seg.get("dim"):
        vf.append(f"eq=brightness=-{seg['dim']}:saturation=0.85")
    af = []
    if slow != 1.0:
        f = slow
        while f < 0.5:
            af.append("atempo=0.5")
            f /= 0.5
        af.append(f"atempo={f:.4f}")
    af.append(f"afade=t=in:d=0.01,afade=t=out:st={max(0.0, float(seg['dur']) - 0.02):.3f}:d=0.02")
    if seg.get("mute"):
        af.append("volume=0")
    cmd = [FFMPEG, "-v", "error", "-y", "-ss", f"{seg['ss']:.3f}", "-t", f"{src_dur:.3f}", "-i", str(clips / f"{seg['clip']}.avi"),
           "-vf", ",".join(vf), "-af", ",".join(af), "-t", f"{seg['dur']:.3f}", "-r", "60",
           "-c:v", "libx264", "-crf", "12", "-preset", "fast", "-pix_fmt", "yuv420p",
           "-c:a", "aac", "-b:a", "256k", "-ar", "48000", "-ac", "2", str(out)]
    run(cmd)


def build_base(clips: Path) -> Path:
    seg_dir = OUT / "segments"
    shutil.rmtree(seg_dir, ignore_errors=True)
    seg_dir.mkdir(parents=True)
    listing = []
    listing_v = []
    t = 0.0
    for i, seg in enumerate(TIMELINE["segments"]):
        path = seg_dir / f"{i:02d}_{seg['clip']}.mp4"
        make_segment(clips, seg, path)
        listing.append(f"file '{path.as_posix()}'")
        vpath = seg_dir / f"v{i:02d}_{seg['clip']}.mp4"
        vertical_segment(path, seg, vpath)
        listing_v.append(f"file '{vpath.as_posix()}'")
        seg["start"] = t
        t += float(seg["dur"])
    (seg_dir / "list.txt").write_text("\n".join(listing), encoding="utf-8")
    (seg_dir / "list_v.txt").write_text(chr(10).join(listing_v), encoding="utf-8")
    base = OUT / "base.mp4"
    run([FFMPEG, "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(seg_dir / "list.txt"), "-c", "copy", str(base)])
    base_v = OUT / "base_v.mp4"
    run([FFMPEG, "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(seg_dir / "list_v.txt"), "-c", "copy", str(base_v)])
    TIMELINE["total"] = t
    return base


def vertical_segment(src: Path, seg: dict, out: Path) -> None:
    """Re-frame one 16:9 segment for 9:16: sharp centre over a blurred copy."""
    if seg.get("vmode") == "full":
        fg = "[b]scale=1080:-2:flags=lanczos[fg]"
    else:
        cx = float(seg.get("vcx", 960))
        x0 = int(max(0, min(1920 - 1280, cx - 640)))
        vy = int(seg.get("vy", 0))
        fg = f"[b]crop=1280:{1080 - vy}:{x0}:{vy},scale=1080:-2:flags=lanczos[fg]"
    fc = ("[0:v]split[a][b];"
          "[a]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,gblur=sigma=34,eq=brightness=-0.32:saturation=1.1[bg];"
          + fg + ";[bg][fg]overlay=0:(H-h)/2-40[v]")
    run([FFMPEG, "-v", "error", "-y", "-i", str(src), "-filter_complex", fc, "-map", "[v]", "-map", "0:a", "-r", "60",
         "-c:v", "libx264", "-crf", "12", "-preset", "fast", "-pix_fmt", "yuv420p", "-c:a", "copy", str(out)])


def flash_sequence(outdir: Path, canvas: str, frames: int = 8) -> int:
    outdir.mkdir(parents=True, exist_ok=True)
    w, h = ov.CANVAS[canvas]
    for i in range(frames):
        a = int(255 * (1 - i / frames) ** 1.6 * 0.9)
        Image.new("RGBA", (w, h), (255, 255, 255, a)).save(outdir / f"{i:04d}.png")
    return frames


def gradient_png(path: Path, canvas: str) -> None:
    w, h = ov.CANVAS[canvas]
    band = int(h * (0.30 if canvas == "h" else 0.2))
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h - band, h):
        a = int(245 * min(1.0, ((y - (h - band)) / band) * 1.7) ** 1.1)
        for x in range(w):
            px[x, y] = (4, 7, 14, a)
    img.save(path)


def make_overlays(canvas: str) -> list[dict]:
    """Return [{dir, start, frames, kind}] for one canvas."""
    d = OUT / "ov" / canvas
    shutil.rmtree(d, ignore_errors=True)
    items: list[dict] = []
    for i, o in enumerate(TIMELINE["overlays"]):
        kind = o["type"]
        sub = d / f"{i:02d}_{kind}"
        start, dur = float(o["at"]), float(o["dur"])
        if kind == "title":
            n = ov.title(canvas, str(sub), dur)
        elif kind == "kicker":
            anchor = tuple(o["anchor"][canvas]) if "anchor" in o else None
            n = ov.kicker(canvas, str(sub), o["text"], dur, anchor=anchor, size=o.get("size"))
        elif kind == "tag":
            n = ov.nametag(canvas, str(sub), o["left"], o["right"], dur)
        elif kind == "cta":
            n = ov.cta(canvas, str(sub), dur, URL)
            sub = Path(str(sub) + "_main")
        elif kind == "disclaimer":
            n = ov.disclaimer(canvas, str(sub), dur)
        elif kind == "flash":
            n = flash_sequence(sub, canvas)
        else:
            raise ValueError(kind)
        items.append({"dir": sub, "start": start, "frames": n})
    return items


def mix_audio_filter(total: float, n_inputs_before_music: int) -> str:
    m = n_inputs_before_music
    fade_out = max(0.0, total - 0.7)
    return (f"[{m}:a]atrim=start={MUSIC_START},asetpts=PTS-STARTPTS,atrim=duration={total},volume={TIMELINE.get('music_gain', 0.5)},"
            f"afade=t=in:d=0.15,afade=t=out:st={fade_out:.3f}:d=0.7[mus];"
            f"[0:a][mus]amix=inputs=2:normalize=0:duration=first,loudnorm=I=-14:TP=-1.5:LRA=9,"
            f"afade=t=out:st={fade_out:.3f}:d=0.7[aout]")


def compose(base: Path, canvas: str, out: Path) -> None:
    total = float(TIMELINE["total"])
    items = make_overlays(canvas)
    grad = OUT / "ov" / f"gradient_{canvas}.png"
    grad.parent.mkdir(parents=True, exist_ok=True)
    gradient_png(grad, canvas)
    inputs = ["-i", str(base)]
    chains = []
    chains.append("[0:v]setsar=1[v0]")
    idx = 1
    cur = "v0"
    # gradient behind the bottom lower-third, only while gameplay shows
    for g in TIMELINE.get("gradient_spans", []):
        inputs += ["-loop", "1", "-i", str(grad)]
        chains.append(f"[{cur}][{idx}:v]overlay=0:0:enable='between(t,{g[0]},{g[1]})'[g{idx}]")
        cur = f"g{idx}"
        idx += 1
    for it in items:
        inputs += ["-itsoffset", f"{it['start']:.3f}", "-framerate", "60", "-i", str(it["dir"] / "%04d.png")]
        chains.append(f"[{cur}][{idx}:v]overlay=0:0:eof_action=pass[o{idx}]")
        cur = f"o{idx}"
        idx += 1
    inputs += ["-i", str(MUSIC)]
    music_idx = idx
    chains.append(mix_audio_filter(total, music_idx))
    chains.append(f"[{cur}]fade=t=out:st={total - 0.12:.3f}:d=0.12,format=yuv420p[vout]")
    cmd = [FFMPEG, "-v", "error", "-y", *inputs, "-filter_complex", ";".join(chains), "-map", "[vout]", "-map", "[aout]",
           "-t", f"{total:.3f}", "-r", "60", "-c:v", "libx264", "-crf", "15", "-preset", "slow", "-pix_fmt", "yuv420p",
           "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", str(out)]
    run(cmd)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--clips", default=str(OUT / "clips_v4"))
    ap.add_argument("--only", choices=["h", "v"], default=None)
    args = ap.parse_args()
    final = OUT / "final"
    final.mkdir(parents=True, exist_ok=True)
    base = build_base(Path(args.clips))
    if args.only != "v":
        compose(base, "h", final / "trailer_16x9.mp4")
    if args.only != "h":
        compose(OUT / "base_v.mp4", "v", final / "trailer_9x16.mp4")
    print("total", TIMELINE["total"])


if __name__ == "__main__":
    main()
