"""PURPOSE: Render a five-state, four-facing Riftbound sentinel animation for the Hex Weaver role.

Run in background Blender. Mirrors render_warrior_animation.py: the same camera, frame size,
state timings, and atlas layout, so both characters share one board scale and foot pivot.
Uses object keyframes, not a skeletal rig. Intermediate frames stay in an ignored directory.
"""
import bpy
import json
import math
from array import array
from pathlib import Path
from mathutils import Matrix, Vector
from bpy_extras.object_utils import world_to_camera_view

if not bpy.app.background:
    raise RuntimeError("Use a separate background Blender process.")
ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/source/blender"
OUTPUT = ROOT / "assets/characters/blender_pilot/animated"
FRAMES = SOURCE / "riftbound_frames"
OUTPUT.mkdir(parents=True, exist_ok=True)
FRAMES.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE / "abyssal_pilot.blend"))
scene = bpy.context.scene
actor = bpy.data.objects["AE / Riftbound sentinel"]
parts = list(actor.children_recursive)
base = {obj.name: obj.matrix_basis.copy() for obj in parts}
for obj in scene.objects:
    if obj.type == "MESH":
        obj.hide_render = obj not in parts
actor.location = (0, 0, 0)
actor.rotation_euler = (0, 0, 0)
# At full size the staff tip sits 1-5 px from the top of the shared camera and clips on any tilt.
# Scaling about the feet keeps the shared foot pivot; the sentinel still stands taller than the Warrior.
actor.scale = (.9, .9, .9)
camera = scene.camera
camera.location = (0, -7, 5)
camera.rotation_euler = (Vector((0, 0, 1.15))-camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.ortho_scale = 3.1
scene.render.resolution_x = scene.render.resolution_y = 256
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.color_mode = "RGBA"
scene.render.image_settings.file_format = "PNG"
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.fps = 12
scene.frame_start, scene.frame_end = 1, 30
STATES = ["idle", "move", "attack", "hit", "death"]
DURATIONS = {"idle": 1.2, "move": .6, "attack": .42, "hit": .24, "death": .72}
FACINGS = {"south": 0, "east": math.pi/4, "north": math.pi, "west": -math.pi/4}
SHOULDER = (.49, 0, 1.27)


def pivot_rotation(pivot, angle, axis):
    return Matrix.Translation(pivot) @ Matrix.Rotation(angle, 4, axis) @ Matrix.Translation(-Vector(pivot))


def pivot_scale(pivot, factor):
    return Matrix.Translation(pivot) @ Matrix.Diagonal((factor, factor, factor, 1)) @ Matrix.Translation(-Vector(pivot))


def pose(state, frame):
    """The robe hem stays on its cell; the specter articulates rigid pieces around simple pivots."""
    phase = frame / 6 * math.tau
    for obj in parts:
        mat = base[obj.name].copy()
        loc = mat.translation.copy()
        hem = obj.name.startswith("Robe shard")
        staff_arm = obj.name.startswith(("Ritual staff", "Floating staff crystal")) or (
            obj.name.startswith(("Upper arm", "Claw")) and loc.x > 0)
        glow = obj.name.startswith(("Floating staff crystal", "Chest crystal", "Witchlight eye"))
        if state == "idle":
            if hem:
                mat = pivot_rotation((loc.x, loc.y, .5), .05*math.sin(phase + loc.x*4), "X") @ mat
            else:
                mat = Matrix.Translation((0, 0, .03*math.sin(phase))) @ mat
            if obj.name.startswith("Floating staff crystal"):
                mat = Matrix.Translation((0, 0, .04*math.sin(phase + 1))) @ mat
        elif state == "move":
            # A forward glide: lean into travel, hem trails behind.
            if hem:
                mat = pivot_rotation((loc.x, loc.y, .5), .22 + .06*math.sin(phase*2 + loc.x*4), "X") @ mat
            else:
                mat = pivot_rotation((0, 0, .1), .12, "X") @ Matrix.Translation((0, 0, .025*math.cos(phase*2))) @ mat
        elif state == "attack":
            # Release is the first frame: damage has already occurred in the simulation.
            thrust = [1.0, 1.15, .9, .55, .22, 0][frame]
            flare = [1.7, 1.45, 1.25, 1.12, 1.04, 1][frame]
            if staff_arm:
                mat = pivot_rotation(SHOULDER, .75*thrust, "X") @ mat
            elif not hem:
                mat = pivot_rotation((0, 0, .3), .07*thrust, "X") @ mat
            if glow:
                mat = pivot_scale(mat.translation.copy(), flare) @ mat
        elif state == "hit":
            recoil = [1, .85, .55, .25, .1, 0][frame]
            if not hem:
                mat = pivot_rotation((0, 0, .3), -.16*recoil, "X") @ mat
            if obj.name.startswith("Witchlight eye"):
                mat = pivot_scale(mat.translation.copy(), 1 - .5*recoil) @ mat
        elif state == "death":
            collapse = frame/5
            # The robe folds onto its own cell; the staff tips but stays inside the frame.
            mat = Matrix.Diagonal((1 + .12*collapse, 1 + .12*collapse, 1 - .62*collapse, 1)) @ mat
            if staff_arm:
                mat = pivot_rotation((.68, -.1, .05), -.5*collapse, "Y") @ mat
            elif not hem:
                mat = pivot_rotation((0, 0, .2), .35*collapse, "X") @ mat
            if glow:
                mat = pivot_scale(mat.translation.copy(), 1 - .7*collapse) @ mat
        obj.matrix_basis = mat


# Save editable object keyframes for each of the five six-frame strips.
for row, state in enumerate(STATES):
    scene.timeline_markers.new(state, frame=row*6+1)
    for frame in range(6):
        pose(state, frame)
        for obj in parts:
            for channel in ("location", "rotation_euler", "scale"):
                obj.keyframe_insert(data_path=channel, frame=row*6+frame+1)
scene.frame_set(1)
bpy.context.view_layer.update()
anchor = world_to_camera_view(scene, camera, Vector((0, 0, 0)))
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "riftbound_animation_pilot.blend"))

