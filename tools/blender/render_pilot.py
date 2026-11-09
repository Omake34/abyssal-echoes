"""PURPOSE: Build and render the original Abyssal Echoes art pilot in background Blender.

Run: blender --background --python tools/blender/render_pilot.py
Only pilot-owned output files are replaced. Never run in an interactive scene.
"""

import bpy
import json
import math
import random
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

if not bpy.app.background:
    raise RuntimeError("Run this generator in a separate background Blender process.")

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/source/blender"
PREVIEW = ROOT / "art/previews/blender_pilot"
SPRITES = ROOT / "assets/characters/blender_pilot"
for folder in (SOURCE, PREVIEW, SPRITES):
    folder.mkdir(parents=True, exist_ok=True)
(SOURCE / ".gdignore").touch()
bpy.ops.wm.read_factory_settings(use_empty=True)
random.seed(17)


def material(name, color, metal=0.0, rough=0.5, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = rough
    shader.inputs["Emission Color"].default_value = (*color, 1)
    shader.inputs["Emission Strength"].default_value = emission
    return mat


steel = material("Warrior / blue iron", (0.12, 0.20, 0.28), .75, .32)
edge = material("Warrior / antique brass", (.65, .36, .12), .72, .32)
blade = material("Warrior / blade", (.5, .66, .72), .85, .22)
dark = material("Deep recess", (.012, .019, .03), .1)
cloth = material("Warrior / oxblood cloth", (.23, .025, .043), 0, .8)
teal = material("Soul / jade emission", (.08, .85, .66), .2, .3, 2.4)
violet = material("Enemy / amethyst", (.25, .06, .42), .45, .34)
bone = material("Enemy / old ivory", (.59, .55, .43), .1, .6)
glow = material("Enemy / violet fire", (.63, .12, 1), .1, .3, 3)
stone = [material(f"Slate {i}", (.055+i*.009, .07+i*.009, .09+i*.012), .15, .77) for i in range(4)]
trim = material("Architecture / basalt", (.026, .033, .055), .3, .5)


def finish(obj, name, mat, parent=None):
    obj.name = name
    obj.data.materials.append(mat)
    if parent:
        obj.parent = parent
    return obj


def box(name, loc, scale, mat, parent=None, bevel=.05):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Soft forged edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    return finish(obj, name, mat, parent)


def ico(name, loc, scale, mat, parent=None):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat, parent)


def cone(name, loc, radius, depth, mat, parent=None, top=0):
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=radius, radius2=top, depth=depth, location=loc)
    return finish(bpy.context.object, name, mat, parent)


def rod(name, start, end, radius, mat, parent=None):
    delta = Vector(end)-Vector(start)
    obj = cone(name, (Vector(start)+Vector(end))/2, radius, delta.length, mat, parent, radius)
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return obj


def ring(name, loc, radius, thickness, mat, parent=None):
    bpy.ops.mesh.primitive_torus_add(major_segments=48, minor_segments=6, location=loc,
                                   major_radius=radius, minor_radius=thickness)
    return finish(bpy.context.object, name, mat, parent)


def root(name):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    return obj


# Front faces -Y; exaggerated armor shapes stay readable at sprite scale.
hero = root("AE / Warrior")
for x in (-.24, .24):
    box("Boot", (x, -.08, .17), (.34, .56, .33), steel, hero)
    box("Greave", (x, 0, .55), (.29, .32, .51), steel, hero)
    ico("Knee guard", (x, -.2, .65), (.19, .12, .19), edge, hero)
box("Armored torso", (0, 0, 1.13), (.8, .48, .68), steel, hero, .13)
box("Waist belt", (0, -.01, .85), (.78, .54, .12), edge, hero)
box("Tabard", (0, -.29, .68), (.32, .055, .6), cloth, hero)
ico("Heart seal", (0, -.28, 1.2), (.13, .06, .2), edge, hero)
ico("Heart light", (0, -.34, 1.2), (.065, .035, .1), teal, hero)
box("Cape", (0, .31, .97), (.73, .085, 1.07), cloth, hero)
for x in (-.53, .53):
    ico("Pauldron", (x, 0, 1.39), (.33, .37, .25), edge, hero)
    box("Arm", (x, 0, 1.05), (.25, .28, .52), steel, hero)
    ico("Gauntlet", (x, -.08, .8), (.19, .2, .2), steel, hero)
