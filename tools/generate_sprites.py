"""AntChem pixel art sprite generator.
Generates all prototype sprites from DESIGN.md color tokens.
Each sprite: 1px pure-black outline, fill, single-pixel highlight at top-left 45°.
"""
from PIL import Image, ImageDraw
import os, math

OUT = os.path.join(os.path.dirname(__file__), "..", "assets")
os.makedirs(OUT, exist_ok=True)

# ── Color Palette (from DESIGN.md) ──
C = {
    "cave_deep":    (0x0D, 0x06, 0x04, 255),
    "cave_soil":    (0x3E, 0x27, 0x23, 255),
    "cave_stone":   (0x78, 0x90, 0x9C, 255),
    "cave_clay":    (0x8D, 0x6E, 0x63, 255),
    "firefly":      (0xF5, 0xD0, 0x6B, 255),
    "firefly_dim":  (0xC4, 0xA4, 0x4A, 255),
    "acid_green":   (0x7C, 0xB3, 0x42, 255),
    "rust_red":     (0xA0, 0x52, 0x2D, 255),
    "lava_orange":  (0xFF, 0x6F, 0x00, 255),
    "surface_green":(0x55, 0x8B, 0x2F, 255),
    "smoke_gray":   (0x9E, 0x9E, 0x9E, 255),
    "pure_black":   (0x00, 0x00, 0x00, 255),
    "pure_white":   (0xFF, 0xFF, 0xFF, 255),
    "transparent":  (0, 0, 0, 0),
    "ui_bg":        (0x1A, 0x12, 0x10, 255),
    "ui_bg_hover":  (0x2A, 0x1F, 0x15, 255),
}

def outline_rect(draw, x, y, w, h, outline=C["pure_black"]):
    """1px outline rectangle (pixel art: no anti-aliasing)"""
    for px in [(x, y, x+w-1, y), (x, y+h-1, x+w-1, y+h-1), (x, y, x, y+h-1), (x+w-1, y, x+w-1, y+h-1)]:
        draw.line(px, fill=outline)

def fill_rect(draw, x, y, w, h, color):
    for dy in range(h):
        draw.line([(x, y+dy), (x+w-1, y+dy)], fill=color)

def draw_highlight(draw, x, y, w, h, color):
    """Single-pixel highlight at top-left edges (45° light from top-left)"""
    for dx in range(1, min(3, w-1)):
        draw.point((x+dx, y+1), fill=color)
    for dy in range(1, min(3, h-1)):
        draw.point((x+1, y+dy), fill=color)

def make_sprite(w, h):
    img = Image.new("RGBA", (w, h), C["transparent"])
    draw = ImageDraw.Draw(img)
    return img, draw

# ═══════════════════════════════════════════
# 1. MATERIAL ICONS (16x16 px)
# ═══════════════════════════════════════════
MATERIALS = {
    "sulfur":       ("sulfur",       C["firefly"]),
    "saltpeter":    ("saltpeter",    (0xE8, 0xE8, 0xE0, 255)),
    "charcoal":     ("charcoal",     (0x1A, 0x1A, 0x1A, 255)),
    "clay":         ("clay",         C["cave_clay"]),
    "iron_rust":    ("iron_rust",    C["rust_red"]),
    "limestone":    ("limestone",    (0xE0, 0xE0, 0xD8, 255)),
    "diatomite":    ("diatomite",    (0xF0, 0xF0, 0xE8, 255)),
    "formic_acid":  ("formic_acid",  C["acid_green"]),
    "beeswax":      ("beeswax",      (0xF0, 0xD0, 0x60, 255)),
    "resin":        ("resin",        (0xDA, 0xA6, 0x22, 255)),
    "fat":          ("fat",          (0xE8, 0xD0, 0x80, 255)),
    "plant_ash":    ("plant_ash",    (0xD8, 0xD8, 0xD8, 255)),
    "rot_soil":     ("rot_soil",     (0x30, 0x20, 0x18, 255)),
    "ammonium":     ("ammonium",     (0xF0, 0xF0, 0xE0, 255)),
    "fireant_venom":("fireant_venom",C["lava_orange"]),
    "lead_powder":  ("lead_powder",  (0x70, 0x70, 0x78, 255)),
}