atlas_paths = {}
for facing, angle in FACINGS.items():
    actor.rotation_euler.z = angle
    atlas_pixels = array("f", [0]) * (1536*1280*4)
    for row, state in enumerate(STATES):
        for frame in range(6):
            scene.frame_set(row*6+frame+1)
            path = FRAMES / f"{state}_{facing}_{frame}.png"
            scene.render.filepath = str(path)
            bpy.ops.render.render(write_still=True)
            img = bpy.data.images.load(str(path), check_existing=False)
            pixels = array("f", [0]) * (256*256*4)
            img.pixels.foreach_get(pixels)
            # Blender image buffers start at bottom-left; atlas rows are top-to-bottom.
            for y in range(256):
                dest = (((4-row)*256+y)*1536+frame*256)*4
                atlas_pixels[dest:dest+1024] = pixels[y*1024:(y+1)*1024]
            bpy.data.images.remove(img)
    atlas = bpy.data.images.new(f"Riftbound {facing} atlas", width=1536, height=1280, alpha=True)
    atlas.pixels.foreach_set(atlas_pixels)
    atlas.filepath_raw = str(OUTPUT / f"riftbound_{facing}.png")
    atlas.file_format = "PNG"
    atlas.save()
    atlas_paths[facing] = str(Path(atlas.filepath_raw).relative_to(ROOT)).replace("\\", "/")
    bpy.data.images.remove(atlas)
    print(f"ATLAS COMPLETE: {facing}", flush=True)

(OUTPUT / "riftbound_manifest.json").write_text(json.dumps({
    "author": "Original Abyssal Echoes procedural geometry and object-keyframe animation",
    "source": "art/source/blender/riftbound_animation_pilot.blend",
    "generator": "tools/blender/render_riftbound_animation.py",
    "game_role": "hexer (Hex Weaver and magic-attacking run enemies)",
    "frame_size": [256, 256], "columns": 6, "rows": STATES,
    "durations_seconds": DURATIONS,
    "foot_pivot_normalized": [anchor.x, 1-anchor.y],
    "facings": atlas_paths,
    "attack_contact_frame": 0,
    "notes": "Ranged cast; release is frame zero. East/west use three-quarter poses. Death holds final frame. No root motion.",
}, indent=2), encoding="utf-8")
print("RIFTBOUND ANIMATION COMPLETE: 120 frames, 4 atlases", flush=True)
