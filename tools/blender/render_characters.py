"""PURPOSE: Build and animate the remaining hero classes and the Raider enemy in one background run.

Run: blender --background --python tools/blender/render_characters.py [-- archer mage ...]
Uses the pilot scene's lights, world and camera, and the Warrior's framing, timings and atlas
layout, so every set shares one board scale and foot pivot. Object keyframes, no skeletal rig.
Part-name tags drive the shared poses: "L:" legs, "H:" robe hem, "W:" weapon arm.
"""
import bpy
import json
import math
import sys
from array import array
from pathlib import Path
from mathutils import Matrix, Vector
from bpy_extras.object_utils import world_to_camera_view

if not bpy.app.background:
    raise RuntimeError("Use a separate background Blender process.")
ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/source/blender"
OUTPUT = ROOT / "assets/characters/blender_pilot/animated"
FRAMES = SOURCE / "character_frames"
FRAMES.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE / "abyssal_pilot.blend"))
scene = bpy.context.scene
for obj in scene.objects:
    if obj.type == "MESH":
        obj.hide_render = True
M = bpy.data.materials


def material(name, color, metal=0.0, rough=0.5, emission=0.0):
    mat = M.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = rough
    shader.inputs["Emission Color"].default_value = (*color, 1)
    shader.inputs["Emission Strength"].default_value = emission
    return mat


# Pilot materials keep the new cast in the Warrior's palette.
steel, brass, blade = M["Warrior / blue iron"], M["Warrior / antique brass"], M["Warrior / blade"]
dark, oxblood, bone, teal = M["Deep recess"], M["Warrior / oxblood cloth"], M["Enemy / old ivory"], M["Soul / jade emission"]
skin = material("Cast / weathered skin", (.52, .36, .27), 0, .7)
leather = material("Cast / dark leather", (.16, .09, .05), .05, .7)
forest = material("Archer / forest cloak", (.06, .2, .12), 0, .8)
lavender = material("Mage / dusk robe", (.27, .2, .5), 0, .75)
arcane = material("Mage / arcane light", (.35, .6, 1), .1, .3, 3)
cream = material("Cleric / linen", (.7, .64, .48), 0, .75)
holy = material("Cleric / sunlight", (1, .78, .35), .1, .3, 2.5)
shadow = material("Assassin / night cloth", (.025, .025, .04), .05, .7)
crimson = material("Assassin / crimson", (.4, .02, .04), 0, .7)
ember = material("Assassin / ember eyes", (1, .15, .12), .1, .3, 3)
royal = material("Captain / royal blue", (.05, .1, .36), 0, .75)
rust = material("Raider / rust iron", (.3, .13, .07), .7, .45)
raider_eye = material("Raider / furnace eyes", (1, .4, .08), .1, .3, 3)


def finish(obj, name, mat, parent):
    obj.name = name
    obj.data.materials.append(mat)
    obj.parent = parent
    return obj


def box(name, loc, scale, mat, parent, bevel=.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Soft forged edges", "BEVEL")
        mod.width, mod.segments = bevel, 2
        obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    return finish(obj, name, mat, parent)


def ico(name, loc, scale, mat, parent):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=loc)
    bpy.context.object.scale = scale
    return finish(bpy.context.object, name, mat, parent)


def cone(name, loc, radius, depth, mat, parent, top=0):
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=radius, radius2=top, depth=depth, location=loc)
    return finish(bpy.context.object, name, mat, parent)


def rod(name, start, end, radius, mat, parent):
    delta = Vector(end)-Vector(start)
    obj = cone(name, (Vector(start)+Vector(end))/2, radius, delta.length, mat, parent, radius)
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return obj


def ring(name, loc, radius, thickness, mat, parent):
    bpy.ops.mesh.primitive_torus_add(major_segments=32, minor_segments=6, location=loc,
                                   major_radius=radius, minor_radius=thickness)
    return finish(bpy.context.object, name, mat, parent)


def root(name):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    return obj


def legs(r, x, boot, leg, boot_mat, leg_mat):
    for side in (-x, x):
        box("L:Boot", (side, -.05, boot[2]/2), boot, boot_mat, r)
        box("L:Leg", (side, 0, boot[2] + leg[2]/2 - .04), leg, leg_mat, r)