box("Helm", (0, -.015, 1.79), (.6, .53, .56), steel, hero, .14)
box("Black visor", (0, -.285, 1.81), (.47, .045, .11), dark, hero, .015)
box("Visor light", (0, -.312, 1.82), (.35, .012, .026), teal, hero, .005)
box("Helm ridge", (0, -.295, 1.71), (.055, .04, .21), edge, hero)
box("Helm crest", (0, .01, 2.1), (.08, .36, .13), edge, hero)
shield = ico("Kite shield / brass rim", (-.69, -.3, 1.0), (.4, .13, .57), edge, hero)
ico("Kite shield / iron face", (-.69, -.41, 1.0), (.32, .065, .47), steel, hero)
ico("Kite shield / soul mark", (-.69, -.48, 1.04), (.095, .035, .23), teal, hero)
rod("Sword grip", (.6, -.15, .78), (.7, -.15, 1.08), .055, dark, hero)
rod("Sword guard", (.48, -.15, 1.07), (.91, -.15, .97), .05, edge, hero)
sword = box("Sword blade", (.85, -.15, 1.52), (.14, .065, 1.0), blade, hero, .015)
sword.rotation_euler[1] = .3
cone("Sword point", (1.015, -.15, 2.05), .09, .2, blade, hero).rotation_euler[1] = .3

enemy = root("AE / Riftbound sentinel")
cone("Tattered spectral body", (0, 0, .68), .53, 1.25, violet, enemy, .23)
for x in (-.29, 0, .29):
    cone("Robe shard", (x, -.14, .25), .17, .5, dark, enemy, .07)
ico("Shoulder mantle", (0, 0, 1.25), (.65, .34, .36), violet, enemy)
ico("Hood", (0, 0, 1.73), (.43, .32, .5), dark, enemy)
ico("Ivory mask", (0, -.26, 1.7), (.29, .105, .33), bone, enemy)
for x in (-.12, .12):
    box("Eye socket", (x, -.355, 1.76), (.13, .04, .1), dark, enemy, .01)
    ico("Witchlight eye", (x, -.383, 1.76), (.045, .025, .04), glow, enemy)
cone("Jaw", (0, -.3, 1.42), .13, .24, bone, enemy, .2)
for sign in (-1, 1):
    horn = cone("Crown horn", (sign*.36, .01, 2.03), .13, .65, violet, enemy)
    horn.rotation_euler[1] = sign*.43
    rod("Upper arm", (sign*.49, 0, 1.27), (sign*.62, -.03, .94), .11, violet, enemy)
    ico("Claw", (sign*.63, -.08, .85), (.15, .15, .2), bone, enemy)
rod("Ritual staff", (.68, -.1, .14), (.68, -.1, 2.12), .045, bone, enemy)
ico("Floating staff crystal", (.68, -.1, 2.3), (.16, .13, .29), glow, enemy)
ico("Chest crystal", (0, -.3, 1.18), (.12, .07, .22), glow, enemy)

hero.location = (-1.65, -.55, .12)
hero.rotation_euler[2] = -.3
enemy.location = (1.6, .65, .12)
enemy.rotation_euler[2] = .4
characters = set(hero.children_recursive) | set(enemy.children_recursive)

# Modular ruin kit: tiles, chamfered plinth, broken pillars, and soul braziers.
box("Arena plinth", (0, 0, -.2), (8, 6.2, .45), trim, bevel=.18)
for x in range(8):
    for y in range(6):
        box("Slate floor tile", (x-3.5, y-2.5, .045), (.96, .96, .14), random.choice(stone), bevel=.035)
ring("Ritual outer inlay", (0, 0, .13), 2.3, .018, edge)
ring("Ritual inner inlay", (0, 0, .13), 2.12, .012, edge)
for angle in range(0, 360, 30):
    a = math.radians(angle)
    mark = box("Radial rune", (2.22*math.cos(a), 2.22*math.sin(a), .14), (.08, .18, .012), teal, bevel=.005)
    mark.rotation_euler[2] = a
