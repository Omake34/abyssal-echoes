import os
import re

path = 'resources/skills/skill_fireball.tres'
with open(path, 'r', encoding='utf-8') as file:
    content = file.read()

content = re.sub(r'tier = 2', 'tier = 1', content)
content = re.sub(r'merge_result_id = ""', 'merge_result_id = "fireball_tier2"', content)

with open(path, 'w', encoding='utf-8') as file:
    file.write(content)

tier2_content = content
tier2_content = re.sub(r'id = "fireball"', 'id = "fireball_tier2"', tier2_content)
tier2_content = re.sub(r'tier = 1', 'tier = 2', tier2_content)
tier2_content = re.sub(r'merge_result_id = "fireball_tier2"', 'merge_result_id = ""', tier2_content)
tier2_content = re.sub(r'display_name = "Fireball"', 'display_name = "Fireball II"', tier2_content)

def multiply_power(match):
    return f"power = {float(match.group(1)) * 1.5}"
tier2_content = re.sub(r'power = ([0-9.]+)', multiply_power, tier2_content)

tier2_path = 'resources/skills/skill_fireball_tier2.tres'
with open(tier2_path, 'w', encoding='utf-8') as file:
    file.write(tier2_content)

print("Fixed fireball")
