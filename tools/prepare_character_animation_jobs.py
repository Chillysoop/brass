"""Stage owned Sprite Fusion source poses and a dependency-aware animation job plan.

No credentials or network calls. PNG cropping/padding only prepares already-owned
native keyframes; it does not invent, deform, or relabel new animation artwork.
"""
from __future__ import annotations

import argparse
import json
import struct
import zlib
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
ACT_ONE = ["brass_recruit", "brass_runner", "brass_riveter", "brass_shieldwright", "scout",
           "brass_bruiser", "brass_linksmith", "brass_captain", "brass_sapper",
           "brass_tollkeeper", "brass_bellmaker", "tollkeeper_drone"]
READY_TRAVEL = {"brass_runner", "brass_riveter", "scout", "tollkeeper_drone"}
HERO_ACTIONS = {
    "warden": ("attack_guard", 6, 6, "Brace the shield in front of the body, drive the shield forward with a forceful short step, then recover to the same guard. Sword remains in the other hand. The shield visibly leads the action."),
    "bulwark": ("attack_heavy", 5, 7, "Lift the mace high above the shoulder, plant both armored feet, then deliver a weighty downward mace strike and recover. Keep the enormous shield secured in the other hand."),
    "breaker": ("attack_heavy", 4, 7, "Raise both enormous mechanical gauntlets, compress the knees and torso, then drive both fists down and forward together in one heavy blow. Recover with a visible mechanical recoil."),
    "hexwright": ("attack_guard", 3, 6, "Plant the staff, open the free hand forward, then bring that hand across the chest in a compact protective casting gesture before recovering. Small aether shimmer follows the wrist; the body and hand movement carry the action."),
    "wayfarer": ("attack_mobility", 4, 6, "Perform a nimble planted pivot and side step while facing the same direction, draw the glowing hand across the body, then snap into a poised arrival stance and recover. Keep the lantern attached to its hand. A few tiny phase motes only."),
    "lancer": ("attack_heavy", 3, 7, "Lower into a two-handed spear brace, pull the spear back for a heavy committed lunge, then drive it forward with both arms and recover. The entire spear stays intact; keep the planted feet and forward aim readable."),
    "cantor": ("attack_guard", 5, 6, "Raise both brass bells before the chest, spread them out in a strong protective ringing gesture, then settle back into the starting stance. Distinct arm, shoulder and robe motion; only a few small glowing sound motes."),
    "apothecary": ("attack_ranged", 4, 6, "Take a small potion flask from the belt with the free hand, draw that arm back and throw the flask forward, then recover. Keep the staff held securely in the other hand. Make the release hand clearly readable."),
    "rune_smith": ("attack_cast", 2, 7, "Hold the runic hammer before the chest, trace a small glowing rune across its face with the free hand, then thrust the charged hammer forward and recover. This is a deliberate two-hand smithing cast, not the existing overhead hammer swing."),
    "starshot": ("attack_heavy", 4, 7, "Lower into a stable marksman's crouch, bring the rifle scope tightly to the eye and settle, then fire one powerful shot with visible shoulder recoil and recover. The rifle always aims forward. Keep her auburn hair, teal hat and coat."),
    "cinder_mage": ("attack_heavy", 3, 7, "Grasp the ornate staff with both hands, lift it into a deliberate heavy casting preparation, then drive it forward with a planted body motion and recover. A compact hot glow at the staff head only; keep the arms and staff visible."),
    "duelist": ("attack_heavy", 6, 7, "Coil the torso and draw the blade across the body, then make one broad sweeping sword cut with a low athletic stance and recover. Clearly different from a straight thrust. Keep the blade, hat and teal plume intact."),
}
EXTRA_ACTIONS = {
    "warden": ("attack_heavy", 3, 7, "Draw the sword high behind the shoulder, plant the shield, then make a broad heavy diagonal sword cut and recover. Preserve the same sword and shield."),
    "bulwark": ("attack_quick", 4, 5, "Keep the tower shield forward and make one compact fast mace jab around its edge, followed by a crisp recovery. A quick counter rather than a large overhead swing."),
    "breaker": ("attack_guard", 0, 6, "Bring both mechanical gauntlets together in a tight protective brace before the chest, absorb an imagined frontal impact through the knees and shoulders, then recover."),
    "hexwright": ("attack_heavy", 6, 7, "Draw the staff and free arm back in a deliberate heavy channel, then sweep the staff forward while pulling the free hand toward the chest. Keep the whole body planted; a compact violet glow follows the hands."),
    "wayfarer": ("attack_quick", 3, 5, "Make a fast open-palm phase strike forward with a small hip pivot, then return to the poised starting stance. The lantern remains in the other hand and the cloak follows the turn."),
    "lancer": ("attack_guard", 0, 6, "Turn the spear across the front of the body, brace it with both hands to deflect an imagined strike, then recover into forward spear readiness. Keep the full spear intact."),
    "cantor": ("attack_heavy", 4, 7, "Raise both brass bells high with an expressive deep body preparation, then ring them outward with a broad downward arm motion and recover. The heavy ringing action is carried by the arms and robe."),
    "apothecary": ("attack_guard", 0, 6, "Plant the staff diagonally across the body as a protective brace, hold a small vial close with the free hand, then open the free palm forward and recover. Preserve the staff and potion belt."),
    "rune_smith": ("attack_guard", 0, 6, "Lift the broad hammer face in front of the chest, grip it securely as a short protective brace, absorb an imagined impact through the arms, then recover. No overhead strike."),
    "starshot": ("attack_mobility", 0, 6, "Keep the rifle trained forward while making a nimble backward step, fire with a compact shoulder recoil during the step, then settle into a balanced aiming stance. Never turn away from the target; keep the movement inside the canvas."),
    "cinder_mage": ("attack_guard", 2, 6, "Bring the staff across the front of the body and draw a compact protective gesture with the other hand, brace with a slight knee bend, then recover. Only a few warm embers at the hands; keep the body visible."),
    "duelist": ("attack_guard", 3, 6, "Bring the rapier diagonally up in front of the chest, make a precise wrist-led parry with a small shoulder turn, then return to the starting stance. This is a defensive blade action, not a wide slash or straight thrust."),
}
ENEMY_ACTIONS = {
    "brass_recruit": "Wind the sword arm back, give a short clockwork marching step, swing the sword forward, then recover behind the round shield. The winding key stays attached.",
    "brass_runner": "Brace the thin mechanical legs, pull the polearm back, then drive a quick precise spear jab forward and recover. Preserve the complete long weapon and pointed head.",
    "brass_riveter": "Settle the wheels, wind the front rotary barrel, fire a short rivet burst with a crisp barrel and chassis recoil, then settle. This is a wheeled gun machine, not a walking humanoid.",
    "brass_shieldwright": "Bring the broad shield tightly forward, plant the armored feet and shove the shield ahead, then recover. The shield and helmet stay attached and structurally intact.",
    "scout": "Crouch, draw one curved blade back, make a quick sweeping blade strike, then recover into a light alert stance. Distinct mechanical arm and leg movement.",
    "brass_bruiser": "Wind the huge piston fists back while compressing the torso and knees, deliver a heavy forward piston punch, then let the machinery recoil and recover. Keep the smokestacks attached.",
    "brass_linksmith": "Raise the small forward claw and brace the legs, pulse the back-mounted aether coil, then extend the claw in a deliberate support-casting gesture and recover. Keep the cable physically connected.",
    "brass_captain": "Raise the curved saber, brace behind the hanging banner, make a commanding wide saber slash, then recover. The banner cloth follows the body naturally.",
    "brass_sapper": "Brace all mechanical legs, tilt the mortar tubes for a shot, fire one compact mortar discharge with a visible chassis recoil, then settle. Preserve both tubes and the squat quadruped body.",
    "brass_bellmaker": "Draw both heavy arms up, rock the massive bell body back, then drive the fists and bell body down into one resonant ground strike and recover. Give the small feet a clear stomp; preserve the whole bell silhouette.",
    "tollkeeper_drone": "Hover in place, extend the small repair arm forward, release a tiny green repair spark, then retract the arm and settle. Preserve the hanging cables and green canister.",
}
TRAVEL = {
    "brass_runner": "A quick springy running cycle with long alternating mechanical leg strides. Keep the polearm held steady and pointing forward. Seamless loop, in place.",
    "brass_riveter": "The wheels rotate while the brass gun chassis rolls in place with a subtle rhythmic suspension bounce. Keep the large barrel aimed forward. Seamless loop; no humanoid legs.",
    "scout": "A light quick mechanical trotting cycle with alternating bent legs and small counter-moving arms. The curved blades remain safely held. Seamless loop, in place.",
    "tollkeeper_drone": "A smooth hovering travel loop with the body gently bobbing, small stabilizing feet and cables swaying, and the green canister remaining attached. Seamless loop, in place.",
    "brass_sapper": "A squat four-legged mechanical scuttle cycle: alternate the small legs while the mortar chassis stays stable. Both mortar tubes stay pointed up. Seamless loop, in place.",
    "brass_bellmaker": "A heavy short marching shuffle with alternating tiny feet, the massive bell body rocking with weight, and the arms counterbalancing. Seamless loop, in place.",
}


