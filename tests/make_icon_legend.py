import os
import math
from PIL import Image, ImageDraw, ImageFont

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "")
ATLAS = os.path.join(os.path.dirname(os.path.dirname(OUT_DIR)), "assets", "tiles", "ground_tiles.png")

# (物品ID, 中文名, 颜色RGB, 形状, 图标字)
RES = [
    ("wood", "木材", (0.35, 0.65, 0.25), "diamond", "木"),
    ("stone", "石头", (0.55, 0.55, 0.55), "square", "石"),
    ("iron", "铁矿石", (0.4, 0.5, 0.8), "square", "铁"),
    ("darkstone", "暗石", (0.45, 0.3, 0.6), "square", "暗"),
    ("parts", "零件", (0.8, 0.7, 0.35), "hexagon", "件"),
    ("frost_crystal", "冰晶", (0.65, 0.85, 1.0), "star", "冰"),
    ("ember", "余烬", (1.0, 0.6, 0.15), "star", "烬"),
    ("rad_dust", "辐射尘", (0.55, 0.75, 0.25), "star", "尘"),
    ("gear", "齿轮", (0.6, 0.65, 0.75), "hexagon", "齿"),
    ("swamp_herb", "沼泽草药", (0.45, 0.7, 0.3), "diamond", "草"),
    ("gem", "宝石", (1.0, 0.6, 0.8), "star", "宝"),
    ("sky_crystal", "天空晶石", (0.75, 0.9, 1.0), "star", "天"),
    ("salt_crystal", "盐晶", (0.9, 0.85, 0.7), "square", "盐"),
    ("cactus_fiber", "仙人掌纤维", (0.45, 0.6, 0.3), "diamond", "纤"),
    ("thunder_crystal", "雷晶", (0.6, 0.65, 1.0), "star", "雷"),
    ("glow_shroom", "荧光菇", (0.7, 0.55, 0.9), "diamond", "菇"),
    ("spore", "孢子", (0.8, 0.7, 0.9), "circle", "孢"),
    ("rune_stone", "符文石", (0.55, 0.7, 0.85), "square", "符"),
    ("relic", "古物", (0.85, 0.7, 0.45), "hexagon", "古"),
    ("soul_ember", "灵魂余烬", (0.7, 0.75, 0.95), "star", "魂"),
    ("bone", "白骨", (0.9, 0.9, 0.85), "hexagon", "骨"),
    ("clean_water", "净水", (0.4, 0.75, 0.9), "circle", "水"),
    ("oasis_herb", "绿洲草药", (0.4, 0.75, 0.45), "diamond", "药"),
]


def shape_pts(shape, s):
    pts = []
    if shape == "diamond":
        pts = [(0, -s), (s, 0), (0, s), (-s, 0)]
    elif shape == "circle":
        for i in range(16):
            a = 2 * math.pi * i / 16
            pts.append((math.cos(a) * s, math.sin(a) * s))
    elif shape == "hexagon":
        for i in range(6):
            a = 2 * math.pi * i / 6 - math.pi / 6
            pts.append((math.cos(a) * s, math.sin(a) * s))
    elif shape == "star":
        for i in range(10):
            a = 2 * math.pi * i / 10 - math.pi / 2
            r = s if i % 2 == 0 else s * 0.43
            pts.append((math.cos(a) * r, math.sin(a) * r))
    else:
        pts = [(-s, -s), (s, -s), (s, s), (-s, s)]
    return pts


font = ImageFont.truetype("C:/Windows/Fonts/simhei.ttf", 26)
font_sm = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 16)
cols, cell = 6, 110
rows = (len(RES) + cols - 1) // cols
img = Image.new("RGB", (cols * cell, rows * cell + 30), (28, 28, 32))
d = ImageDraw.Draw(img)
for i, (_rid, name, c, shape, glyph) in enumerate(RES):
    cx = (i % cols) * cell + cell // 2
    cy = (i // cols) * cell + cell // 2 + 8
    fill = tuple(min(255, int(v * 255 * 1.18)) for v in c)
    d.polygon([(cx + x * 1.32, cy + y * 1.32) for x, y in shape_pts(shape, 26)], fill=(12, 12, 12))
    d.polygon([(cx + x, cy + y) for x, y in shape_pts(shape, 26)], fill=fill)
    bbox = d.textbbox((0, 0), glyph, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text((cx - tw / 2, cy - th / 2 - 4), glyph, font=font, fill=(255, 255, 255),
           stroke_width=3, stroke_fill=(0, 0, 0))
    d.text((cx, (i // cols) * cell + cell + 6), name, font=font_sm, fill=(230, 230, 230), anchor="ma")

out = os.path.join(OUT_DIR, "item_icon_legend.png")
img.save(out)
print("legend saved:", out)

atlas = Image.open(ATLAS).resize((512, 512), Image.NEAREST)
atlas.save(os.path.join(OUT_DIR, "tile_atlas_preview.png"))
print("atlas saved")
