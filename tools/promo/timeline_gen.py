"""Single source of truth for the 22.5 s trailer: segments, transitions, captions, sound cues.

    python tools/promo/timeline_gen.py   # writes tools/promo/timeline.json

All durations are in beats at BPM (144 -> 0.4167 s) so cuts land on the music grid.
`ss` is the in-point inside the recorded clip (seconds); cue times given as
"clip_t" are seconds inside that clip and are converted to trailer time by the builder.
"""
import json
from pathlib import Path

BPM = 144.0
BEAT = 60.0 / BPM

HE_URL = "roee030.github.io/world-fight-election"

# (name in Hebrew) for caption tags
HE = {
    "bennet": "בנט", "avigdor": "ליברמן", "bibi": "ביבי", "yair_golan": "יאיר גולן", "aryeh_deri": "אריה דרעי",
    "yair_lapid": "יאיר לפיד", "mansour_abbas": "מנסור עבאס", "benny_gantz": "בני גנץ", "itamar_ben_gvir": "איתמר בן גביר",
    "bezalel_smotrich": "בצלאל סמוטריץ'", "gadi_eisenkot": "גדי איזנקוט", "trump": "טראמפ", "joint_list": "הרשימה המשותפת",
}

UI_CROP = "1480:832:220:100"       # zoom into the 1280x720 design frame of the select / arena screens
MENU_CROP = "1700:956:0:0"         # also removes the hero video's corner watermark

SEGMENTS = [
    # name, clip, ss, beats, extras...
    dict(name="hook", clip="fin_trump", ss=3.9, beats=5, punch=0.0, vcx=960),
    dict(name="title", clip="ch_eisenkot", ss=6.4, beats=3, dim=0.08, vcx=500, vy=140),
    dict(name="menu", clip="scr_menu", ss=1.0, beats=3, crop=MENU_CROP, punch=0.0, vmode="full"),
    dict(name="select", clip="scr_select", ss=0.75, beats=3, crop=UI_CROP, punch=0.0, vmode="full", detect=dict(kind="hit_light", thr=0.03, gain=0.5)),
    dict(name="reveal", clip="scr_select", ss=3.55, beats=3, crop=UI_CROP, punch=0.0, vmode="full", detect=dict(kind="hit_light", thr=0.03, gain=0.55)),
    dict(name="arena", clip="scr_select", ss=5.85, beats=2, crop=UI_CROP, punch=0.0, vmode="full"),
    dict(name="f1", clip="ch_gvir", ss=5.85, beats=2, vcx=1470, vy=140, detect=dict(kind="hit", thr=0.06, gain=0.9)),
    dict(name="f2", clip="ch_avigdor", ss=3.7, beats=2, vcx=960, vy=140, detect=dict(kind="hit", thr=0.06, gain=0.9)),
    dict(name="f3", clip="ch_gantz", ss=5.5, beats=2, vcx=1000, vy=140, detect=dict(kind="hit", thr=0.06, gain=0.9)),
    dict(name="f4", clip="ch_trump2", ss=5.1, beats=2, vcx=870, vy=140, detect=dict(kind="hit", thr=0.06, gain=0.9)),
    dict(name="f5", clip="ch_golan", ss=4.2, beats=2, vcx=960, vy=140, detect=dict(kind="hit", thr=0.06, gain=0.9)),
    dict(name="campaign", clip="campaign", ss=3.3, beats=4, crop="1536:864:192:30", punch=0.0, vmode="full"),
    dict(name="golan", clip="fin_golan", ss=3.85, beats=5, punch=0.0, vcx=960, crop="1564:880:178:0"),
    dict(name="eisenkot", clip="fin_eisenkot", ss=4.0, beats=4, punch=0.0, vcx=960),
    dict(name="boss", clip="boss_gantz", ss=3.95, beats=6, punch=0.0, vcx=960),
    dict(name="cta", clip="boss_gantz", ss=5.9, beats=6, punch=0.0, dim=0.55, mute=True, vcx=960),
]