def read_png(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    at, packed, palette, transparency = 8, bytearray(), b"", b""
    while at < len(data):
        length = struct.unpack_from(">I", data, at)[0]
        kind, body = data[at + 4:at + 8], data[at + 8:at + 8 + length]
        if kind == b"IHDR":
            width, height, bits, color, _, _, interlace = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT": packed.extend(body)
        elif kind == b"PLTE": palette = body
        elif kind == b"tRNS": transparency = body
        at += length + 12
    assert bits == 8 and interlace == 0 and color in (2, 3, 6), (path, bits, color, interlace)
    channels = {2: 3, 3: 1, 6: 4}[color]
    raw, stride = zlib.decompress(packed), width * channels
    rows, prior = [], bytearray(stride)
    for y in range(height):
        begin = y * (stride + 1)
        mode, row = raw[begin], bytearray(raw[begin + 1:begin + 1 + stride])
        for x in range(stride):
            a = row[x - channels] if x >= channels else 0
            b = prior[x]
            c = prior[x - channels] if x >= channels else 0
            if mode == 1: prediction = a
            elif mode == 2: prediction = b
            elif mode == 3: prediction = (a + b) // 2
            elif mode == 4:
                p = a + b - c
                distances = (abs(p - a), abs(p - b), abs(p - c))
                prediction = (a, b, c)[distances.index(min(distances))]
            else: prediction = 0
            row[x] = (row[x] + prediction) & 255
        rows.append(row)
        prior = row
    output = bytearray()
    for row in rows:
        for x in range(width):
            if color == 6: output.extend(row[x * 4:x * 4 + 4])
            elif color == 2: output.extend(row[x * 3:x * 3 + 3] + b"\xff")
            else:
                index = row[x]
                output.extend(palette[index * 3:index * 3 + 3])
                output.append(transparency[index] if index < len(transparency) else 255)
    return width, height, bytes(output)


def write_png(path: Path, width: int, height: int, pixels: bytes) -> None:
    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xffffffff)
    rows = b"".join(b"\0" + pixels[y * width * 4:(y + 1) * width * 4] for y in range(height))
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
               + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))
    if not path.exists() or path.read_bytes() != encoded:
        temporary = path.with_suffix(path.suffix + ".tmp")
        temporary.write_bytes(encoded)
        temporary.replace(path)