for mat_id, (name, color) in MATERIALS.items():
    img, draw = make_sprite(16, 16)
    fill_rect(draw, 1, 1, 14, 14, color)
    outline_rect(draw, 0, 0, 16, 16)
    draw_highlight(draw, 0, 0, 16, 16, tuple(min(c+40, 255) for c in color[:3]) + (255,))
    # center dot for identification
    fill_rect(draw, 6, 6, 4, 4, tuple(max(c-40, 0) for c in color[:3]) + (255,))
    img.save(os.path.join(OUT, f"mat_{mat_id}.png"))
print(f"Generated {len(MATERIALS)} material icons")

# ═══════════════════════════════════════════
# 2. INTERMEDIATE ICONS (16x16, special shapes)
# ═══════════════════════════════════════════
def make_intermediate(name, color):
    img, draw = make_sprite(16, 16)
    # diamond shape
    cx, cy = 8, 8
    pts = [(cx, 1), (15, cy), (cx, 14), (1, cy)]
    # fill diamond
    for y in range(1, 15):
        x_span = int(7 - abs(y-7.5) * 0.9)
        for x in range(cx - max(1, x_span), cx + max(1, x_span)):
            if 0 <= x < 16:
                draw.point((x, y), fill=color)
    # outline diamond perimeter
    for i in range(len(pts)):
        draw.line([pts[i], pts[(i+1)%4]], fill=C["pure_black"])
    draw_highlight(draw, 0, 0, 16, 16, tuple(min(c+40,255) for c in color[:3])+(255,))
    img.save(os.path.join(OUT, f"inter_{name}.png"))

INTERMEDIATES = [
    ("nitrating_acid", C["acid_green"]),
    ("carbon_fiber", (0x30, 0x30, 0x30, 255)),
    ("stabilizing_wax", C["firefly_dim"]),
    ("aromatic_oil", (0xE0, 0xC0, 0x40, 255)),
]
for name, color in INTERMEDIATES:
    make_intermediate(name, color)
print(f"Generated {len(INTERMEDIATES)} intermediate icons")

# ═══════════════════════════════════════════
# 3. EQUIPMENT ICONS (32x32 px)
# ═══════════════════════════════════════════
def make_equipment_icon(name, colors, shape_fn):
    img, draw = make_sprite(32, 32)
    shape_fn(draw, colors)
    outline_rect(draw, 0, 0, 32, 32)
    draw_highlight(draw, 0, 0, 32, 32, tuple(min(c+50,255) for c in colors[0][:3])+(255,))
    img.save(os.path.join(OUT, f"equip_{name}.png"))

def mortar_shape(draw, clrs):
    fill_rect(draw, 4, 18, 24, 10, clrs[0])  # base stone
    fill_rect(draw, 10, 8, 12, 10, clrs[1])  # bowl

def lamp_shape(draw, clrs):
    fill_rect(draw, 12, 20, 8, 8, clrs[1])   # base
    fill_rect(draw, 13, 4, 6, 16, (255,255,200,255))  # glow
    for dy in range(4, 20, 3):
        draw.point((15, dy), fill=clrs[0])

def crucible_shape(draw, clrs):
    fill_rect(draw, 8, 14, 16, 14, clrs[0])
    fill_rect(draw, 10, 6, 12, 8, clrs[1])
    fill_rect(draw, 4, 22, 24, 4, clrs[0])

def still_shape(draw, clrs):
    fill_rect(draw, 13, 2, 6, 28, clrs[0])  # main tube
    fill_rect(draw, 3, 8, 10, 4, clrs[0])   # arm
    fill_rect(draw, 3, 22, 10, 4, clrs[0])  # arm

