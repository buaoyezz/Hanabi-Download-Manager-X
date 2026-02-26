import json

# 读取中文语言包
with open('lib/l10n/app_zh.arb', 'r', encoding='utf-8') as f:
    zh_data = json.load(f)

# 创建喵喵语言包
meow_data = {
    "@@locale": "meow",
    "@@languageName": "喵喵语 🐱"
}

# 特殊翻译映射
special_translations = {
    "开发者": "铲屎官",
    "官方网站": "官方猫窝",
    "运行中": "跑着呢喵",
    "已停止": "睡着了喵",
    "在线": "在线喵",
    "离线": "离线喵",
}

# 遍历所有键值对
for key, value in zh_data.items():
    # 跳过元数据键
    if key.startswith('@@') or key.startswith('@'):
        continue
    
    # 如果是字符串，添加"喵"
    if isinstance(value, str):
        # 应用特殊翻译
        translated = value
        for zh, meow in special_translations.items():
            translated = translated.replace(zh, meow)
        
        # 如果还没有"喵"结尾，添加"喵"
        if not translated.endswith('喵') and not translated.endswith('...') and translated:
            translated += '喵'
        
        meow_data[key] = translated

# 写入文件
with open('lang/app_meow.arb', 'w', encoding='utf-8') as f:
    json.dump(meow_data, f, ensure_ascii=False, indent=2)

print("喵喵语言包生成完成！")
print(f"共 {len(meow_data)} 个翻译条目")