# Front faces -Y. Every figure stays under ~2.15 so swings keep headroom in the shared camera.
def build_archer():
    r = root("AE / Archer")
    legs(r, .17, (.24, .4, .3), (.2, .22, .5), leather, forest)
    box("Jerkin", (0, 0, 1.05), (.56, .36, .62), leather, r, .08)
    box("Belt", (0, -.01, .8), (.6, .4, .09), brass, r)
    box("Cloak", (0, .22, .95), (.62, .07, .98), forest, r)
    rod("Quiver", (-.12, .25, .85), (.2, .27, 1.5), .09, leather, r)
    for dx in (-.03, .03):
        ico("Fletching", (.2+dx, .28, 1.6), (.05, .04, .1), bone, r)
    ico("Head", (0, -.02, 1.58), (.22, .22, .25), skin, r)
    cone("Hood", (0, .03, 1.72), .32, .6, forest, r, .04)
    box("Face shade", (0, -.2, 1.62), (.3, .04, .12), dark, r, .01)
    for x in (-.07, .07):
        ico("Eye", (x, -.23, 1.6), (.03, .02, .025), teal, r)
    rod("Draw arm", (.31, 0, 1.28), (.4, -.06, .98), .08, leather, r)
    ico("Draw hand", (.41, -.08, .93), (.08, .08, .08), skin, r)
    rod("W:Bow arm", (-.31, 0, 1.28), (-.42, -.3, 1.12), .08, leather, r)
    ico("W:Bow hand", (-.43, -.34, 1.1), (.08, .08, .08), skin, r)
    rod("W:Bow upper limb", (-.44, -.4, 1.12), (-.44, -.3, 1.68), .035, brass, r)
    rod("W:Bow lower limb", (-.44, -.4, 1.12), (-.44, -.3, .56), .035, brass, r)
    rod("W:Bowstring", (-.44, -.28, 1.68), (-.44, -.28, .56), .008, bone, r)
    rod("W:Nocked arrow", (-.44, -.62, 1.12), (-.44, -.1, 1.12), .012, teal, r)
    return r, {"shoulder": (-.31, 0, 1.28), "attack": "cast", "amount": -.35}


def build_mage():
    r = root("AE / Mage")
    cone("Robe", (0, 0, .62), .48, 1.24, lavender, r, .22)
    for x in (-.24, 0, .24):
        cone("H:Robe hem", (x, -.12, .18), .14, .36, dark, r, .06)
    box("Sash", (0, -.02, .95), (.5, .42, .08), brass, r)
    ico("Mantle", (0, 0, 1.22), (.46, .3, .24), lavender, r)
    ico("Head", (0, -.03, 1.49), (.2, .2, .23), skin, r)
    beard = cone("Beard", (0, -.17, 1.34), .12, .3, bone, r)
    beard.rotation_euler[0] = math.pi
    for x in (-.07, .07):
        ico("Eye", (x, -.21, 1.53), (.03, .02, .025), arcane, r)
    cone("Hat brim", (0, 0, 1.66), .42, .06, lavender, r, .4)
    cone("Hat", (0, .04, 1.91), .26, .5, lavender, r).rotation_euler[0] = .15
    rod("Arm", (-.36, 0, 1.22), (-.42, -.1, .95), .09, lavender, r)
    ico("Hand", (-.43, -.12, .9), (.08, .08, .08), skin, r)
    rod("W:Staff arm", (.36, 0, 1.22), (.48, -.15, 1.0), .09, lavender, r)
    ico("W:Staff hand", (.5, -.18, .97), (.08, .08, .08), skin, r)
    rod("W:Staff", (.52, -.2, .15), (.52, -.2, 1.74), .04, leather, r)
    ico("W:Staff orb", (.52, -.2, 1.87), (.12, .12, .12), arcane, r)
    return r, {"shoulder": (.36, 0, 1.22), "attack": "cast", "amount": .6}


