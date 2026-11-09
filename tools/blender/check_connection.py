"""Run with VS Code's Blender: Run Script in a managed Blender session."""

import bpy

print("Abyssal Echoes: VS Code -> Blender connection OK", flush=True)
print(f"Blender version: {bpy.app.version_string}", flush=True)
print(f"Active scene: {bpy.context.scene.name}", flush=True)