for x, y, h in ((-3.35, 2.3, 1.5), (3.35, 2.3, 2.05), (-3.35, -2.3, .5), (3.35, -2.3, .65)):
    box("Pillar foot", (x, y, .2), (.7, .7, .24), trim)
    box("Broken pillar", (x, y, h/2+.3), (.43, .43, h), stone[1])
    box("Pillar band", (x, y, .55), (.49, .49, .12), edge)
    ico("Soul flame", (x, y, h+.51), (.13, .13, .29), teal)
    data = bpy.data.lights.new("Brazier glow", "POINT")
    data.energy = 30
    data.color = (.15, 1, .72)
    light = bpy.data.objects.new("Brazier glow", data)
    bpy.context.collection.objects.link(light)
    light.location = (x, y, h+.65)

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.world = bpy.data.worlds.new("Abyss atmosphere")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.065, .085, .15, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = .35


def area(name, loc, color, power, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.color, data.shape, data.size = power, color, "DISK", size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = (Vector((0, 0, .7))-obj.location).to_track_quat("-Z", "Y").to_euler()
    return obj


area("Warm key", (-3, -4, 7), (1, .78, .53), 1000, 5)
area("Cold rim", (2, 4, 6), (.35, .65, 1), 1400, 4)
area("Soft front", (1, -6, 3), (.63, .77, 1), 350, 4)
bpy.ops.object.camera_add(location=(8, -12, 11))
camera = bpy.context.object
camera.name = "Pilot orthographic camera"
camera.data.type = "ORTHO"
scene.camera = camera


def camera_at(loc, target, scale):
    camera.location = loc
    camera.rotation_euler = (Vector(target)-camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.ortho_scale = scale


def render(path, width, height, transparent=False):
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = transparent
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


camera_at((8, -12, 11), (0, 0, .3), 11.8)
scene.render.resolution_x, scene.render.resolution_y = 1440, 1000
scene.render.resolution_percentage = 100
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "abyssal_pilot.blend"))
render(PREVIEW / "arena_beauty.png", 1440, 1000)
for obj in characters:
    obj.hide_render = True
render(PREVIEW / "arena_environment.png", 1440, 1000, True)

# Render character turnarounds against alpha with identical framing and foot pivots.
for obj in scene.objects:
    if obj.type == "MESH":
        obj.hide_render = True
camera_at((0, -7, 5), (0, 0, 1.15), 3.1)
scene.render.resolution_x = scene.render.resolution_y = 256
bpy.context.view_layer.update()
ground_anchor = world_to_camera_view(scene, camera, Vector((0, 0, 0)))
foot_pivot = [ground_anchor.x, 1.0 - ground_anchor.y]
scene.cycles.samples = 24
records = []
for character, name in ((hero, "warrior"), (enemy, "riftbound")):
    character.location = (0, 0, 0)
    for obj in character.children_recursive:
        obj.hide_render = False
    # Three-quarter east/west poses preserve the silhouette on the small Godot board.
    for facing, angle in (("south", 0), ("east", math.pi/4), ("north", math.pi), ("west", -math.pi/4)):
        character.rotation_euler[2] = angle
        output = SPRITES / f"{name}_idle_{facing}.png"
        render(output, 256, 256, True)
        records.append({"id": f"{name}_idle_{facing}", "path": str(output.relative_to(ROOT)), "size": [256, 256]})
    for obj in character.children_recursive:
        obj.hide_render = True

(PREVIEW / "manifest.json").write_text(json.dumps({
    "status": "Static art pilot; Warrior integrated in ArenaBoard; no rig or animation yet",
    "author": "Original procedural Blender geometry created for Abyssal Echoes",
    "source": "art/source/blender/abyssal_pilot.blend",
    "generator": "tools/blender/render_pilot.py",
    "blender": bpy.app.version_string,
    "camera": "Orthographic; front -Y; east/west use readable three-quarter poses",
    "foot_pivot_normalized": foot_pivot,
    "sprites": records,
}, indent=2), encoding="utf-8")
print("ABYSSAL PILOT COMPLETE", flush=True)