def build_cleric():
    r = root("AE / Cleric")
    cone("Robe", (0, 0, .62), .5, 1.24, cream, r, .25)
    box("H:Tabard", (0, -.27, .55), (.24, .05, .9), holy, r, .01)
    for x in (-.28, .28):
        cone("H:Robe hem", (x, -.1, .18), .15, .36, cream, r, .07)
    box("Rope belt", (0, -.02, .95), (.52, .44, .07), brass, r)
    ico("Mantle", (0, 0, 1.25), (.5, .32, .24), cream, r)
    ico("Cowl", (0, .05, 1.55), (.27, .27, .28), cream, r)
    ico("Head", (0, -.05, 1.53), (.2, .2, .22), skin, r)
    for x in (-.07, .07):
        ico("Eye", (x, -.23, 1.56), (.03, .02, .025), dark, r)
    box("Mitre", (0, 0, 1.84), (.24, .16, .3), cream, r)
    box("Mitre band", (0, -.085, 1.84), (.05, .02, .28), brass, r, .005)
    cone("Mitre peak", (0, 0, 2.04), .14, .14, cream, r)
    ring("Halo", (0, .2, 1.72), .24, .02, holy, r).rotation_euler[0] = math.pi/2
    rod("Arm", (-.38, 0, 1.25), (-.44, -.15, 1.0), .09, cream, r)
    box("Tome", (-.46, -.2, .98), (.26, .08, .32), oxblood, r, .02)
    box("Tome clasp", (-.46, -.245, .98), (.06, .02, .1), brass, r, .005)
    rod("W:Mace arm", (.38, 0, 1.25), (.46, -.12, 1.0), .09, cream, r)
    ico("W:Mace hand", (.47, -.15, .96), (.08, .08, .08), skin, r)
    rod("W:Mace handle", (.48, -.15, .82), (.48, -.15, 1.48), .035, brass, r)
    ico("W:Mace head", (.48, -.15, 1.56), (.13, .13, .13), steel, r)
    ico("W:Mace light", (.48, -.27, 1.56), (.05, .03, .05), holy, r)
    return r, {"shoulder": (.38, 0, 1.25), "attack": "cast", "amount": .6}


def build_assassin():
    r = root("AE / Assassin")
    legs(r, .16, (.22, .38, .26), (.19, .22, .45), shadow, leather)
    box("Body", (0, -.03, .96), (.5, .34, .55), shadow, r, .08).rotation_euler[0] = .12
    box("Sash", (0, -.02, .75), (.54, .38, .08), crimson, r)
    box("Scarf", (0, -.05, 1.27), (.4, .36, .14), crimson, r)
    box("Scarf tail", (.12, .22, 1.08), (.1, .05, .45), crimson, r, .01)
    ico("Head", (0, -.04, 1.47), (.21, .21, .24), shadow, r)
    cone("Hood", (0, .03, 1.56), .29, .5, shadow, r, .04)
    box("Eye slit", (0, -.23, 1.5), (.22, .02, .035), ember, r, .005)
    rod("Off arm", (-.31, 0, 1.18), (-.4, -.12, .92), .08, shadow, r)
    ico("Off hand", (-.41, -.14, .88), (.07, .07, .07), leather, r)
    box("Reverse dagger", (-.42, -.15, .7), (.05, .07, .32), blade, r, .01)
    rod("W:Dagger arm", (.31, 0, 1.18), (.42, -.15, .95), .08, shadow, r)
    ico("W:Dagger hand", (.43, -.18, .93), (.07, .07, .07), leather, r)
    box("W:Dagger", (.44, -.38, .95), (.05, .34, .07), blade, r, .01)
    box("W:Dagger guard", (.44, -.22, .95), (.14, .03, .04), brass, r, .005)
    # Negative: the dagger sits below the shoulder, so a forward swing would hide it on the strike frame.
    return r, {"shoulder": (.31, 0, 1.18), "attack": "melee", "amount": -.8}


