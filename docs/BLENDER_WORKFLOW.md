# Blender development in VS Code

Configured on 2026-11-09 with Blender 5.2.3 LTS and JacquesLucke's
Blender Development extension 0.0.31 (already installed).

The project `.vscode/settings.json` selects the local executable at
`F:/SteamLibrary/steamapps/common/Blender/blender.exe`.
Update `blender.executables` if Blender moves or this workspace is used on another PC.

## Start and run a script

1. Open this project folder in VS Code.
2. Press Ctrl+Shift+P and run **Blender: Start**.
3. Open `tools/blender/check_connection.py` or another Blender Python script.
4. Press Ctrl+Shift+P and run **Blender: Run Script**.
5. Check the Blender task terminal for stdout/startup logs, the Debug Console for
   debugger output, and Output > Blender debugpy for extension launch details.

The check prints `Abyssal Echoes: VS Code -> Blender connection OK`, the Blender
version, and the active scene. It does not change the scene or save files.
Use **Blender: Stop** to end the managed session. Run Blender scripts with
**Blender: Run Script**, since ordinary system Python does not include `bpy`.

## Verified

- **Blender: Start** appeared in the Command Palette and launched a managed session.
- The extension's local script endpoint executed the connection check successfully.
- `debugpy.is_client_connected()` returned `true` inside Blender 5.2.3 LTS.

This setup provides Blender Python scripting and debugging alongside the Godot
project. It does not automatically synchronize Blender scenes with Godot assets.

Extension documentation: https://github.com/JacquesLucke/blender_vscode
