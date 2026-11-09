"""PURPOSE: Render a five-state, four-facing Warrior animation pilot from the saved model.

Run in background Blender. Uses object keyframes, not a skeletal rig. Outputs four
6-column/5-row atlases; intermediate frames stay in the ignored authoring directory.
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
FRAMES = SOURCE / "warrior_frames"
OUTPUT.mkdir(parents=True, exist_ok=True)
FRAMES.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE / "abyssal_pilot.blend"))
scene = bpy.context.scene
hero = bpy.data.objects["AE / Warrior"]
parts = list(hero.children_recursive)
base = {obj.name: obj.matrix_basis.copy() for obj in parts}
for obj in scene.objects:
    if obj.type == "MESH":
        obj.hide_render = obj not in parts
hero.location = (0, 0, 0)
hero.rotation_euler = (0, 0, 0)
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


def pivot_rotation(pivot, angle, axis):
    return Matrix.Translation(pivot) @ Matrix.Rotation(angle, 4, axis) @ Matrix.Translation(-Vector(pivot))


def pose(state, frame):
    """Keep the root/feet anchored; articulate rigid armor pieces around simple pivots."""
    phase = frame / 6 * math.tau
    for obj in parts:
        mat = base[obj.name].copy()
        loc = mat.translation
        leg = obj.name.startswith(("Boot", "Greave", "Knee guard"))
        sword_arm = obj.name.startswith("Sword") or (obj.name.startswith(("Arm.", "Gauntlet.")) and loc.x > 0)
        if state == "idle" and not leg:
            mat = Matrix.Translation((0, 0, .022*math.sin(phase))) @ mat
        elif state == "move":
            stride = math.sin(phase + (math.pi if loc.x < 0 else 0))
            if leg:
                mat = Matrix.Translation((0, stride*.17, max(0, stride)*.07)) @ mat
            else:
                mat = Matrix.Translation((0, 0, .025*math.cos(phase*2))) @ mat
                if sword_arm:
                    mat = pivot_rotation((.53, 0, 1.3), .16*math.sin(phase), "X") @ mat
        elif state == "attack":
            # Contact is the first frame: damage has already occurred in the simulation.
            swing = [1.0, 1.35, 1.1, .65, .25, 0][frame]
            if sword_arm:
                mat = pivot_rotation((.53, 0, 1.3), swing, "X") @ mat
            elif not leg:
                mat = pivot_rotation((0, 0, .85), .06*swing, "X") @ mat
        elif state == "hit":
            recoil = [1, .85, .55, .25, .1, 0][frame]
            if not leg:
                mat = pivot_rotation((0, 0, .65), -.13*recoil, "X") @ mat
        elif state == "death":
            collapse = frame/5
            # Compact kneeling collapse stays inside one cell instead of a long corpse.
            mat = Matrix.Diagonal((1, 1, 1-.55*collapse, 1)) @ mat
            if not leg:
                mat = pivot_rotation((0, 0, .35), .5*collapse, "X") @ mat
        obj.matrix_basis = mat


# Save editable object keyframes for each of the five six-frame strips.
for row, state in enumerate(STATES):
    marker = scene.timeline_markers.new(state, frame=row*6+1)
    for frame in range(6):
        pose(state, frame)
        for obj in parts:
            for channel in ("location", "rotation_euler", "scale"):
                obj.keyframe_insert(data_path=channel, frame=row*6+frame+1)
scene.frame_set(1)
bpy.context.view_layer.update()
anchor = world_to_camera_view(scene, camera, Vector((0, 0, 0)))
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "warrior_animation_pilot.blend"))

atlas_paths = {}
for facing, angle in FACINGS.items():
    hero.rotation_euler.z = angle
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
    atlas = bpy.data.images.new(f"Warrior {facing} atlas", width=1536, height=1280, alpha=True)
    atlas.pixels.foreach_set(atlas_pixels)
    atlas.filepath_raw = str(OUTPUT / f"warrior_{facing}.png")
    atlas.file_format = "PNG"
    atlas.save()
    atlas_paths[facing] = str(Path(atlas.filepath_raw).relative_to(ROOT)).replace("\\", "/")
    bpy.data.images.remove(atlas)
    print(f"ATLAS COMPLETE: {facing}", flush=True)

(OUTPUT / "manifest.json").write_text(json.dumps({
    "author": "Original Abyssal Echoes procedural geometry and object-keyframe animation",
    "source": "art/source/blender/warrior_animation_pilot.blend",
    "generator": "tools/blender/render_warrior_animation.py",
    "frame_size": [256, 256], "columns": 6, "rows": STATES,
    "durations_seconds": DURATIONS,
    "foot_pivot_normalized": [anchor.x, 1-anchor.y],
    "facings": atlas_paths,
    "attack_contact_frame": 0,
    "notes": "East/west use three-quarter poses. Death holds final frame. No root motion.",
}, indent=2), encoding="utf-8")
print("WARRIOR ANIMATION COMPLETE: 120 frames, 4 atlases", flush=True)