def build_captain():
    r = root("AE / Captain")
    legs(r, .2, (.3, .5, .3), (.26, .3, .48), steel, steel)
    box("Cuirass", (0, 0, 1.08), (.72, .44, .6), steel, r, .1)
    box("Tabard", (0, -.25, .72), (.5, .05, .7), royal, r, .01)
    box("Sash", (0, -.24, 1.08), (.12, .05, .7), brass, r, .01).rotation_euler[1] = .6
    box("Half cape", (0, .28, 1.0), (.66, .07, .95), royal, r)
    for x in (-.46, .46):
        ico("Pauldron", (x, 0, 1.33), (.26, .3, .2), brass, r)
    ico("Head", (0, -.04, 1.64), (.21, .21, .24), skin, r)
    ico("Helm", (0, .02, 1.73), (.26, .26, .23), steel, r)
    box("Helm brow", (0, -.2, 1.73), (.4, .06, .05), brass, r, .01)
    cone("Plume", (0, .1, 1.97), .08, .36, crimson, r).rotation_euler[0] = -.5
    box("Arm", (-.5, 0, 1.03), (.22, .26, .48), steel, r)
    ico("Round shield rim", (-.62, -.28, 1.0), (.36, .08, .36), brass, r)
    ico("Round shield face", (-.62, -.34, 1.0), (.29, .05, .29), royal, r)
    ico("Shield mark", (-.62, -.39, 1.0), (.08, .03, .08), teal, r)
    box("W:Spear arm", (.5, 0, 1.03), (.22, .26, .48), steel, r)
    ico("W:Gauntlet", (.52, -.1, .8), (.16, .17, .17), steel, r)
    rod("W:Spear shaft", (.55, -.12, .2), (.55, -.12, 1.9), .03, leather, r)
    cone("W:Spear head", (.55, -.12, 1.99), .06, .2, blade, r)
    box("W:Pennant", (.67, -.12, 1.72), (.22, .02, .24), royal, r, .005)
    return r, {"shoulder": (.5, 0, 1.28), "attack": "melee", "amount": .9}


def build_raider():
    r = root("AE / Raider")
    legs(r, .27, (.36, .55, .34), (.32, .34, .48), rust, leather)
    box("Hunched torso", (0, .03, 1.1), (.95, .6, .7), rust, r, .12).rotation_euler[0] = .18
    ico("Fur belly", (0, -.12, .86), (.5, .34, .25), leather, r)
    for sign in (-1, 1):
        ico("Spiked pauldron", (sign*.58, .02, 1.42), (.34, .38, .25), rust, r)
        cone("Pauldron spike", (sign*.64, .02, 1.66), .07, .3, bone, r)
        horn = cone("Helm horn", (sign*.3, -.1, 1.88), .08, .42, bone, r)
        horn.rotation_euler[1] = sign*.6
    box("Helm", (0, -.14, 1.6), (.46, .46, .44), rust, r, .1)
    box("Visor slit", (0, -.38, 1.62), (.34, .04, .07), dark, r, .01)
    for x in (-.09, .09):
        ico("Eye", (x, -.4, 1.62), (.04, .02, .03), raider_eye, r)
    box("Arm", (-.62, 0, 1.05), (.28, .3, .55), rust, r)
    ico("Fist", (-.64, -.08, .76), (.17, .18, .18), leather, r)
    box("W:Axe arm", (.62, 0, 1.05), (.28, .3, .55), rust, r)
    ico("W:Axe fist", (.64, -.12, .76), (.17, .18, .18), leather, r)
    rod("W:Axe haft", (.66, -.15, .55), (.66, -.15, 1.85), .045, leather, r)
    box("W:Axe head", (.82, -.15, 1.68), (.3, .06, .36), blade, r, .02)
    cone("W:Axe back spike", (.55, -.15, 1.68), .05, .2, blade, r).rotation_euler[1] = -math.pi/2
    return r, {"shoulder": (.62, 0, 1.33), "attack": "melee", "amount": 1.0}


BUILDERS = {"archer": build_archer, "mage": build_mage, "cleric": build_cleric,
            "assassin": build_assassin, "captain": build_captain, "raider": build_raider}
argv = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
names = argv or list(BUILDERS)
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
# Strike/release is frame zero: damage has already happened in the simulation.
CURVES = {"melee": [1.0, 1.35, 1.1, .65, .25, 0], "cast": [1.0, 1.15, .9, .55, .22, 0]}


def pivot_rotation(pivot, angle, axis):
    return Matrix.Translation(pivot) @ Matrix.Rotation(angle, 4, axis) @ Matrix.Translation(-Vector(pivot))


