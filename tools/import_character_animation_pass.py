"""Import downloaded native animation sheets and annotate frame-local attachment sockets.

Reads the private generation journal; never authenticates or downloads. Existing
art stays intact. New PNGs are alpha-normalized, not scaled or repainted. Socket
proofs and contact sheets go to the private work directory for visual review.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import statistics
import sys
from pathlib import Path

sys.dont_write_bytecode = True
from prepare_character_animation_jobs import ACT_ONE, HERO_ACTIONS, EXTRA_ACTIONS, PROJECT, read_png, write_png

PRIMARY = {"warden": "quick", "bulwark": "guard", "breaker": "quick", "hexwright": "cast",
           "wayfarer": "cast", "lancer": "quick", "cantor": "cast", "apothecary": "cast",
           "rune_smith": "heavy", "starshot": "ranged", "cinder_mage": "cast", "duelist": "quick"}
# Landmarks reviewed against the owned 80px still images. Image searches track
# visible skin/weapon pixels in each frame instead of emitting from body offsets.
LANDMARKS = {
    "warden": {"hand": [19, 51], "blade": [52, 69], "cast": [58, 43]},
    "bulwark": {"hand": [27, 45], "blade": [37, 60], "cast": [58, 39]},
    "breaker": {"hand": [58, 38], "blade": [66, 41], "cast": [66, 41]},
    "hexwright": {"hand": [62, 32], "blade": [10, 26], "cast": [64, 32]},
    "wayfarer": {"hand": [16, 39], "blade": [60, 30], "cast": [16, 39]},
    "lancer": {"hand": [43, 35], "blade": [75, 22], "cast": [43, 35]},
    "cantor": {"hand": [68, 31], "blade": [17, 53], "cast": [17, 53]},
    "apothecary": {"hand": [59, 24], "blade": [70, 7], "cast": [64, 42]},
    "rune_smith": {"hand": [26, 44], "blade": [65, 24], "cast": [62, 24]},
    "starshot": {"hand": [52, 41], "blade": [77, 39], "muzzle": [77, 39], "cast": [77, 39]},
    "cinder_mage": {"hand": [15, 18], "blade": [67, 12], "cast": [15, 18]},
    "duelist": {"hand": [55, 43], "blade": [69, 13], "cast": [55, 43]},
    "brass_recruit": {"hand": [42, 53], "blade": [66, 67], "cast": [56, 46]},
    "brass_runner": {"hand": [43, 39], "blade": [76, 30], "cast": [43, 39]},
    "brass_riveter": {"hand": [39, 41], "blade": [9, 34], "muzzle": [9, 34], "cast": [9, 34]},
    "brass_shieldwright": {"hand": [53, 40], "blade": [61, 43], "cast": [58, 43]},
    "scout": {"hand": [56, 43], "blade": [65, 24], "cast": [56, 43]},
    "brass_bruiser": {"hand": [58, 40], "blade": [67, 40], "cast": [67, 40]},
    "brass_linksmith": {"hand": [58, 39], "blade": [66, 38], "cast": [65, 39]},
    "brass_captain": {"hand": [56, 43], "blade": [65, 18], "cast": [56, 43]},
    "brass_sapper": {"hand": [41, 32], "blade": [58, 17], "muzzle": [58, 17], "cast": [58, 17]},
    "brass_tollkeeper": {"hand": [54, 34], "blade": [67, 20], "cast": [54, 34]},
    "brass_bellmaker": {"hand": [56, 47], "blade": [62, 49], "cast": [41, 51]},
    "tollkeeper_drone": {"hand": [62, 45], "blade": [66, 48], "cast": [61, 44]},
}
CONTACT_OVERRIDES = {"hero:starshot:attack_heavy": 6, "hero:duelist:attack_heavy": 8,
                     "hero:bulwark:attack_heavy": 6, "hero:breaker:attack_heavy": 9,
                     "hero:hexwright:attack_guard": 7, "hero:lancer:attack_heavy": 6,
                     "hero:cantor:attack_guard": 3, "hero:apothecary:attack_ranged": 8,
                     "hero:cinder_mage:attack_heavy": 8, "enemy:brass_runner:attack": 9,
                     "enemy:scout:attack": 7, "enemy:brass_captain:attack": 7,
                     "enemy:brass_sapper:attack": 2, "enemy:tollkeeper_drone:attack": 2,
                     "hero:warden:attack_heavy": 5, "hero:apothecary:attack_guard": 7,
                     "hero:starshot:attack_mobility": 7, "hero:lancer:attack_v2": 7}
REVIEWED_TRACKS = {
    "hero:lancer:attack_v2": {
        "hand": {0:[67,79],1:[67,77],2:[64,77],3:[61,72],4:[36,70],5:[34,64],6:[47,73],7:[78,71],8:[76,73],9:[80,75],10:[73,77],11:[68,78]},
        "blade": {0:[100,62],1:[97,60],2:[87,55],3:[74,48],4:[28,49],5:[13,18],6:[27,77],7:[121,69],8:[120,70],9:[118,71],10:[114,76],11:[102,65]},
    },
    "hero:duelist:attack": {
        "hand": [[55,41],[56,41],[54,42],[52,39],[42,38],[12,42],[7,37],[31,36],[60,34],[56,36],[43,41],[36,47]],
        "blade": [[69,13],[69,13],[64,22],[64,30],[64,36],[32,50],[23,48],[4,33],[76,30],[72,28],[73,39],[57,48]],
    },
    "hero:warden:attack": {
        "hand": {0:[20,49],2:[14,39],3:[19,24],4:[24,27],5:[36,28],6:[39,42],7:[39,42],8:[45,47],9:[27,52],11:[20,49]},
        "blade": {0:[53,72],2:[45,44],3:[9,2],4:[14,8],5:[69,31],6:[72,43],7:[72,43],8:[64,49],9:[57,60],11:[53,72]},
    },
    "hero:lancer:attack": {
        "hand": {0:[44,35],2:[45,35],3:[44,36],4:[53,33],5:[57,35],7:[59,35],8:[54,39],9:[47,40],11:[44,35]},
        "blade": {0:[76,22],2:[74,22],3:[76,25],4:[79,29],5:[79,34],7:[79,34],8:[79,37],9:[76,29],11:[76,22]},
    },
    "hero:duelist:attack_heavy": {
        "hand": [[20,62],[76,59],[80,60],[78,58],[82,55],[51,53],[31,58],[29,50],[64,65],[35,68],[26,57],[19,61]],
        "blade": [[41,76],[105,51],[106,50],[98,54],[86,32],[49,17],[6,55],[6,58],[88,55],[84,70],[45,79],[43,80]],
    },
    "hero:starshot:attack_heavy": {
        "hand": [[72,60],[72,58],[74,57],[74,57],[74,57],[74,57],[69,61],[68,62],[68,59],[68,59],[66,61],[70,63]],
        "muzzle": [[87,56],[87,54],[92,53],[92,53],[92,53],[92,53],[88,57],[88,58],[84,56],[84,56],[82,58],[86,60]],
    },
    "hero:cinder_mage:attack": {
        "hand": [[15,18],[17,18],[21,19],[24,20],[31,25],[43,34],[45,34],[42,37],[39,38],[22,38],[15,18],[15,18]],
    },
    "enemy:brass_riveter:run": {
        "muzzle": [[27,58],[26,58],[26,58],[27,58],[26,59],[25,59],[26,58],[26,58]],
    },
    "hero:warden:attack_guard": {
        "hand": {0:[45,65],4:[44,64],6:[27,75],8:[22,78],11:[30,77]},
        "blade": {0:[83,66],4:[67,75],6:[35,93],8:[24,93],11:[49,91]},
        "cast": {0:[69,65],4:[67,61],6:[66,56],8:[75,56],11:[72,56]},
    },
    "hero:bulwark:attack_heavy": {
        "hand": {0:[27,42],4:[31,33],5:[34,35],6:[68,63],8:[69,70],11:[38,78]},
        "blade": {0:[39,22],4:[20,18],5:[26,25],6:[92,65],8:[94,70],11:[39,81]},
    },
    "hero:breaker:attack_heavy": {
        "hand": {0:[77,51],4:[74,31],5:[73,25],7:[70,27],8:[67,27],9:[76,50],11:[75,51]},
        "blade": {0:[84,51],4:[80,22],5:[79,22],7:[73,18],8:[71,20],9:[86,50],11:[84,50]},
    },
    "hero:hexwright:attack_guard": {"hand": {0:[66,65],5:[62,64],7:[78,56],9:[76,62],11:[68,64]}},
    "hero:wayfarer:attack_mobility": {"hand": {0:[30,62],2:[38,56],4:[69,66],6:[68,66],8:[34,75],10:[31,68],11:[31,66]}},
    "hero:lancer:attack_heavy": {
        "hand": {0:[55,59],4:[62,54],6:[66,55],8:[68,58],11:[55,59]},
        "blade": {0:[96,41],3:[16,54],4:[16,54],5:[19,51],6:[98,55],8:[101,56],9:[105,57],11:[98,42]},
    },
    "hero:cantor:attack_guard": {
        "hand": {0:[56,61],1:[55,59],3:[55,58],5:[54,64],6:[39,58],8:[39,58],11:[39,58]},
        "cast": {0:[73,63],1:[75,54],3:[76,54],5:[66,67],6:[29,77],8:[27,80],11:[27,81]},
    },
    "hero:apothecary:attack_ranged": {"hand": {0:[30,64],4:[42,61],5:[37,58],6:[26,53],7:[43,48],8:[80,51],9:[71,55],10:[58,64],11:[34,64]}},
    "hero:rune_smith:attack_cast": {
        "hand": {0:[40,65],5:[42,65],7:[56,61],9:[57,60],11:[40,64]},
        "cast": {0:[80,43],5:[82,49],7:[83,55],9:[85,45],11:[81,42]},
    },
    "hero:cinder_mage:attack_heavy": {
        "hand": {0:[71,64],3:[62,32],6:[62,34],8:[67,53],9:[71,63],10:[70,62],11:[77,62]},
        "cast": [[79,32],[79,25],[68,12],[48,12],[32,18],[22,23],[26,26],[25,22],[79,45],[90,56],[89,50],[85,31]],
    },
    "hero:warden:attack_heavy": {
        "hand": {0:[37,57],3:[40,41],4:[66,42],5:[75,64],7:[75,64],8:[51,77],9:[42,64],11:[43,56]},
        "blade": {0:[31,33],3:[8,40],4:[67,15],5:[103,61],7:[103,61],8:[77,89],9:[30,57],11:[40,21]},
    },
    "hero:hexwright:attack_heavy": {
        "hand": {0:[37,69],3:[39,66],5:[70,64],7:[70,64],9:[69,64],11:[69,61]},
        "cast": {0:[28,47],3:[35,36],5:[90,62],7:[91,62],9:[88,61],11:[82,32]},
    },
    "hero:apothecary:attack_guard": {"hand": {0:[27,63],3:[36,61],5:[57,51],6:[74,54],7:[78,54],8:[66,62],9:[54,64],11:[29,64]}},
    "hero:starshot:attack_mobility": {
        "hand": [[72,69],[72,66],[75,61],[75,61],[75,61],[75,61],[75,61],[71,60],[72,61],[69,64],[68,67],[71,62]],
        "muzzle": [[88,65],[89,62],[93,57],[94,56],[94,56],[94,56],[94,56],[90,56],[90,57],[87,60],[84,62],[86,56]],
    },
    "hero:duelist:attack_guard": {
        "hand": {0:[63,58],2:[52,48],4:[52,48],6:[52,48],7:[56,49],8:[66,58],9:[64,61],11:[61,61]},
        "blade": {0:[81,25],2:[48,17],4:[46,16],6:[49,16],7:[54,19],8:[75,36],9:[67,42],11:[75,31]},
    },
    "hero:rune_smith:attack_guard": {
        "hand": {0:[40,63],2:[52,49],3:[59,45],5:[59,45],6:[65,50],7:[66,50],8:[64,52],11:[40,64]},
        "cast": {0:[79,40],2:[77,28],3:[69,18],5:[69,18],6:[83,32],7:[88,40],8:[85,43],9:[81,45],11:[81,42]},
    },
}


def pixel(data: bytes, width: int, x: int, y: int) -> tuple[int, ...]:
    return tuple(data[(y * width + x) * 4:(y * width + x) * 4 + 4])


def crop(data: bytes, width: int, rect: list[int]) -> bytes:
    x, y, w, h = map(int, rect)
    return b"".join(data[((y + row) * width + x) * 4:((y + row) * width + x + w) * 4] for row in range(h))


def normalize_alpha(data: bytes) -> bytes:
    result = bytearray(data)
    # Sprite Fusion uses chroma RGB underneath genuine alpha. Never globally key
    # green/magenta: the heroes' cloth and magic legitimately use those colours.
    for index in range(0, len(result), 4):
        if result[index + 3] == 0:
            result[index:index + 3] = b"\0\0\0"
    return bytes(result)


def component(data: bytes, width: int, height: int) -> tuple[set[int], tuple[int, int, int, int]]:
    remaining = {i for i in range(width * height) if data[i * 4 + 3] >= 96}
    largest: set[int] = set()
    while remaining:
        first = remaining.pop()
        found, queue = {first}, [first]
        while queue:
            index = queue.pop()
            x, y = index % width, index // width
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if not (0 <= x + dx < width and 0 <= y + dy < height): continue
                    nxt = (y + dy) * width + x + dx
                    if nxt in remaining:
                        remaining.remove(nxt)
                        found.add(nxt)
                        queue.append(nxt)
        if len(found) > len(largest): largest = found
    if not largest: return set(), (0, 0, width, height)
    xs, ys = [i % width for i in largest], [i // width for i in largest]
    return largest, (min(xs), min(ys), max(xs) + 1, max(ys) + 1)


def closest(data: bytes, width: int, height: int, expected: list[float], radius: int, mode: str = "opaque") -> list[float]:
    result, best = expected, float("inf")
    for y in range(max(0, int(expected[1]) - radius), min(height, int(expected[1]) + radius + 1)):
        for x in range(max(0, int(expected[0]) - radius), min(width, int(expected[0]) + radius + 1)):
            r, g, b, a = pixel(data, width, x, y)
            if a < 128: continue
            if mode == "skin" and not (r > g * 1.05 and g > b * 1.02 and r > 100 and 30 < b < 175): continue
            if mode == "metal" and not (max(r, g, b) > 125 and max(r, g, b) - min(r, g, b) < 90): continue
            distance = (x - expected[0]) ** 2 + (y - expected[1]) ** 2
            if distance < best:
                result, best = [x + .5, y + .5], distance
    if best == float("inf") and mode != "opaque": return closest(data, width, height, expected, radius, "opaque")
    return [round(max(0, min(width, result[0])), 2), round(max(0, min(height, result[1])), 2)]


def muzzle(data: bytes, width: int, height: int, expected: list[float], facing: int, machine: bool) -> list[float]:
    candidates = []
    for y in range(max(0, int(expected[1]) - 14), min(height, int(expected[1]) + 15)):
        for x in range(max(0, int(expected[0]) - 17), min(width, int(expected[0]) + 18)):
            r, g, b, a = pixel(data, width, x, y)
            # Solid dark barrel outline, excluding bright white/orange discharge.
            if a >= 160 and max(r, g, b) < 155:
                candidates.append((x * facing - abs(y - expected[1]) * 1.15, x, y))
    if not candidates: return closest(data, width, height, expected, 9)
    _, x, y = max(candidates)
    x -= facing * (5 if machine else 2)  # mouth/base, not a baked discharge pixel
    return [round(x + .5, 2), round(y + .5, 2)]


def source_input(job: dict, completed: dict) -> Path | None:
    inp = job.get("request", {}).get("inputs", [{}])[0]
    if inp.get("local_path"): return Path(inp["local_path"])
    if inp.get("from_job") in completed:
        outputs = completed[inp["from_job"]].get("outputs", [])
        out = next((o for o in outputs if o.get("index", 0) == inp.get("output_index", 0)), None)
        if out:
            path = out["asset"].get("local_files", {}).get("asset", "")
            if path.lower().endswith(".png"): return Path(path)
    return None


def base_landmarks(identity: str, reference_height: float) -> dict:
    base = LANDMARKS.get(identity, {"hand": [54, 41], "blade": [65, 32], "cast": [54, 41]})
    return {key: [value[0] * reference_height / 80, value[1] * reference_height / 80] for key, value in base.items()}


def tracked_point(track: list | dict, index: int) -> list[float]:
    if isinstance(track, list): return track[min(index, len(track) - 1)].copy()
    keys = sorted(map(int, track))
    before = max((key for key in keys if key <= index), default=keys[0])
    after = min((key for key in keys if key >= index), default=keys[-1])
    a, b = track.get(before, track.get(str(before))), track.get(after, track.get(str(after)))
    phase = (index - before) / max(1, after - before)
    return [a[axis] + (b[axis] - a[axis]) * phase for axis in range(2)]


def annotate(identity: str, record: dict, state: str, clip: dict, rgba: bytes, atlas_width: int,
             source: Path | None = None, overrides: dict | None = None) -> tuple[dict, list[bytes]]:
    frames = clip["frames"]
    frame_pixels = [crop(rgba, atlas_width, frame["rect"]) for frame in frames]
    width, height = map(int, frames[0]["rect"][2:])
    masks = [component(data, width, height) for data in frame_pixels]
    reference = float(record["height"])
    if source and source.exists():
        sw, sh, raw = read_png(source)
        _, source_bounds = component(raw, sw, sh)
        first_bounds = masks[0][1]
        ratio = (first_bounds[3] - first_bounds[1]) / max(1, source_bounds[3] - source_bounds[1])
        reference = round(reference * max(.8, min(1.4, ratio)), 3)
    elif "reference_height" in clip:
        reference = float(clip["reference_height"])
    clip["reference_height"] = reference
    scale = reference / max(1, float(record["height"]))
    # A stable shared floor avoids cancelling intentional jump/bob motion and
    # avoids following a low sword-tip, hammer head, dangling cable or particle.
    floor_candidates = []
    for mask, bounds in masks:
        central = [index // width for index in mask if abs(index % width - width * .5) < width * .24]
        floor_candidates.append(max(central) + 1 if central else bounds[3])
    floor = sorted(floor_candidates)[round((len(floor_candidates) - 1) * .85)]
    if overrides and "floor" in overrides: floor = float(overrides["floor"])
    profile = base_landmarks(identity, float(record["height"]))
    # Align the profile's reviewed sole line, not the canvas bottom.
    offset_y = floor - float(record["height"]) * .96 * scale
    point = lambda xy: [width * .5 + (xy[0] - float(record["height"]) * .5) * scale,
                        offset_y + xy[1] * scale]
    previous_hand = None
    for index, (frame, data) in enumerate(zip(frames, frame_pixels)):
        expected = {key: point(value) for key, value in profile.items()}
        frame_scale = scale
        # Broad action landmarks guide local image searches; the selected pixels
        # come from the actual native pose in this frame.
        phase = index / max(1, int(clip.get("contact_frame", 0))) if state.startswith("attack") else 0
        if state == "attack_heavy" and identity not in ["starshot"]:
            if phase < .65:
                expected["hand"][1] -= math.sin(phase / .65 * math.pi) * 11 * frame_scale
                expected["blade"][1] -= math.sin(phase / .65 * math.pi) * 15 * frame_scale
            elif phase <= 1:
                expected["hand"][0] += 10 * frame_scale
                expected["blade"] = [width * .72, floor - reference * .43]
        if previous_hand and state not in ["death"]:
            expected["hand"] = [(expected["hand"][i] + previous_hand[i]) * .5 for i in range(2)]
        hand = closest(data, width, height, expected["hand"], max(8, round(12 * frame_scale)), "skin" if identity in PRIMARY else "opaque")
        previous_hand = hand
        blade = closest(data, width, height, expected["blade"], max(8, round(13 * frame_scale)), "metal")
        casting = closest(data, width, height, expected["cast"], max(7, round(10 * frame_scale)), "skin" if identity in PRIMARY else "opaque")
        if identity in ["hexwright", "wayfarer", "cinder_mage", "apothecary"]:
            casting = hand.copy() if state in ["attack", "attack_cast", "attack_ranged"] else casting
        gun = muzzle(data, width, height, expected.get("muzzle", expected["blade"]), int(record.get("facing", 1)), identity == "brass_riveter") if identity in ["starshot", "brass_riveter"] else blade.copy()
        sockets = {"hand": hand, "blade": blade, "muzzle": gun, "cast": casting, "feet": [round(width * .5, 2), round(floor, 2)]}
        name = f"{'hero' if identity in PRIMARY else 'enemy'}:{identity}:{state}"
        # Versioned replacements may have a different canvas/action than their
        # archived predecessor, so their reviewed landmarks use the job key.
        track_key = clip.get("source", {}).get("job", name)
        tracks = REVIEWED_TRACKS.get(track_key, REVIEWED_TRACKS.get(name, {}))
        for key, track in tracks.items():
            at = tracked_point(track, index)
            sockets[key] = closest(data, width, height, at, 5) if isinstance(track, dict) else at
        if tracks.get("hand"):
            sockets["cast"] = sockets["hand"].copy()
        if tracks.get("cast"):
            track = tracks["cast"]
            at = tracked_point(track, index)
            sockets["cast"] = closest(data, width, height, at, 5) if isinstance(track, dict) else at
        if tracks.get("blade"):
            sockets["muzzle"] = sockets["blade"].copy()
        if tracks.get("muzzle"):
            sockets["cast"] = sockets["muzzle"].copy()
        if identity in ["hexwright", "wayfarer", "cantor", "apothecary", "rune_smith", "cinder_mage"]:
            sockets["muzzle"] = sockets["cast"].copy()
        if overrides and str(index) in overrides.get("frames", {}):
            sockets.update(overrides["frames"][str(index)])
        frame["sockets"] = sockets
        frame["pivot"] = sockets["feet"].copy()
    if state == "run":
        clip["stride_length"] = 88 if identity in ["brass_runner", "scout", "duelist", "lancer", "starshot"] else 68
        if identity in ["brass_riveter", "tollkeeper_drone"]: clip["stride_length"] = 82
    clip["socket_source"] = "reviewed character landmarks tracked on native frame pixels"
    return clip, frame_pixels


def proof(path: Path, clip: dict, cells: list[bytes]) -> None:
    w, h = map(int, clip["frames"][0]["rect"][2:])
    width, height = w * len(cells), h
    canvas = bytearray(width * height * 4)
    colours = {"hand": (80, 255, 80, 255), "blade": (50, 160, 255, 255), "muzzle": (255, 70, 70, 255),
               "cast": (245, 90, 255, 255), "feet": (255, 255, 255, 255)}
    for i, (frame, pixels) in enumerate(zip(clip["frames"], cells)):
        for y in range(h):
            start = (y * width + i * w) * 4
            canvas[start:start + w * 4] = pixels[y * w * 4:(y + 1) * w * 4]
        for key, colour in colours.items():
            x, y = map(round, frame["sockets"][key])
            for dx, dy in [(-2, 0), (-1, 0), (0, 0), (1, 0), (2, 0), (0, -2), (0, -1), (0, 1), (0, 2)]:
                px, py = i * w + x + dx, y + dy
                if 0 <= px < width and 0 <= py < height:
                    at = (py * width + px) * 4
                    canvas[at:at + 4] = bytes(colour)
    write_png(path, width, height, bytes(canvas))


def run(journal_path: Path, jobs_paths: list[Path], review_path: Path | None, report_dir: Path) -> None:
    manifest_path = PROJECT / "assets/sprite_fusion/manifest.json"
    manifest = json.loads(manifest_path.read_text())
    jobs = {row["name"]: row for path in jobs_paths if path.exists() for row in json.loads(path.read_text())}
    requests = json.loads(journal_path.read_text())
    completed = {row["name"]: row for row in requests if row.get("status") == "succeeded" and row.get("outputs")}
    review = json.loads(review_path.read_text()) if review_path and review_path.exists() else {}
    imported, checks = [], []
    prepared = {}
    for name, row in completed.items():
        job = jobs.get(name, {})
        if job.get("state") in [None, "run_pose"]: continue
        settings = review.get(name, {})
        selected = int(settings.get("selection", 0))
        output = next((out for out in row["outputs"] if int(out.get("index", 0)) == selected), row["outputs"][0])
        asset = output["asset"]
        source_path = Path(asset.get("local_files", {}).get("spritesheet", ""))
        if not source_path.is_file(): continue
        width, height, rgba = read_png(source_path)
        fw, fh = int(asset["width"]), int(asset["height"])
        count = int(asset.get("frameCount", 1))
        assert width % fw == 0 and height % fh == 0 and width // fw * (height // fh) >= count, name
        kind = "hero" if job["group"] == "heroes" else "enemy"
        identity, state = job["identity"], job["state"]
        output_file = job.get("output_file", f"{kind}_{identity}_{state}.png")
        assert Path(output_file).name == output_file and output_file.endswith(".png"), "Output must be one PNG filename"
        destination = PROJECT / "assets/sprite_fusion/animations" / output_file
        rgba = normalize_alpha(rgba)
        write_png(destination, width, height, rgba)
        columns = width // fw
        contact = int(settings.get("contact_frame", CONTACT_OVERRIDES.get(name, job.get("contact_frame", 0))))
        clip = {"texture": "res://" + destination.relative_to(PROJECT).as_posix(),
                "frames": [{"rect": [i % columns * fw, i // columns * fh, fw, fh], "pivot": [fw / 2, fh * .96]} for i in range(count)],
                "fps": 24 if state == "hit" else int(asset.get("fps", 8)), "loop": state in ["idle", "run", "backpedal", "strafe"],
                "contact_frame": min(count - 1, max(0, contact)),
                "source": {"provider": "Sprite Fusion", "asset_id": asset["id"], "request_id": row.get("request_id"), "job": name,
                           "source_sha256": hashlib.sha256(source_path.read_bytes()).hexdigest()}}
        if state.startswith("attack_"): clip["action_family"] = state.removeprefix("attack_")
        manifest[job["group"]][identity]["animations"][state] = clip
        prepared[(job["group"], identity, state)] = source_input(job, completed)
        imported.append(name)
    for group in ["heroes", "enemies"]:
        for identity, record in manifest[group].items():
            if group == "heroes": record["action_families"] = {PRIMARY[identity]: "attack"}
            if identity not in PRIMARY and identity not in ACT_ONE and not any(len(c["frames"]) > 1 for c in record["animations"].values()):
                continue
            for state, clip in record["animations"].items():
                path = PROJECT / clip["texture"].removeprefix("res://")
                width, _, data = read_png(path)
                name = f"{'hero' if group == 'heroes' else 'enemy'}:{identity}:{state}"
                if state == "attack" and identity == "cinder_mage": clip["contact_frame"] = 5
                if state == "attack" and identity == "duelist": clip["contact_frame"] = 8
                clip, cells = annotate(identity, record, state, clip, data, width,
                                       prepared.get((group, identity, state)), review.get(name))
                if group == "heroes" and state.startswith("attack_"):
                    record["action_families"][state.removeprefix("attack_")] = state
                if group == "heroes" or identity in ACT_ONE:
                    proof(report_dir / "sockets" / f"{group}-{identity}-{state}.png", clip, cells)
                checks.append({"group": group, "identity": identity, "state": state, "frames": len(cells),
                               "reference_height": clip["reference_height"], "contact_frame": clip["contact_frame"]})
    manifest["socket_schema"] = 1
    manifest["animation_pass"] = {"first_act_enemies": ACT_ONE, "native_imports": sorted(imported)}
    encoded = json.dumps(manifest, indent=2) + "\n"
    temporary = manifest_path.with_suffix(".json.tmp")
    temporary.write_text(encoded)
    temporary.replace(manifest_path)
    report_dir.mkdir(parents=True, exist_ok=True)
    (report_dir / "import-report.json").write_text(json.dumps({"imported": imported, "clips": checks}, indent=2) + "\n")
    print(f"Imported {len(imported)} completed native clips; annotated {len(checks)} clips with physical attachment/ground landmarks.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--journal", type=Path, required=True)
    parser.add_argument("--jobs", type=Path, nargs="+", required=True)
    parser.add_argument("--review", type=Path)
    parser.add_argument("--report-dir", type=Path, required=True)
    args = parser.parse_args()
    run(args.journal, args.jobs, args.review, args.report_dir)
