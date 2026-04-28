import os
import re

directory = 'resources/skills'
files = os.listdir(directory)

for f in files:
    if f.endswith('.tres') and not 'tier2' in f:
        path = os.path.join(directory, f)
        with open(path, 'r', encoding='utf-8') as file:
            content = file.read()
        
        # We only process if tier is 1
        tier_match = re.search(r'tier = 1', content)
        if not tier_match:
            continue
            
        id_match = re.search(r'id = "(.*?)"', content)
        if not id_match:
            continue
            
        skill_id = id_match.group(1)
        tier2_id = skill_id + '_tier2'
        
        # Modify original
        new_content = re.sub(r'merge_result_id = ""', f'merge_result_id = "{tier2_id}"', content)
        with open(path, 'w', encoding='utf-8') as file:
            file.write(new_content)
            
        # Create Tier 2
        tier2_content = new_content
        tier2_content = re.sub(r'id = ".*?"', f'id = "{tier2_id}"', tier2_content)
        tier2_content = re.sub(r'tier = 1', 'tier = 2', tier2_content)
        tier2_content = re.sub(r'merge_result_id = ".*?"', 'merge_result_id = ""', tier2_content)
        tier2_content = re.sub(r'display_name = "(.*?)"', r'display_name = "\1 II"', tier2_content)
        
        def multiply_power(match):
            return f"power = {float(match.group(1)) * 1.5}"
        tier2_content = re.sub(r'power = ([0-9.]+)', multiply_power, tier2_content)
        
        tier2_filename = f.replace('.tres', '_tier2.tres')
        tier2_path = os.path.join(directory, tier2_filename)
        with open(tier2_path, 'w', encoding='utf-8') as file:
            file.write(tier2_content)
            
        print(f"Processed {f} -> {tier2_filename}")