def pose(parts, base, spec, state, frame):
    """Feet and hem stay on the cell; rigid pieces articulate around simple pivots."""
    phase = frame / 6 * math.tau
    robed = not any(obj.name.startswith("L:") for obj in parts)
    for obj in parts:
        mat = base[obj.name].copy()
        loc = mat.translation.copy()
        leg, hem, weapon = (obj.name.startswith(tag) for tag in ("L:", "H:", "W:"))
        body = not (leg or hem)
        if state == "idle":
            if body:
                mat = Matrix.Translation((0, 0, .022*math.sin(phase))) @ mat
            elif hem:
                mat = pivot_rotation((loc.x, loc.y, .4), .05*math.sin(phase + loc.x*4), "X") @ mat
        elif state == "move":
            stride = math.sin(phase + (math.pi if loc.x < 0 else 0))
            if leg:
                mat = Matrix.Translation((0, stride*.17, max(0, stride)*.07)) @ mat
            elif hem:
                mat = pivot_rotation((loc.x, loc.y, .4), .22 + .06*math.sin(phase*2 + loc.x*4), "X") @ mat
            else:
                if robed:
                    mat = pivot_rotation((0, 0, .1), .1, "X") @ mat
                mat = Matrix.Translation((0, 0, .025*math.cos(phase*2))) @ mat
                if weapon:
                    mat = pivot_rotation(spec["shoulder"], .14*math.sin(phase), "X") @ mat
        elif state == "attack":
            strike = CURVES[spec["attack"]][frame]
            if weapon:
                mat = pivot_rotation(spec["shoulder"], spec["amount"]*strike, "X") @ mat
            elif body:
                mat = pivot_rotation((0, 0, .6), .06*strike, "X") @ mat
        elif state == "hit":
            recoil = [1, .85, .55, .25, .1, 0][frame]
            if body:
                mat = pivot_rotation((0, 0, .5), -.13*recoil, "X") @ mat
        elif state == "death":
            collapse = frame/5
            # Compact collapse stays inside one cell instead of a long corpse.
            mat = Matrix.Diagonal((1, 1, 1-.55*collapse, 1)) @ mat
            if body:
                mat = pivot_rotation((0, 0, .35), .5*collapse, "X") @ mat
        obj.matrix_basis = mat


cast = {}
# Build and key every character so the saved .blend is always complete; render only the requested ones.
for name in BUILDERS:
    actor, spec = BUILDERS[name]()
    parts = list(actor.children_recursive)
    for obj in parts:
        obj.hide_render = True
    base = {obj.name: obj.matrix_basis.copy() for obj in parts}
    # Save editable object keyframes for each of the five six-frame strips.
    for row, state in enumerate(STATES):
        for frame in range(6):
            pose(parts, base, spec, state, frame)
            for obj in parts:
                for channel in ("location", "rotation_euler", "scale"):
                    obj.keyframe_insert(data_path=channel, frame=row*6+frame+1)
    cast[name] = (actor, parts)
for row, state in enumerate(STATES):
    scene.timeline_markers.new(state, frame=row*6+1)
scene.frame_set(1)
bpy.context.view_layer.update()
anchor = world_to_camera_view(scene, camera, Vector((0, 0, 0)))
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "character_animation_pilot.blend"))

for name in names:
    actor, parts = cast[name]
    for obj in parts:
        obj.hide_render = False
    atlas_paths = {}
    for facing, angle in FACINGS.items():
        actor.rotation_euler.z = angle
        atlas_pixels = array("f", [0]) * (1536*1280*4)
        for row, state in enumerate(STATES):
            for frame in range(6):
                scene.frame_set(row*6+frame+1)
                path = FRAMES / f"{name}_{state}_{facing}_{frame}.png"
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
        atlas = bpy.data.images.new(f"{name} {facing} atlas", width=1536, height=1280, alpha=True)
        atlas.pixels.foreach_set(atlas_pixels)
        atlas.filepath_raw = str(OUTPUT / f"{name}_{facing}.png")
        atlas.file_format = "PNG"
        atlas.save()
        atlas_paths[facing] = str(Path(atlas.filepath_raw).relative_to(ROOT)).replace("\\", "/")
        bpy.data.images.remove(atlas)
    for obj in parts:
        obj.hide_render = True
    (OUTPUT / f"{name}_manifest.json").write_text(json.dumps({
        "author": "Original Abyssal Echoes procedural geometry and object-keyframe animation",
        "source": "art/source/blender/character_animation_pilot.blend",
        "generator": "tools/blender/render_characters.py",
        "frame_size": [256, 256], "columns": 6, "rows": STATES,
        "durations_seconds": DURATIONS,
        "foot_pivot_normalized": [anchor.x, 1-anchor.y],
        "facings": atlas_paths,
        "attack_contact_frame": 0,
        "notes": "East/west use three-quarter poses. Death holds final frame. No root motion.",
    }, indent=2), encoding="utf-8")
    print(f"CHARACTER COMPLETE: {name}", flush=True)
print("ALL CHARACTERS COMPLETE", flush=True)
