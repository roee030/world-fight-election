"""Slice optional 4x3 transition sheets without changing canonical fighter frames."""

from pathlib import Path
from PIL import Image

try:
    from tools.slice_sprite_sheets import CANVAS, MARGIN, extract_pose_cells, normalize
except ModuleNotFoundError:  # direct `python tools/slice_transition_sheets.py`
    from slice_sprite_sheets import CANVAS, MARGIN, extract_pose_cells, normalize


ROOT = Path(__file__).resolve().parents[1]
SHEETS = ROOT / "assets" / "characters" / "sprite-sheets" / "transitions"
FRAMES = ROOT / "assets" / "characters" / "transitions"
TRANSITION_NAMES = (
    "idle_breath",
    "weight_shift",
    "step_contact",
    "jab_windup",
    "jab_extension",
    "jab_recoil",
    "cross_windup",
    "cross_extension",
    "cross_recoil",
    "kick_chamber",
    "kick_extension",
    "kick_recovery",
)


def slice_transition_sheet(path: Path, save: bool = True) -> list[Image.Image]:
    fighter_id = path.stem.removesuffix("-transitions").replace("-", "_")
    sheet = Image.open(path).convert("RGBA")
    visible_bounds = sheet.getchannel("A").point(lambda alpha: 255 if alpha > 12 else 0).getbbox()
    if visible_bounds is None:
        raise ValueError(f"empty transition sheet: {path}")
    if visible_bounds[0] <= 0 or visible_bounds[1] <= 0 or visible_bounds[2] >= sheet.width or visible_bounds[3] >= sheet.height:
        raise ValueError(f"transition art touches the sheet boundary: {path}")
    cells = extract_pose_cells(sheet)
    canonical = Image.open(FRAMES.parent / "sprites" / f"{fighter_id}-0.png").convert("RGBA")
    canonical_bounds = canonical.getchannel("A").getbbox()
    idle_bounds = cells[0].getchannel("A").getbbox()
    if canonical_bounds is None or idle_bounds is None:
        raise ValueError(f"missing canonical or transition idle art for {fighter_id}")
    canonical_height = canonical_bounds[3] - canonical_bounds[1]
    idle_height = idle_bounds[3] - idle_bounds[1]
    shared_scale = canonical_height / idle_height
    max_w = CANVAS - MARGIN * 2
    max_h = CANVAS - MARGIN - 2
    frames = []
    for cell in cells:
        bounds = cell.getchannel("A").getbbox()
        if bounds is None:
            raise ValueError(f"empty transition pose for {fighter_id}")
        figure = cell.crop(bounds)
        target = (max(1, round(figure.width * shared_scale)), max(1, round(figure.height * shared_scale)))
        if target[1] > max_h:
            fit = max_h / target[1]
            target = (max(1, round(target[0] * fit)), max_h)
        # A fully extended side kick can be wider than the fixed 512px contract.
        # Preserve canonical height and squeeze only that pose horizontally rather
        # than cropping anatomy or shrinking the fighter between adjacent frames.
        if target[0] > max_w:
            target = (max_w, target[1])
        figure = figure.resize(target, Image.Resampling.LANCZOS)
        frame = Image.new("RGBA", (CANVAS, CANVAS))
        frame.alpha_composite(figure, ((CANVAS - target[0]) // 2, CANVAS - MARGIN - target[1]))
        frames.append(frame)
    if save:
        FRAMES.mkdir(parents=True, exist_ok=True)
        for index, frame in enumerate(frames):
            frame.save(FRAMES / f"{fighter_id}-{index}.png")
        print(f"{fighter_id}: {len(frames)} supplemental transition frames")
    return frames


def main() -> None:
    for sheet in sorted(SHEETS.glob("*-transitions.png")):
        slice_transition_sheet(sheet)


if __name__ == "__main__":
    main()