def source_frame(record: dict, state: str, index: int, destination: Path, canvas_size: int | None = None) -> dict:
    clip = record["animations"][state]
    frame = clip["frames"][index]
    x, y, width, height = map(int, frame["rect"])
    atlas_width, _, pixels = read_png(PROJECT / clip["texture"].removeprefix("res://"))
    canvas = canvas_size or (112 if max(width, height) <= 96 else 128)
    assert canvas >= max(width, height), "Prepared canvas cannot crop the owned pose"
    ox, oy = (canvas - width) // 2, canvas - height - 8
    output = bytearray(canvas * canvas * 4)
    for row in range(height):
        start = ((y + row) * atlas_width + x) * 4
        target = ((oy + row) * canvas + ox) * 4
        output[target:target + width * 4] = pixels[start:start + width * 4]
    write_png(destination, canvas, canvas, output)
    return {"local_path": str(destination), "source_texture": clip["texture"], "source_frame": index,
            "source_rect": frame["rect"], "padding": [ox, oy], "reference_height": record["height"]}


def build(output: Path) -> None:
    manifest = json.loads((PROJECT / "assets/sprite_fusion/manifest.json").read_text())
    output.mkdir(parents=True, exist_ok=True)
    poses, jobs, provenance = output / "source-poses", [], {}
    for identity in ACT_ONE:
        record = manifest["enemies"][identity]
        source = source_frame(record, "idle", 0, poses / f"enemy-{identity}-ready.png")
        provenance[f"enemy:{identity}:source"] = source
        if identity not in READY_TRAVEL:
            prompt = ("Prepare this exact character for an in-place walking cycle: put one supporting foot clearly on the ground and the opposite leg forward, "
                      "with a natural balanced travel stance. Keep its exact identity, palette, equipment, facing direction and all mechanical parts. "
                      "Leave the existing canvas room around the whole character. Do not add motion blur or scenery.")
            jobs.append({"name": f"enemy:{identity}:run_pose", "group": "enemies", "identity": identity, "state": "run_pose",
                         "request": {"operation": "edit", "inputs": [{"local_path": source["local_path"]}], "prompt": prompt}})
    for identity, (state, source_index, contact, motion) in HERO_ACTIONS.items():
        record = manifest["heroes"][identity]
        source = source_frame(record, "attack", source_index, poses / f"hero-{identity}-{state}.png")
        provenance[f"hero:{identity}:{state}"] = source
        jobs.append({"name": f"hero:{identity}:{state}", "group": "heroes", "identity": identity, "state": state,
                     "contact_frame": contact, "request": {"operation": "animate", "inputs": [{"local_path": source["local_path"]}],
                     "output_frames": 12, "colors": 32, "prompt": motion + " One complete action, then recover; do not loop. Preserve the same character and forward facing direction. Stay within the canvas."}})
        still = source_frame(record, "idle", 0, poses / f"hero-{identity}-standing.png")
        provenance[f"hero:{identity}:standing"] = still
        for reaction, count, motion in [
            ("hit", 6, "A short impact reaction: recoil the shoulders and torso from a forward hit, flinch with a tiny knee bend, then recover to the starting stance. Keep the feet planted and keep all equipment attached. One quick action, not a loop."),
            ("death", 12, "A readable defeat animation: the character loses balance, knees buckle, the torso falls to the ground, and the body settles into a still defeated pose. Keep the recognizable clothing and weapons; no gore, no disappearing or respawning. One action, not a loop.")]:
            jobs.append({"name": f"hero:{identity}:{reaction}", "group": "heroes", "identity": identity, "state": reaction,
                         "contact_frame": 0, "request": {"operation": "animate", "inputs": [{"local_path": still["local_path"]}],
                         "output_frames": count, "colors": 32, "prompt": motion + " Preserve the exact character, palette and facing direction. Keep the complete body within the canvas."}})
    for identity in ACT_ONE:
        source = provenance[f"enemy:{identity}:source"]
        travel = TRAVEL.get(identity, "A natural mechanical marching cycle with alternating feet and counter-moving arms, preserving all equipment. A clear planted supporting foot on each step. Seamless loop, in place.")
        inp = {"local_path": source["local_path"]} if identity in READY_TRAVEL else {"from_job": f"enemy:{identity}:run_pose", "output_index": 0}
        jobs.append({"name": f"enemy:{identity}:run", "group": "enemies", "identity": identity, "state": "run", "contact_frame": 0,
                     "request": {"operation": "animate", "inputs": [inp], "output_frames": 8, "colors": 32,
                     "prompt": travel + " Preserve the same character, facing direction and palette. Keep the complete body inside the canvas; do not translate out of frame."}})
        if identity != "brass_tollkeeper":
            jobs.append({"name": f"enemy:{identity}:attack", "group": "enemies", "identity": identity, "state": "attack", "contact_frame": 6,
                         "request": {"operation": "animate", "inputs": [{"local_path": source["local_path"]}], "output_frames": 12, "colors": 32,
                         "prompt": ENEMY_ACTIONS[identity] + " One complete action, then recover; do not loop. Preserve the same machine, palette, facing direction and every attached part. Keep the complete character within the canvas."}})
    (output / "jobs.json").write_text(json.dumps(jobs, indent=2) + "\n")
    (output / "source-poses.json").write_text(json.dumps(provenance, indent=2) + "\n")
    summary = {"heroes": list(HERO_ACTIONS), "first_act_enemy_sprites": ACT_ONE, "animation_jobs": 59,
               "pose_edit_jobs": 8, "baseline_credits": len(jobs) * 15, "prepared_sources": provenance,
               "scope": "One new native action for every hero, native hero hit/death, and native run/attack for the entire Brass Frontier Act I roster."}
    (output / "plan.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"Prepared {len(jobs)} jobs: 59 animations + 8 pose edits, {len(jobs) * 15} credits; {output / 'jobs.json'}")


def extras(output: Path) -> None:
    manifest = json.loads((PROJECT / "assets/sprite_fusion/manifest.json").read_text())
    output.mkdir(parents=True, exist_ok=True)
    jobs = []
    for identity, (state, source_index, contact, motion) in EXTRA_ACTIONS.items():
        source = source_frame(manifest["heroes"][identity], "attack", source_index,
                              output / "source-poses" / f"hero-{identity}-{state}.png")
        jobs.append({"name": f"hero:{identity}:{state}", "group": "heroes", "identity": identity, "state": state,
                     "contact_frame": contact, "request": {"operation": "animate", "inputs": [{"local_path": source["local_path"]}],
                     "output_frames": 12, "colors": 32, "prompt": motion + " One complete action, then recover; do not loop. Preserve the exact character and facing direction. Stay within the canvas."}})
    (output / "extras.json").write_text(json.dumps(jobs, indent=2) + "\n")
    print(f"Prepared {len(jobs)} optional second action-family jobs: 180 credits; {output / 'extras.json'}")


def lancer_fix(output: Path) -> None:
    manifest = json.loads((PROJECT / "assets/sprite_fusion/manifest.json").read_text())
    # Always use the original owned ready pose, even after the replacement is
    # installed. Padding expands empty space without scaling or repainting him.
    record = dict(manifest["heroes"]["lancer"])
    record["animations"] = {"attack": {"texture": "res://assets/sprite_fusion/animations/hero_lancer_attack.png",
                                      "frames": [{"rect": [0, 0, 80, 80]}]}}
    source = source_frame(record, "attack", 0, output / "source-poses/hero-lancer-quick-v2.png", 128)
    job = {"name": "hero:lancer:attack_v2", "group": "heroes", "identity": "lancer", "state": "attack",
           "output_file": "hero_lancer_attack_v2.png", "contact_frame": 6,
           "request": {"operation": "animate", "inputs": [{"local_path": source["local_path"]}],
                       "output_frames": 12, "colors": 32,
                       "prompt": "Animate this exact teal-cloaked armored spear knight making ONE quick two-handed straight spear thrust and recovery. Start in this forward-facing ready pose, draw the hands and spear back slightly, step into a compact forward thrust, then recover to the original ready stance. A quick precise jab, not an overhead swing or spinning attack. His complete original long spear, including its metal pointed tip, MUST stay visible inside this roomy 128 by 128 canvas in EVERY frame, with a clear transparent margin. Keep the spear almost horizontal during the forward strike. Preserve the exact knight, helmet, plume, cloak, colors and attached equipment. Keep the feet centered in place with only a small planted step; do not move the whole character across the canvas. No added effects, no motion trails, no scenery, no other weapons. One action then recover; do not loop."}}
    output.mkdir(parents=True, exist_ok=True)
    (output / "lancer-fix.json").write_text(json.dumps([job], indent=2) + "\n")
    (output / "lancer-fix-source.json").write_text(json.dumps(source, indent=2) + "\n")
    print(f"Prepared one 15-credit replacement quick-thrust job; {output / 'lancer-fix.json'}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--extras-only", action="store_true")
    parser.add_argument("--lancer-fix-only", action="store_true")
    args = parser.parse_args()
    lancer_fix(args.output) if args.lancer_fix_only else extras(args.output) if args.extras_only else build(args.output)
