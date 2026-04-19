import json
import re

with open('app_meow.arb', 'r', encoding='utf-8') as f:
    d = json.load(f)

for k, v in d.items():
    if not isinstance(v, str): continue
    
    # Replace spaces before meow character
    # E.g. " 喵" -> "喵", "   喵" -> "喵"
    new_v = re.sub(r'\s+喵', '喵', v)
    
    new_v = new_v.replace(' 喵', '喵')
    d[k] = new_v

with open('app_meow.arb', 'w', encoding='utf-8') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)

print("Removed extra spaces before 喵")
