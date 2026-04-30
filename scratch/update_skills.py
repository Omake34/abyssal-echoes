import os
import re

skill_dir = r"d:\Godot Things\New folder\time_walker_darkworld\resources\skills"

mapping = {
    "arcane_blast": '["mage"]',
    "fireball": '["mage"]',
    "magic_bolt": '["mage"]',
    "heal": '["cleric"]',
    "smite": '["cleric"]',
    "power_strike": '["warrior"]',
    "slash": '["warrior"]',
    "whirlwind": '["warrior"]',
    "snipe": '["archer"]',
    "rally": '[]'  # Generic
}

for filename in os.listdir(skill_dir):
    if filename.endswith(".tres"):
        path = os.path.join(skill_dir, filename)
        with open(path, 'r') as f:
            content = f.read()
        
        # Determine class
        found = False
        for key, classes in mapping.items():
            if key in filename:
                content = re.sub(r'compatible_classes = \[.*?\]', f'compatible_classes = {classes}', content)
                if f'compatible_classes = {classes}' not in content:
                     # If property doesn't exist, add it
                     content = content.replace('target_type =', f'compatible_classes = {classes}\ntarget_type =')
                found = True
                break
        
        if found:
            with open(path, 'w') as f:
                f.write(content)
print("Updated skills.")