# transition AFTER segment i (None for the last): xfade type, seconds, horizontal blur px, white flash
TRANSITIONS = {
    "hook": dict(type="fadewhite", d=0.22, blur=0, flash=False),
    "title": dict(type="slideleft", d=0.18, blur=70, flash=True),
    "menu": dict(type="smoothleft", d=0.20, blur=60, flash=False),
    "select": dict(type="hblur", d=0.14, blur=0, flash=False),
    "reveal": dict(type="slideleft", d=0.16, blur=70, flash=False),
    "arena": dict(type="zoomin", d=0.22, blur=0, flash=True),
    "f1": dict(type="slideright", d=0.14, blur=80, flash=True),
    "f2": dict(type="slideleft", d=0.14, blur=80, flash=True),
    "f3": dict(type="slideright", d=0.14, blur=80, flash=True),
    "f4": dict(type="slideleft", d=0.14, blur=80, flash=True),
    "f5": dict(type="circleopen", d=0.24, blur=0, flash=True),
    "campaign": dict(type="fadewhite", d=0.18, blur=0, flash=False),
    "golan": dict(type="slideleft", d=0.16, blur=70, flash=True),
    "eisenkot": dict(type="fadewhite", d=0.18, blur=0, flash=False),
    "boss": dict(type="fade", d=0.30, blur=0, flash=False),
}

HE_DISCLAIMER = ["סאטירה · קריקטורות בדיוניות · ללא קשר לאף מפלגה או מועמד", "הדמויות והאירועים בדויים ונועדו לבידור"]


def seg_start(name: str) -> float:
    t = 0.0
    for s in SEGMENTS:
        if s["name"] == name:
            return t
        t += s["beats"] * BEAT
    raise KeyError(name)