EQUIPMENT_ICONS = [
    ("mortar_stone", [C["cave_stone"], C["smoke_gray"]], mortar_shape),
    ("mortar_graded", [C["cave_stone"], (0x90,0xA0,0xB0,255)], mortar_shape),
    ("firefly_lamp", [C["firefly"], C["firefly_dim"]], lamp_shape),
    ("crucible_thermo", [C["cave_clay"], C["firefly_dim"]], crucible_shape),
    ("still", [C["cave_stone"], C["firefly_dim"]], still_shape),
]
for name, colors, shape_fn in EQUIPMENT_ICONS:
    make_equipment_icon(name, colors, shape_fn)
print(f"Generated {len(EQUIPMENT_ICONS)} equipment icons")

# ═══════════════════════════════════════════
# 4. BUILDING BLOCKS (for RigidBody2D)
# ═══════════════════════════════════════════
def make_brick(name, w, h, color, variant=0):
    img, draw = make_sprite(w, h)
    fill_rect(draw, 1, 1, w-2, h-2, color)
    outline_rect(draw, 0, 0, w, h)
    draw_highlight(draw, 0, 0, w, h, tuple(min(c+30,255) for c in color[:3])+(255,))
    # brick lines for larger blocks
    if w >= 64:
        for lx in range(w//2, w-2, w//2):
            draw.line([(lx, 1), (lx, h-2)], fill=C["pure_black"])
    img.save(os.path.join(OUT, f"brick_{name}.png"))

BLOCKS = [
    ("soil_64x32",    64, 32, C["cave_soil"]),
    ("stone_64x32",   64, 32, C["cave_stone"]),
    ("clay_64x32",    64, 32, C["cave_clay"]),
    ("rust_64x32",    64, 32, C["rust_red"]),
    ("soil_32x32",    32, 32, C["cave_soil"]),
    ("stone_32x32",   32, 32, C["cave_stone"]),
    ("clay_32x32",    32, 32, C["cave_clay"]),
]
for name, w, h, color in BLOCKS:
    make_brick(name, w, h, color)
print(f"Generated {len(BLOCKS)} building blocks")

# ═══════════════════════════════════════════
# 5. FIREFLY GLOW (20x20 radial)
# ═══════════════════════════════════════════
img, draw = make_sprite(20, 20)
cx, cy = 9.5, 9.5
for y in range(20):
    for x in range(20):
        dist = math.sqrt((x-cx)**2 + (y-cy)**2)
        if dist < 9:
            alpha = int(max(0, 255 * (1.0 - dist/9.0) ** 1.5))
            r, g, b = C["firefly"][:3]
            draw.point((x, y), fill=(r, g, b, alpha))
img.save(os.path.join(OUT, "firefly_glow.png"))
print("Generated firefly glow")

# ═══════════════════════════════════════════
# 6. ANT SPRITE (24x20 px, 4 idle frames)
# ═══════════════════════════════════════════
def draw_ant(draw, ox, oy, leg_offset: int = 0):
    """Draw ant at (ox, oy) — body + head + legs + antennae"""
    dark = (0x20, 0x12, 0x08, 255)
    mid =  (0x40, 0x28, 0x10, 255)
    # body segments
    fill_rect(draw, ox+8, oy+6, 6, 5, dark)   # abdomen
    fill_rect(draw, ox+6, oy+4, 4, 4, mid)     # thorax
    fill_rect(draw, ox+2, oy+3, 3, 4, dark)     # head
    # legs (6, with offset animation)
    for leg_i, lx in enumerate([ox+7, ox+9, ox+10]):
        ly = oy + (8 if leg_i < 2 else 9)
        leg_tip = ly + [3, 2, 2][leg_i] + (leg_offset if leg_i == 1 else -leg_offset)
        draw.line([(lx, ly), (lx + [2, -2, 2][leg_i], leg_tip)], fill=dark)
    # antennae
    draw.line([(ox+2, oy+3), (ox-1, oy)], fill=dark)
    draw.line([(ox+3, oy+3), (ox+0, oy+1)], fill=dark)
    # eye
    draw.point((ox+1, oy+4), fill=C["pure_black"])

for frame in range(4):
    img, draw = make_sprite(24, 20)
    leg_off = [0, 1, 0, -1][frame]
    draw_ant(draw, 2, 3, leg_off)
    # 1px black outline around the ant silhouette
    img.save(os.path.join(OUT, f"ant_idle_{frame}.png"))
print("Generated ant idle sprites (4 frames)")

# ═══════════════════════════════════════════
# 7. EXPLOSIVE PLACED SPRITE (8x12 px)
# ═══════════════════════════════════════════
img, draw = make_sprite(8, 12)
fill_rect(draw, 1, 1, 6, 8, C["firefly_dim"])
fill_rect(draw, 2, 8, 4, 2, (0x80, 0x40, 0x20, 255))  # fuse base
draw.line([(4, 0), (4, 2)], fill=C["firefly"])  # spark
outline_rect(draw, 0, 0, 8, 12)
img.save(os.path.join(OUT, "explosive_placed.png"))
print("Generated explosive sprite")

# ═══════════════════════════════════════════
# 8. CAVE WALL TILE (32x32, repeatable)
# ═══════════════════════════════════════════
img, draw = make_sprite(32, 32)
fill_rect(draw, 0, 0, 32, 32, C["cave_soil"])
for i in range(40):
    rx = i * 7 % 32
    ry = i * 13 % 32
    draw.point((rx, ry), fill=tuple(c + (i*3)%10 for c in C["cave_deep"][:3]) + (255,))
img.save(os.path.join(OUT, "cave_wall_tile.png"))
print("Generated cave wall tile")

# ═══════════════════════════════════════════
# 9. PARTICLE SPRITES (4x4, 8x8)
# ═══════════════════════════════════════════
for name, size, color in [("smoke", 8, C["smoke_gray"]), ("fire", 8, C["lava_orange"]), ("spark", 4, C["firefly"])]:
    img, draw = make_sprite(size, size)
    cx, cy = size/2 - 0.5, size/2 - 0.5
    r = size/2 - 1
    for y in range(size):
        for x in range(size):
            dist = math.sqrt((x-cx)**2 + (y-cy)**2)
            if dist <= r:
                alpha = int(255 * (1.0 - dist/r))
                draw.point((x, y), fill=color[:3] + (alpha,))
    img.save(os.path.join(OUT, f"particle_{name}.png"))
print("Generated particle sprites")

# ═══════════════════════════════════════════
# 10. UI OVERLAY — Naming Dialog BG
# ═══════════════════════════════════════════
img, draw = make_sprite(320, 160)
fill_rect(draw, 1, 1, 318, 158, C["ui_bg"])
outline_rect(draw, 0, 0, 320, 160, C["firefly"])
img.save(os.path.join(OUT, "ui_naming_bg.png"))
print("Generated naming dialog BG")

# ═══════════════════════════════════════════
# 11. SYNTHESIS GRAPH NODE BACKGROUNDS
# ═══════════════════════════════════════════
# known explosive node (32x16)
img, draw = make_sprite(32, 16)
fill_rect(draw, 1, 1, 30, 14, C["ui_bg"])
outline_rect(draw, 0, 0, 32, 16, C["firefly"])
img.save(os.path.join(OUT, "ui_node_known_explosive.png"))

# intermediate node (diamond, 32x16)
img, draw = make_sprite(32, 16)
for y in range(1, 15):
    span = int(8 - abs(y-7.5) * 0.8)
    for x in range(16-max(1,span), 16+max(1,span)):
        if 0 <= x < 32:
            draw.point((x, y), fill=C["ui_bg"])
# diamond outline
pts = [(16, 1), (31, 8), (16, 14), (1, 8)]
for i in range(4):
    draw.line([pts[i], pts[(i+1)%4]], fill=C["acid_green"])
img.save(os.path.join(OUT, "ui_node_intermediate.png"))

# locked node (dashed, 32x16)
img, draw = make_sprite(32, 16)
for x in range(0, 30, 4):
    draw.point((x+1, 0), fill=(0x44,)*3+(255,))
    draw.point((x+1, 15), fill=(0x44,)*3+(255,))
img.save(os.path.join(OUT, "ui_node_locked.png"))

print("Generated synthesis graph node sprites")

print("\n✓ All sprites generated in: " + OUT)
print(f"Total: {len(os.listdir(OUT))} files")