def build() -> dict:
    segs = []
    for s in SEGMENTS:
        d = dict(s)
        d["dur"] = round(s["beats"] * BEAT, 4)
        d["tr"] = TRANSITIONS.get(s["name"])
        segs.append(d)
    total = round(sum(s["dur"] for s in segs), 4)
    st = lambda n: round(seg_start(n), 4)

    overlays = [
        dict(type="flash", at=round(st("hook") + 1.325 - 0.03, 3), dur=0.15),
        dict(type="title", at=st("title"), dur=round(3 * BEAT, 3), sub="מהדורת הבחירות", main="וורלד פייט"),
        dict(type="kicker", at=st("menu") + 0.1, dur=round(3 * BEAT - 0.1, 3), text="מי יהיה ראש הממשלה הבא?",
             anchor=dict(h=[0.5, 0.9], v=[0.5, 0.76]), size=88),
        dict(type="kicker", at=st("select") + 0.05, dur=round(8 * BEAT - 0.05, 3), text="בחרו לוחם · יריב אקראי",
             anchor=dict(h=[0.5, 0.9], v=[0.5, 0.76]), size=80),
        dict(type="kicker", at=st("f1") + 0.05, dur=round(10 * BEAT - 0.05, 3), text="הקרב על התואר",
             anchor=dict(h=[0.5, 0.17], v=[0.5, 0.2]), size=104),
    ]
    tags = [("f1", "itamar_ben_gvir", "yair_lapid"), ("f2", "avigdor", "aryeh_deri"), ("f3", "benny_gantz", "bezalel_smotrich"),
            ("f4", "trump", "bennet"), ("f5", "yair_golan", "joint_list")]
    for name, left, right in tags:
        overlays.append(dict(type="tag", at=st(name) + 0.05, dur=round(2 * BEAT - 0.1, 3), left=HE[left], right=HE[right], versus="נגד"))
    overlays += [
        dict(type="kicker", at=st("campaign") + 0.05, dur=round(4 * BEAT - 0.1, 3), text="הלחמו בכל ראשי המפלגות לכנסת ה-26",
             anchor=dict(h=[0.5, 0.115], v=[0.5, 0.74]), size=64),
        dict(type="kicker", at=st("golan") + 0.5, dur=round(13 * BEAT - 0.5, 3), text="13 לוחמים · 13 פינישרים",
             anchor=dict(h=[0.5, 0.17], v=[0.5, 0.2]), size=88),
        dict(type="flash", at=round(st("boss") + 0.55 - 0.03, 3), dur=0.15),
        dict(type="cta", at=st("cta"), dur=round(6 * BEAT, 3), line1="שחקו עכשיו בחינם", line2="ישר בדפדפן"),
        dict(type="disclaimer", at=st("cta") + 0.3, dur=round(6 * BEAT - 0.3, 3), lines=HE_DISCLAIMER),
    ]

    # manual sound cues: t = trailer seconds (clip_t cues are converted by the builder)
    sfx = [
        dict(t=0.0, kind="hit_big", gain=1.0), dict(t=0.0, kind="whoosh_down", gain=0.9),
        dict(t=1.325, kind="boom", gain=1.0), dict(t=1.325, kind="hit_big", gain=0.9), dict(t=1.4, kind="crowd_big", gain=1.0),
        dict(t=st("title"), kind="bell", gain=1.0), dict(t=st("title"), kind="boom_long", gain=0.9), dict(t=st("title"), kind="crash", gain=0.8),
        dict(t=st("menu"), kind="cheer", gain=0.8),
        dict(t=st("reveal") + (4.8 - 3.55), kind="hit_big", gain=0.9),
        dict(t=st("arena") + 0.0, kind="whoosh", gain=0.6),
        dict(t=st("campaign"), kind="riser", gain=0.9),
        dict(t=st("golan") + 0.0, kind="hit_big", gain=0.9),
    ]
    for k in (4.2, 4.3, 4.4, 4.5, 4.6):
        sfx.append(dict(t=st("golan") + (k - 3.85), kind="hit_light", gain=0.8))
    sfx += [
        dict(t=st("golan") + (4.8 - 3.85), kind="boom", gain=0.9),
        dict(t=st("golan") + (5.6 - 3.85), kind="cheer", gain=0.9),
        dict(t=st("eisenkot") + 0.0, kind="hit_big", gain=0.9),
        dict(t=st("eisenkot") + (4.65 - 4.0), kind="boom", gain=1.0), dict(t=st("eisenkot") + (4.65 - 4.0), kind="hit_big", gain=0.9),
        dict(t=st("boss") + 0.0, kind="hit_big", gain=0.9),
        dict(t=st("boss") + 0.55, kind="hit_big", gain=1.0), dict(t=st("boss") + 0.65, kind="boom", gain=1.0),
        dict(t=st("boss") + (5.7 - 3.95), kind="cheer", gain=1.0),
        dict(t=st("cta"), kind="bell", gain=1.0), dict(t=st("cta"), kind="crowd_big", gain=1.0), dict(t=st("cta"), kind="crash", gain=0.8),
    ]

    sections = [
        dict(**{"from": 0.0}, to=st("title"), guitar=0.0, bass=0.0, drums=1.0),
        dict(**{"from": st("title")}, to=st("f1"), guitar=0.7, bass=1.0, drums=1.0, hats=True),
        dict(**{"from": st("f1")}, to=st("campaign"), guitar=1.0, bass=1.0, drums=1.0, hats=True),
        dict(**{"from": st("campaign")}, to=st("golan"), guitar=0.0, bass=1.0, drums=1.0, hats=True),
        dict(**{"from": st("golan")}, to=total + 5, guitar=1.0, bass=1.0, drums=1.0, hats=True),
    ]
    return dict(bpm=BPM, total=total, segments=segs, overlays=overlays, sfx=sfx, sections=sections, music_gain=0.6,
                gradient_spans=[[st("title"), st("menu")], [st("f1"), st("campaign")], [st("golan"), total]])


if __name__ == "__main__":
    tl = build()
    Path(__file__).with_name("timeline.json").write_text(json.dumps(tl, indent=1, ensure_ascii=False), encoding="utf-8")
    print("total", tl["total"], "s,", len(tl["segments"]), "segments")
