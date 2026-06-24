
"""
AntChem Pixel Art Generator v2 — Generate all game sprites
Run: python generate_all.py
"""

import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from pixel_art import *
import numpy as np
from PIL import Image, ImageDraw
import random

OUT = os.path.join(os.path.dirname(__file__), "..", "assets")
os.makedirs(OUT, exist_ok=True)

# ═══════════════════════════════════════════
# UTILITY
# ═══════════════════════════════════════════

def save(img, name):
    path = os.path.join(OUT, name)
    img.save(path)
    return path

def apply_pixel_outline(img):
    """Apply 1px pure-black outline to non-transparent pixels"""
    arr = np.array(img)
    h, w = arr.shape[:2]
    outline_mask = np.zeros((h, w), dtype=bool)
    for y in range(h):
        for x in range(w):
            if arr[y, x, 3] == 0:
                # Check 4-neighbors for non-transparent
                for dx, dy in [(-1,0),(1,0),(0,-1),(0,1)]:
                    nx, ny = x+dx, y+dy
                    if 0 <= nx < w and 0 <= ny < h and arr[ny, nx, 3] > 128:
                        outline_mask[y, x] = True
                        break
    arr[outline_mask] = P.pure_black
    return Image.fromarray(arr)

def draw_pixels(arr, mask, color):
    """Draw color where mask is True"""
    arr[mask] = color

# ═══════════════════════════════════════════
# 1. MATERIAL ICONS (16×16)
# ═══════════════════════════════════════════

def generate_material_icon(name, shape_func, color_a, color_b, color_c):
    """Generate a detailed 16×16 material icon"""
    SIZE = 16
    img = create_sprite(SIZE, SIZE)
    draw = ImageDraw.Draw(img)
    
    # Fill background shape
    shape_func(draw, SIZE)
    
    # Outline
    arr = np.array(img)
    outlined = apply_pixel_outline(Image.fromarray(arr))
    
    # Rim light (top-left highlight)
    arr2 = np.array(outlined)
    for dy in range(1, 4):
        for dx in range(1, 4):
            if dy < SIZE-1 and dx < SIZE-1 and arr2[dy, dx, 3] > 0:
                arr2[dy, dx] = lighter(arr2[dy, dx][:3] + (255,), 15)
    
    # Edge shadow (bottom-right)
    for dy in range(SIZE-4, SIZE-1):
        for dx in range(SIZE-4, SIZE-1):
            if dy < SIZE and dx < SIZE and arr2[dy, dx, 3] > 0:
                arr2[dy, dx] = darker(arr2[dy, dx][:3] + (255,), 20)
    
    return Image.fromarray(arr2)

def crystal_shape(draw, size, color, cluster_scale=0.6):
    """Draw faceted crystal cluster"""
    cx = size // 2  # center = 8 for 16px
    # Main crystal body
    pts = [(cx, 2), (cx+4, 6), (cx+5, 10), (cx+3, 13), (cx-3, 13), 
           (cx-5, 10), (cx-4, 6)]
    draw.polygon(pts, fill=color)
    # Highlight facet (top-left face)
    pts2 = [(cx, 2), (cx+1, 5), (cx, 8)]
    draw.polygon(pts2, fill=lighter(color, 50))
    # Shadow facet (bottom-right)
    pts3 = [(cx, 8), (cx+1, 5), (cx+5, 10), (cx+3, 13), (cx-1, 12)]
    draw.polygon(pts3, fill=darker(color, 30))
    # Specular highlight point
    draw.point((cx, 4), fill=P.pure_white)
    draw.point((cx+1, 5), fill=lighter(color, 70))
    # Small left crystal
    draw.polygon([(cx-5, 5), (cx-2, 8), (cx-4, 10)], fill=darker(color, 15))
    draw.point((cx-4, 7), fill=lighter(color, 25))
    # Small right crystal
    draw.polygon([(cx+4, 6), (cx+2, 9), (cx+5, 8)], fill=color)
    draw.point((cx+3, 7), fill=lighter(color, 30))

def powder_shape(draw, size, color):
    """Draw powder/grain texture — stippled with particle clumps"""
    import random
    rng = random.Random(42)
    # Dense stipple background
    for y in range(2, 14):
        for x in range(2, 14):
            r = rng.random()
            if r < 0.55:
                shade = rng.randint(-20, 20)
                c = tuple(max(0, min(255, color[i] + shade)) for i in range(3)) + (255,)
                draw.point((x, y), fill=c)
            elif r < 0.65:
                draw.point((x, y), fill=lighter(color, 30))
    # Grain clumps (2-3 pixel groups)
    for _ in range(6):
        cx = rng.randint(3, 12)
        cy = rng.randint(3, 12)
        # Small cluster
        for dx, dy in [(0,0), (1,0), (0,1), (-1,0), (0,-1)]:
            if rng.random() < 0.6:
                px, py = cx+dx, cy+dy
                if 2 <= px < 14 and 2 <= py < 14:
                    draw.point((px, py), fill=lighter(color, 45))
    # Single bright specks
    for _ in range(4):
        x = rng.randint(2, 13)
        y = rng.randint(2, 13)
        draw.point((x, y), fill=P.pure_white)

def layered_shape(draw, size, color_a, color_b, color_c):
    """Draw layered/sedimentary texture"""
    for y in range(1, 15):
        if y < 5:
            c = darker(color_a, 10)
        elif y < 8:
            c = color_a
        elif y < 11:
            c = color_b
        else:
            c = color_c
        # Add slight horizontal variation
        import random
        rng = random.Random(y * 100)
        for x in range(1, 15):
            if rng.random() < 0.15:
                c2 = lighter(c, 15)
                draw.point((x, y), fill=c2)
            elif rng.random() < 0.1:
                draw.point((x, y), fill=darker(c, 15))
            else:
                draw.point((x, y), fill=c)

def liquid_shape(draw, size, color):
    """Draw liquid droplet/bottle shape"""
    # Rounded bottom, narrow top
    draw.ellipse([3, 4, 12, 15], fill=color)
    draw.rectangle([5, 1, 10, 7], fill=color)
    # Highlight
    draw.ellipse([5, 5, 8, 8], fill=lighter(color, 50))
    # Surface line
    draw.line([(4, 7), (11, 7)], fill=darker(color, 30))

def chunk_shape(draw, size, color):
    """Draw irregular chunks/broken pieces with facets"""
    import random
    rng = random.Random(123)
    cx = size // 2
    # Central chunk cluster
    chunks = [
        [(cx-5, 2), (cx, 3), (cx+1, 7), (cx-3, 8), (cx-6, 5)],
        [(cx+1, 3), (cx+5, 4), (cx+4, 9), (cx, 8), (cx, 6)],
        [(cx-4, 8), (cx, 9), (cx-1, 13), (cx-5, 11)],
        [(cx+1, 8), (cx+5, 9), (cx+3, 13), (cx-1, 12)],
    ]
    for i, pts in enumerate(chunks[:rng.randint(3,4)]):
        shade = rng.randint(-20, 20)
        c = tuple(max(0, min(255, color[j] + shade)) for j in range(3)) + (255,)
        draw.polygon(pts, fill=c)
        # Highlight top-left edge
        for px in pts[:2]:
            draw.point(px, fill=lighter(c, 40))
        # Shadow bottom-right
        draw.point(pts[-1], fill=darker(c, 25))

def metallic_shape(draw, size, color):
    """Draw metallic/mineral surface with crystalline facets"""
    import random
    rng = random.Random(77)
    # Base plate
    draw.rectangle([2, 2, 13, 13], fill=color)
    # Crystal face lines creating faceted look
    draw.line([(2, 7), (13, 7)], fill=darker(color, 35))
    draw.line([(7, 2), (7, 13)], fill=darker(color, 35))
    draw.line([(3, 3), (12, 12)], fill=darker(color, 20))
    draw.line([(12, 3), (3, 12)], fill=darker(color, 20))
    # Top-left facet — bright highlight (light from top-left)
    for y in range(2, 7):
        for x in range(2, 7):
            draw.point((x, y), fill=lighter(color, 35))
    # Top-right and bottom-left — medium
    for y in range(2, 7):
        for x in range(8, 13):
            draw.point((x, y), fill=color)
    # Bottom-right — dark shadow
    for y in range(8, 13):
        for x in range(8, 13):
            draw.point((x, y), fill=darker(color, 35))
    # Specular highlights
    for px in [(3,3),(4,3),(3,4),(4,4)]:
        draw.point(px, fill=lighter(color, 70))
    draw.point((3, 3), fill=P.pure_white)

# Material definitions
MATERIALS = [
    # (filename, type, color_a, color_b, color_c)
    ("mat_sulfur", "crystal", P.firefly, None, None),
    ("mat_saltpeter", "crystal", (0xE8, 0xE8, 0xE0, 255), None, None),
    ("mat_charcoal", "chunk", (0x1A, 0x1A, 0x1A, 255), None, None),
    ("mat_clay", "layered", P.cave_clay, darker(P.cave_clay, 15), darker(P.cave_clay, 30)),
    ("mat_iron_rust", "metallic", P.rust_red, None, None),
    ("mat_limestone", "chunk", (0xE0, 0xE0, 0xD8, 255), None, None),
    ("mat_diatomite", "powder", (0xF0, 0xF0, 0xE8, 255), None, None),
    ("mat_formic_acid", "liquid", P.acid_green, None, None),
    ("mat_beeswax", "crystal", (0xF0, 0xD0, 0x60, 255), None, None),
    ("mat_resin", "liquid", (0xDA, 0xA6, 0x22, 255), None, None),
    ("mat_fat", "chunk", (0xE8, 0xD0, 0x80, 255), None, None),
    ("mat_plant_ash", "powder", (0xD8, 0xD8, 0xD8, 255), None, None),
    ("mat_rot_soil", "powder", (0x30, 0x20, 0x18, 255), None, None),
    ("mat_ammonium", "crystal", (0xF0, 0xF0, 0xE0, 255), None, None),
    ("mat_fireant_venom", "liquid", P.lava_orange, None, None),
    ("mat_lead_powder", "powder", (0x70, 0x70, 0x78, 255), None, None),
]

print("Generating material icons...")
for name, typ, ca, cb, cc in MATERIALS:
    if typ == "crystal":
        img = generate_material_icon(name, lambda d,s,c=ca: crystal_shape(d,s,c), ca, cb, cc)
    elif typ == "powder":
        img = generate_material_icon(name, lambda d,s,c=ca: powder_shape(d,s,c), ca, cb, cc)
    elif typ == "chunk":
        img = generate_material_icon(name, lambda d,s,c=ca: chunk_shape(d,s,c), ca, cb, cc)
    elif typ == "layered":
        img = generate_material_icon(name, lambda d,s,c=ca: layered_shape(d,s,ca,cb,cc), ca, cb, cc)
    elif typ == "liquid":
        img = generate_material_icon(name, lambda d,s,c=ca: liquid_shape(d,s,c), ca, cb, cc)
    elif typ == "metallic":
        img = generate_material_icon(name, lambda d,s,c=ca: metallic_shape(d,s,c), ca, cb, cc)
    save(img, f"{name}.png")

print(f"  ✓ {len(MATERIALS)} material icons")

# ═══════════════════════════════════════════
# 2. CAVE WALL TILE (32×32, repeatable)
# ═══════════════════════════════════════════

print("Generating cave wall tile...")
S = 32
img = create_sprite(S, S)
draw = ImageDraw.Draw(img)

# Generate noise-based cave wall texture
noise = fbm((S, S), octaves=4, scale=6.0, seed=1)
noise2 = fbm((S, S), octaves=2, scale=12.0, seed=10)

for y in range(S):
    for x in range(S):
        n = noise[y, x]
        # Map noise to color steps
        if n < 0.25:
            c = P.cave_deep
        elif n < 0.45:
            c = darker(P.cave_soil, 20)
        elif n < 0.65:
            c = P.cave_soil
        elif n < 0.80:
            c = lighter(P.cave_soil, 10)
        else:
            c = P.cave_clay
        # Add small rock flecks
        if noise2[y, x] > 0.75:
            c = P.cave_stone if noise2[y, x] > 0.9 else lighter(P.cave_soil, 20)
        draw.point((x, y), fill=c)

# Ensure repeatable edges by blending
for i in range(S):
    # Top-bottom blend
    c_top = img.getpixel((i, 0))
    c_bot = img.getpixel((i, S-1))
    blend_c = blend(c_top, c_bot, 0.5)
    img.putpixel((i, 0), blend_c)
    img.putpixel((i, S-1), blend_c)
    # Left-right blend
    c_l = img.getpixel((0, i))
    c_r = img.getpixel((S-1, i))
    blend_c = blend(c_l, c_r, 0.5)
    img.putpixel((0, i), blend_c)
    img.putpixel((S-1, i), blend_c)

save(img, "cave_wall_tile.png")
print("  ✓ cave wall tile")

# ═══════════════════════════════════════════
# 3. EQUIPMENT ICONS (32×32)
# ═══════════════════════════════════════════

print("Generating equipment icons...")

def generate_equipment(name, draw_func):
    img = create_sprite(32, 32)
    draw = ImageDraw.Draw(img)
    draw_func(draw)
    arr = np.array(img)
    outlined = apply_pixel_outline(Image.fromarray(arr))
    arr2 = np.array(outlined)
    # Rim light
    for dy in range(1, 5):
        for dx in range(1, 5):
            if arr2[dy, dx, 3] > 0:
                arr2[dy, dx] = lighter(arr2[dy, dx][:3]+(255,), 10)
    # Bottom-right shadow
    for dy in range(27, 31):
        for dx in range(27, 31):
            if arr2[dy, dx, 3] > 0:
                arr2[dy, dx] = darker(arr2[dy, dx][:3]+(255,), 15)
    save(Image.fromarray(arr2), f"equip_{name}.png")

def draw_mortar_stone(draw):
    """Stone mortar: concave bowl on a flat base"""
    fill_rect(draw, 4, 20, 24, 8, P.cave_stone)  # base
    draw.ellipse([6, 4, 25, 22], fill=P.cave_stone)  # bowl
    draw.ellipse([10, 6, 21, 18], fill=darker(P.cave_stone, 20))  # inner bowl
    draw.ellipse([11, 8, 19, 15], fill=darker(P.cave_stone, 40))  # deep inner
    # Pestle
    draw.rectangle([15, 0, 18, 12], fill=P.cave_clay)
    draw.ellipse([13, 10, 20, 17], fill=P.cave_clay)  # grinding end
    # Highlight
    draw.point((7, 8), fill=lighter(P.cave_stone, 30))

def draw_mortar_graded(draw):
    """Graded mortar with mesh rings"""
    fill_rect(draw, 5, 18, 22, 10, P.cave_stone)
    draw.ellipse([6, 3, 25, 22], fill=P.cave_stone)
    # Mesh rings (horizontal lines)
    for i, y in enumerate([8, 12, 16]):
        c = lighter(P.firefly, 10) if i == 1 else P.cave_stone
        draw.line([(10, y), (22, y)], fill=c, width=1)
    # Inner
    draw.ellipse([11, 6, 20, 17], fill=darker(P.cave_stone, 30))

def draw_firefly_lamp(draw):
    """Firefly lamp: glass dome with glow"""
    draw.rectangle([12, 20, 19, 28], fill=P.cave_clay)  # base
    draw.ellipse([7, 2, 24, 22], fill=(0x40, 0x35, 0x20, 255))  # glass
    # Glow inside
    for gy in range(8, 16):
        alpha = int(150 - abs(gy-12)*25)
        for gx in range(11, 20):
            draw.point((gx, gy), fill=(0xF5, 0xD0, 0x6B, alpha))
    # Firefly dots
    draw.point((15, 12), fill=P.firefly)
    draw.point((16, 11), fill=P.firefly)
    draw.point((15, 13), fill=P.pure_white)

def draw_crucible_thermo(draw):
    """Thermostat crucible: ceramic pot with gauge"""
    draw.ellipse([6, 10, 25, 28], fill=P.cave_clay)  # pot body
    draw.ellipse([9, 12, 22, 26], fill=darker(P.cave_clay, 25))  # inner
    # Temperature gauge
    draw.rectangle([3, 2, 7, 12], fill=P.rust_red)  # thermometer
    draw.rectangle([4, 3, 6, 8], fill=P.firefly)  # mercury
    # Handle
    draw.line([(22, 14), (28, 6)], fill=P.cave_clay, width=2)
    # Steam wisps
    for sx, sy in [(10, 7), (18, 5), (14, 3)]:
        draw.point((sx, sy), fill=P.smoke_gray)
        draw.point((sx, sy-1), fill=P.smoke_gray)

def draw_still(draw):
    """Distillation tube: coiled grass stem"""
    # Flask
    draw.ellipse([8, 18, 23, 30], fill=(0x60, 0x70, 0x80, 255))
    draw.rectangle([12, 10, 19, 20], fill=(0x60, 0x70, 0x80, 255))
    # Coil
    points = [(14, 10), (18, 8), (24, 6), (20, 4), (14, 2)]
    for i in range(len(points)-1):
        draw.line([points[i], points[i+1]], fill=P.acid_green, width=2)
    # Receiver
    draw.ellipse([2, 0, 9, 7], fill=(0x60, 0x70, 0x80, 255))
    # Drops
    draw.point((5, 4), fill=lighter(P.acid_green, 40))

def draw_nut_crucible(draw):
    """Nut shell crucible: walnut shell texture"""
    # Shell body
    draw.ellipse([4, 6, 27, 27], fill=(0x8B, 0x6E, 0x50, 255))
    # Shell ridges
    for rx in [9, 15, 21]:
        draw.arc([rx-2, 6, rx+2, 27], 0, 180, fill=darker((0x8B, 0x6E, 0x50, 255), 25), width=1)
    # Inner bowl
    draw.ellipse([10, 8, 21, 22], fill=darker((0x8B, 0x6E, 0x50, 255), 35))
    # Steam
    for sx, sy in [(13, 4), (16, 2), (19, 3)]:
        draw.point((sx, sy), fill=P.smoke_gray)

def draw_acid_bench(draw):
    """Acid-resistant workbench"""
    fill_rect(draw, 2, 16, 28, 14, P.cave_stone)
    # Acid-resistant surface
    fill_rect(draw, 4, 14, 24, 4, P.acid_green)
    # Ventilation slits
    for sx in [10, 16, 22]:
        draw.line([(sx, 18), (sx, 26)], fill=darker(P.cave_stone, 30), width=1)
    # Warning mark
    draw.point((15, 12), fill=P.lava_orange)

def draw_furnace(draw):
    """High-temp furnace: brick structure with flame"""
    # Brick body
    fill_rect(draw, 4, 10, 24, 22, P.rust_red)
    # Brick lines
    for by in [14, 18, 22, 26]:
        draw.line([(4, by), (27, by)], fill=darker(P.rust_red, 25))
    for bx in [10, 16, 22]:
        draw.line([(bx, 10), (bx, 14)], fill=darker(P.rust_red, 25))
        draw.line([(bx-3, 18), (bx-3, 22)], fill=darker(P.rust_red, 25))
        draw.line([(bx, 26), (bx, 31)], fill=darker(P.rust_red, 25))
    # Fire opening
    draw.rectangle([12, 2, 19, 11], fill=P.cave_deep)
    # Flame
    for fy in range(2, 9):
        for fx in range(13, 19):
            if abs(fx-16) + abs(fy-6) < 4:
                shade = 255 - abs(fy-5) * 30
                draw.point((fx, fy), fill=(0xFF, 0x6F, 0x00, shade))

def draw_press_hydraulic(draw):
    """Hydraulic press: piston mechanism"""
    fill_rect(draw, 8, 16, 16, 16, P.cave_stone)  # base
    # Piston shaft
    fill_rect(draw, 13, 4, 18, 18, P.smoke_gray)
    # Press plate
    fill_rect(draw, 8, 2, 24, 6, P.cave_stone)
    # Pressure gauge
    draw.ellipse([3, 20, 11, 28], fill=P.firefly_dim)
    draw.point((7, 24), fill=P.rust_red)

def draw_cure_oven(draw):
    """Curing oven: sealed clay oven"""
    draw.ellipse([4, 8, 27, 30], fill=P.cave_clay)
    # Door
    draw.rectangle([10, 14, 21, 28], fill=darker(P.cave_clay, 25))
    # Handle
    draw.point((19, 22), fill=P.firefly)
    # Thermostat dial
    draw.ellipse([3, 2, 9, 8], fill=P.firefly_dim)
    draw.line([(6, 4), (4, 2)], fill=P.pure_black)

def draw_det_testbench(draw):
    """Detonator test bench: isolated chamber"""
    fill_rect(draw, 4, 8, 24, 24, P.smoke_gray)
    # Viewing window
    fill_rect(draw, 8, 12, 16, 14, (0x30, 0x40, 0x60, 255))
    # Blast shield
    fill_rect(draw, 4, 2, 12, 10, P.cave_stone)
    # Warning stripes
    for sx in range(20, 29, 2):
        draw.point((sx, 4), fill=P.lava_orange)
        draw.point((sx, 6), fill=P.lava_orange)

def draw_soak_trough(draw):
    """Fiber soaking trough"""
    draw.rectangle([4, 12, 27, 28], fill=P.cave_stone)
    draw.rectangle([5, 13, 26, 27], fill=darker(P.cave_stone, 20))
    # Liquid inside
    draw.rectangle([8, 15, 23, 24], fill=(0x50, 0x70, 0x40, 180))
    # Fibers floating
    for fx in [10, 15, 20]:
        draw.line([(fx, 16), (fx, 23)], fill=P.surface_green, width=1)

def draw_mortar_precision(draw):
    """Precision mortar: fine ceramic with measurement marks"""
    draw.ellipse([5, 3, 26, 23], fill=P.cave_stone)
    draw.ellipse([9, 5, 22, 19], fill=darker(P.cave_stone, 20))
    # Measurement marks
    for mx, my in [(8, 8), (7, 12), (8, 16)]:
        draw.point((mx, my), fill=P.firefly)
    # Fine mesh bottom
    draw.line([(9, 20), (22, 20)], fill=P.firefly_dim)
    # Pestle (precision tip)
    fill_rect(draw, 14, 0, 17, 8, P.smoke_gray)

def draw_stone_trough(draw):
    """Basic stone trough"""
    draw.rectangle([4, 14, 27, 28], fill=P.cave_stone)
    draw.rectangle([5, 15, 26, 27], fill=darker(P.cave_stone, 25))
    # Wear marks
    for px in [(8, 17), (15, 20), (22, 18)]:
        draw.point(px, fill=lighter(P.cave_stone, 20))

EQUIPMENT = [
    ("mortar_stone", draw_mortar_stone),
    ("mortar_graded", draw_mortar_graded),
    ("mortar_precision", draw_mortar_precision),
    ("firefly_lamp", draw_firefly_lamp),
    ("crucible_thermo", draw_crucible_thermo),
    ("furnace", draw_furnace),
    ("still", draw_still),
    ("acid_bench", draw_acid_bench),
    ("nut_crucible", draw_nut_crucible),
    ("soak_trough", draw_soak_trough),
    ("press_hydraulic", draw_press_hydraulic),
    ("cure_oven", draw_cure_oven),
    ("det_testbench", draw_det_testbench),
    ("stone_trough", draw_stone_trough),
]

for name, func in EQUIPMENT:
    generate_equipment(name, func)
print(f"  ✓ {len(EQUIPMENT)} equipment icons")

# ═══════════════════════════════════════════
# 4. ANT CHARACTER (24×20, idle + walk)
# ═══════════════════════════════════════════

print("Generating ant character sprites...")

def draw_ant_body(draw, leg_phase=0):
    """Draw an ant with 3 body segments, 6 legs, 2 antennae"""
    ANT_BODY = (0x3E, 0x27, 0x23, 255)  # cave_soil
    ANT_DARK = darker(ANT_BODY, 20)
    ANT_LIGHT = lighter(ANT_BODY, 15)
    
    def ant_px(x, y, c=ANT_BODY):
        if 0 <= x < 24 and 0 <= y < 20:
            draw.point((x, y), fill=c)
    
    # Abdomen (rear, large oval)
    for ax in range(2, 10):
        for ay in range(7, 16):
            dx = ax - 6
            dy = ay - 11
            if (dx*dx)/12 + (dy*dy)/10 < 1:
                c = ANT_LIGHT if dx < 0 else ANT_BODY
                ant_px(ax, ay, c)
    # Abdomen highlight
    ant_px(3, 9, lighter(ANT_BODY, 25))
    ant_px(4, 8, lighter(ANT_BODY, 30))
    
    # Thorax (middle, smaller)
    for tx in range(10, 15):
        for ty in range(8, 14):
            dx = tx - 12
            dy = ty - 11
            if dx*dx/4 + dy*dy/5 < 1:
                ant_px(tx, ty, ANT_BODY)
    
    # Head (front, small oval)
    for hx in range(15, 20):
        for hy in range(7, 13):
            dx = hx - 17
            dy = hy - 10
            if dx*dx/5 + dy*dy/6 < 1:
                ant_px(hx, hy, ANT_DARK)
    
    # Eyes
    ant_px(18, 8, P.firefly)
    ant_px(19, 8, P.firefly)
    
    # Mandibles (jaws)
    ant_px(20, 10, ANT_DARK)
    ant_px(21, 10, ANT_DARK)
    ant_px(20, 11, ANT_DARK)
    
    # Antennae
    import math
    ant_wave = math.sin(leg_phase * 0.5) * 1
    ant_px(18, 5, ANT_DARK)
    ant_px(19 + int(ant_wave), 3, ANT_DARK)
    ant_px(20 + int(ant_wave), 2, ANT_DARK)
    ant_px(19, 6, ANT_DARK)
    ant_px(20, 5, ANT_DARK)
    
    # Legs (6 legs, 3 pairs)
    # Leg phase: 0=standing, 1=mid-step, 2=forward
    leg_positions = [
        # (body_x, body_y, length, forward)
        (10, 13, 4, True),   # rear left
        (10, 13, 4, False),  # rear right
        (12, 12, 3, True),   # mid left
        (12, 12, 3, False),  # mid right
        (14, 11, 3, True),   # front left
        (14, 11, 3, False),  # front right
    ]
    
    for i, (bx, by, length, is_left) in enumerate(leg_positions):
        phase_offset = i * 0.7
        lp = (leg_phase + phase_offset) % 3
        direction = 1 if is_left else -1
        
        for seg in range(length):
            if lp < 1:
                # Leg extended down
                lx = bx + int(direction * (0.5 + seg * 0.8))
                ly = by + seg
            elif lp < 2:
                # Leg mid-step
                lx = bx + int(direction * (0.5 + seg * 0.5))
                ly = by + seg - 1
            else:
                # Leg forward
                lx = bx + int(direction * (1 + seg * 0.3))
                ly = by + seg - 1
            ant_px(lx, ly, ANT_BODY)

# Idle frames (subtle breathing)
for frame in range(4):
    img = create_sprite(24, 20)
    draw = ImageDraw.Draw(img)
    # Subtle body movement
    breath = math.sin(frame * math.pi / 2) * 0.3
    draw_ant_body(draw, leg_phase=0 + breath)
    arr = np.array(img)
    outlined = apply_pixel_outline(Image.fromarray(arr))
    save(outlined, f"ant_idle_{frame}.png")

# Walk frames (6 frames)
for frame in range(6):
    img = create_sprite(24, 20)
    draw = ImageDraw.Draw(img)
    draw_ant_body(draw, leg_phase=frame)
    # Add slight body bob
    arr = np.array(img)
    outlined = apply_pixel_outline(Image.fromarray(arr))
    save(outlined, f"ant_walk_{frame}.png")

print("  ✓ ant idle (4 frames) + walk (6 frames)")

# ═══════════════════════════════════════════
# 5. MISC SPRITES
# ═══════════════════════════════════════════

# Explosive placed
img = create_sprite(8, 12)
draw = ImageDraw.Draw(img)
fill_rect(draw, 1, 1, 6, 10, P.firefly)
fill_rect(draw, 2, 2, 4, 2, P.lava_orange)  # fuse top
draw.point((3, 0), fill=P.lava_orange)  # spark
draw.point((4, 1), fill=P.pure_white)
arr = np.array(img)
save(apply_pixel_outline(Image.fromarray(arr)), "explosive_placed.png")

# Firefly glow
img = create_sprite(20, 20)
draw = ImageDraw.Draw(img)
for dy in range(20):
    for dx in range(20):
        dist = math.sqrt((dx-10)**2 + (dy-10)**2)
        if dist < 9:
            alpha = max(0, int(200 * (1 - dist/9)))
            draw.point((dx, dy), fill=(0xF5, 0xD0, 0x6B, alpha))
# Core
draw.ellipse([8, 8, 12, 12], fill=P.pure_white)
save(img, "firefly_glow.png")

# Building blocks
for name, w, h, color in [
    ("brick_soil_32x32", 32, 32, P.cave_soil),
    ("brick_stone_32x32", 32, 32, P.cave_stone),
    ("brick_clay_32x32", 32, 32, P.cave_clay),
    ("brick_soil_64x32", 64, 32, P.cave_soil),
    ("brick_stone_64x32", 64, 32, P.cave_stone),
    ("brick_rust_64x32", 64, 32, P.rust_red),
    ("brick_clay_64x32", 64, 32, P.cave_clay),
]:
    img = create_sprite(w, h)
    draw = ImageDraw.Draw(img)
    # Textured fill
    noise = fbm((h, w), octaves=2, scale=8.0, seed=hash(name)%1000)
    for y in range(h):
        for x in range(w):
            n = noise[y, x]
            if n < 0.4:
                c = darker(color, int(25*(0.4-n)/0.4))
            elif n < 0.7:
                c = color
            else:
                c = lighter(color, int(15*(n-0.7)/0.3))
            draw.point((x, y), fill=c)
    # Brick lines for larger blocks
    if w >= 64:
        for bx in [w//2]:
            draw.line([(bx, 0), (bx, h-1)], fill=darker(color, 30))
        for by in [h//2]:
            draw.line([(0, by), (w-1, by)], fill=darker(color, 20))
    arr = np.array(img)
    save(apply_pixel_outline(Image.fromarray(arr)), f"{name}.png")

# Particle sprites
for name, w, h, colors in [
    ("particle_smoke", 8, 8, [P.smoke_gray, (0x80, 0x80, 0x80, 200), (0x60, 0x60, 0x60, 120)]),
    ("particle_fire", 8, 8, [P.lava_orange, P.firefly, (0xFF, 0xFF, 0x40, 200)]),
    ("particle_spark", 4, 4, [P.pure_white, P.firefly]),
]:
    img = create_sprite(w, h)
    draw = ImageDraw.Draw(img)
    rng = random.Random(99)
    for y in range(h):
        for x in range(w):
            if rng.random() < 0.6:
                c = colors[rng.randint(0, len(colors)-1)]
                draw.point((x, y), fill=c)
    save(img, f"{name}.png")

# UI elements
img = create_sprite(16, 16)
draw = ImageDraw.Draw(img)
draw.rectangle([0, 0, 15, 15], fill=P.ui_bg)
draw.rectangle([1, 1, 14, 14], outline=P.firefly)
save(img, "ui_node_known_explosive.png")

img = create_sprite(16, 16)
draw = ImageDraw.Draw(img)
draw.rectangle([0, 0, 15, 15], fill=P.ui_bg)
# Diamond
cx, cy = 8, 8
draw.polygon([(cx,2),(14,cy),(cx,13),(2,cy)], outline=P.acid_green)
save(img, "ui_node_intermediate.png")

img = create_sprite(16, 16)
draw = ImageDraw.Draw(img)
draw.rectangle([0, 0, 15, 15], fill=P.ui_bg)
# Dashed outline
for i in range(0, 4):
    draw.point((3+i*3, 1), fill=(0x55, 0x55, 0x55, 255))
    draw.point((14, 3+i*3), fill=(0x55, 0x55, 0x55, 255))
    draw.point((3+i*3, 14), fill=(0x55, 0x55, 0x55, 255))
    draw.point((1, 3+i*3), fill=(0x55, 0x55, 0x55, 255))
save(img, "ui_node_locked.png")

# Naming dialog background
img = create_sprite(240, 100)
draw = ImageDraw.Draw(img)
fill_rect(draw, 0, 0, 240, 100, P.ui_bg)
draw.rectangle([0, 0, 239, 99], outline=P.firefly)
save(img, "ui_naming_bg.png")

print("  ✓ misc sprites (explosive, blocks, particles, UI)")

# ═══════════════════════════════════════════
# 6. INTERMEDIATE ICONS
# ═══════════════════════════════════════════

for name, color in [
    ("inter_aromatic_oil", (0xDA, 0xA6, 0x22, 255)),
    ("inter_carbon_fiber", (0x40, 0x40, 0x40, 255)),
    ("inter_nitrating_acid", (0x9E, 0xD8, 0x40, 255)),
    ("inter_stabilizing_wax", (0xF5, 0xE0, 0xA0, 255)),
]:
    img = create_sprite(16, 16)
    draw = ImageDraw.Draw(img)
    cx, cy = 8, 8
    for y in range(1, 15):
        half_w = int(6.5 - abs(y-7.5) * 0.8)
        for x in range(cx - max(1, half_w), cx + max(1, half_w)):
            if 0 <= x < 16:
                draw.point((x, y), fill=color)
    # Highlight edge
    for dy in range(2, 6):
        draw.point((cx, cy-dy), fill=lighter(color, 40))
    arr = np.array(img)
    save(apply_pixel_outline(Image.fromarray(arr)), f"{name}.png")

print("  ✓ intermediate icons")

# ═══════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════

all_pngs = [f for f in os.listdir(OUT) if f.endswith('.png')]
print(f"\n{'='*50}")
print(f"✓ All sprites generated in: {OUT}")
print(f"Total: {len(all_pngs)} files")
print(f"{'='*50}")


# ═══════════════════════════════════════════
# 7. CHAPTER 2 — SURFACE ASSETS
# ═══════════════════════════════════════════

print("\nGenerating Chapter 2 surface assets...")

# ---------- Surface ground tile (32×32, repeatable) ----------
S = 32
img = create_sprite(S, S)
draw = ImageDraw.Draw(img)
noise = fbm((S, S), octaves=3, scale=6.0, seed=200)
noise2 = fbm((S, S), octaves=2, scale=10.0, seed=210)
for y in range(S):
    for x in range(S):
        n = noise[y, x]
        if n < 0.3:
            c = darker(P.surface_green, 25)
        elif n < 0.55:
            c = P.surface_green
        elif n < 0.75:
            c = lighter(P.surface_green, 12)
        else:
            c = lighter(P.surface_green, 25)
        # Dirt specks
        if noise2[y, x] > 0.8:
            c = P.cave_clay if noise2[y, x] > 0.92 else c
        draw.point((x, y), fill=c)
# Edge blending for tiling
for i in range(S):
    img.putpixel((i, 0), blend(img.getpixel((i, 0)), img.getpixel((i, S-1)), 0.5))
    img.putpixel((i, S-1), blend(img.getpixel((i, 0)), img.getpixel((i, S-1)), 0.5))
    img.putpixel((0, i), blend(img.getpixel((0, i)), img.getpixel((S-1, i)), 0.5))
    img.putpixel((S-1, i), blend(img.getpixel((0, i)), img.getpixel((S-1, i)), 0.5))
save(img, "surface_ground_tile.png")

# ---------- Grass blades (various heights) ----------
for i, h in enumerate([40, 56, 72, 60, 48, 80]):
    img = create_sprite(6, h)
    draw = ImageDraw.Draw(img)
    # Main blade
    for y in range(h):
        sway = int(math.sin(y * 0.08 + i * 0.7) * (1 + y * 0.01))
        w = max(1, int(3 * (1 - y/h * 0.6)))
        for dx in range(-w//2 + sway, w//2 + 1 + sway):
            x = 3 + dx
            if 0 <= x < 6:
                shade = int(20 * (y/h))
                c = darker(P.surface_green, shade) if x == 3 else P.surface_green
                draw.point((x, y), fill=c)
    # Tip highlight
    if h > 1:
        draw.point((3, 0), fill=lighter(P.surface_green, 40))
    arr = np.array(img)
    save(apply_pixel_outline(Image.fromarray(arr)), f"grass_blade_{i}.png")

# ---------- Bottle cap (60×20 obstacle) ----------
img = create_sprite(60, 20)
draw = ImageDraw.Draw(img)
# Cap body (circular top-down view)
draw.ellipse([2, 2, 57, 17], fill=P.rust_red)
draw.ellipse([4, 3, 55, 16], fill=lighter(P.rust_red, 15))
# Ridges (edge crimps)
for angle_deg in range(0, 360, 20):
    rad = math.radians(angle_deg)
    cx, cy = 30, 10
    rx = int(cx + math.cos(rad) * 26)
    ry = int(cy + math.sin(rad) * 7)
    draw.point((rx, ry), fill=darker(P.rust_red, 40))
# Inner circle
draw.ellipse([16, 5, 43, 14], fill=darker(P.rust_red, 20))
# Specular highlight
draw.ellipse([18, 4, 25, 8], fill=lighter(P.rust_red, 40))
arr = np.array(img)
save(apply_pixel_outline(Image.fromarray(arr)), "obstacle_bottlecap.png")

# ---------- Matchbox (40×24 obstacle) ----------
img = create_sprite(40, 24)
draw = ImageDraw.Draw(img)
# Outer box
color_box = (0xDC, 0xC8, 0x90, 255)  # beige cardboard
fill_rect(draw, 1, 1, 38, 22, color_box)
# Cardboard texture lines
for ly in range(3, 21, 4):
    draw.line([(2, ly), (37, ly)], fill=darker(color_box, 10))
# Inner drawer (slightly pulled out)
fill_rect(draw, 4, 6, 20, 17, darker(color_box, 15))
# Striker strip (dark brown on side)
fill_rect(draw, 35, 3, 38, 20, (0x60, 0x40, 0x30, 255))
# Striker dots
for sx in range(36, 39):
    for sy in range(5, 19, 3):
        draw.point((sx, sy), fill=darker((0x60, 0x40, 0x30, 255), 20))
arr = np.array(img)
save(apply_pixel_outline(Image.fromarray(arr)), "obstacle_matchbox.png")

# ---------- Grass stem obstacle (fiber structure) ----------
for i, h in enumerate([64, 80, 96]):
    img = create_sprite(8, h)
    draw = ImageDraw.Draw(img)
    # Thick stem with fiber lines
    for y in range(h):
        sway = int(math.sin(y * 0.06 + i) * 1)
        base_x = 4 + sway
        draw.point((base_x, y), fill=darker(P.surface_green, 20))  # core fiber
        draw.point((base_x-1, y), fill=P.surface_green)
        draw.point((base_x+1, y), fill=P.surface_green)
        # Fiber bands every 12px
        if y % 12 < 3:
            draw.point((base_x-2, y), fill=darker(P.surface_green, 10))
            draw.point((base_x+2, y), fill=darker(P.surface_green, 10))
    # Node points (where you should place explosives)
    for ny in [h//3, 2*h//3]:
        for dx in range(-2, 3):
            draw.point((4+dx, ny), fill=lighter(P.acid_green, 20))
        draw.point((4, ny), fill=P.acid_green)
    arr = np.array(img)
    save(apply_pixel_outline(Image.fromarray(arr)), f"obstacle_stem_{i}.png")

# ---------- Rubble pieces ----------
for i in range(4):
    size = random.randint(16, 24)
    img = create_sprite(size, size)
    draw = ImageDraw.Draw(img)
    rng = random.Random(400 + i)
    # Irregular polygon
    pts = []
    cx, cy = size//2, size//2
    for a in range(0, 360, rng.randint(40, 80)):
        rad = math.radians(a)
        r = rng.randint(size//4, size//2 - 1)
        px = int(cx + math.cos(rad) * r)
        py = int(cy + math.sin(rad) * r)
        pts.append((px, py))
    if len(pts) >= 3:
        draw.polygon(pts, fill=P.cave_stone)
        # Facet highlight
        draw.point(pts[0], fill=lighter(P.cave_stone, 30))
        draw.point(pts[-1], fill=darker(P.cave_stone, 25))
    arr = np.array(img)
    save(apply_pixel_outline(Image.fromarray(arr)), f"rubble_{i}.png")

# ---------- Sky background gradient ----------
img = create_sprite(192, 80)
draw = ImageDraw.Draw(img)
SKY_TOP = (0x87, 0xCE, 0xEB, 255)  # light blue (DESIGN.md exception for Ch2)
for y in range(80):
    t = y / 80
    r = int(SKY_TOP[0] * (1-t) + 0xFF * t)
    g = int(SKY_TOP[1] * (1-t) + 0xFF * t)
    b = int(SKY_TOP[2] * (1-t) + 0xFF * t)
    for x in range(192):
        draw.point((x, y), fill=(r, g, b, 255))
save(img, "bg_sky.png")

print("  ✓ surface ground, 6 grass blades, bottlecap, matchbox, 3 stems, 4 rubble, sky")

# ═══════════════════════════════════════════
# 8. CHAPTER 3 — ENEMY ASSETS
# ═══════════════════════════════════════════

print("Generating Chapter 3 enemy assets...")

# ---------- Fire ant soldier (24×20, idle + patrol) ----------
def draw_fireant(draw, leg_phase=0):
    FA_BODY = P.lava_orange
    FA_DARK = darker(FA_BODY, 35)
    FA_LIGHT = lighter(FA_BODY, 20)
    
    def fp(x, y, c=FA_BODY):
        if 0 <= x < 24 and 0 <= y < 20:
            draw.point((x, y), fill=c)
    
    # Abdomen (rear, pointed — more aggressive)
    for ax in range(1, 11):
        for ay in range(7, 16):
            dx = ax - 5
            dy = ay - 11
            if (dx*dx)/14 + (dy*dy)/10 < 1:
                fp(ax, ay, FA_BODY if dx < 1 else FA_DARK)
    # Stinger
    fp(0, 11, FA_DARK)
    fp(0, 10, P.pure_black)
    
    # Thorax
    for tx in range(10, 15):
        for ty in range(8, 14):
            dx = tx - 12
            dy = ty - 11
            if dx*dx/4 + dy*dy/5 < 1:
                fp(tx, ty, FA_DARK)
    
    # Head (larger, more menacing)
    for hx in range(15, 21):
        for hy in range(6, 13):
            dx = hx - 17
            dy = hy - 9
            if dx*dx/6 + dy*dy/7 < 1:
                fp(hx, hy, FA_DARK)
    
    # Eyes (glowing orange)
    fp(19, 7, P.firefly)
    fp(20, 7, P.firefly)
    fp(19, 8, P.pure_white)
    
    # Mandibles (larger, combat-ready)
    fp(21, 9, P.rust_red)
    fp(22, 10, P.rust_red)
    fp(21, 10, P.pure_black)
    fp(22, 9, P.pure_black)
    
    # Antennae
    fp(19, 4, FA_DARK)
    fp(20, 2, FA_DARK)
    fp(20, 5, FA_DARK)
    
    # Legs (6 legs, more angular)
    leg_data = [
        (9, 13, 4, 1), (9, 13, 4, -1),
        (11, 12, 3, 1), (11, 12, 3, -1),
        (13, 11, 3, 1), (13, 11, 3, -1),
    ]
    for i, (bx, by, length, direction) in enumerate(leg_data):
        lp = (leg_phase + i * 0.7) % 3
        for seg in range(length):
            if lp < 1:
                lx = bx + int(direction * (0.5 + seg * 0.8))
                ly = by + seg
            elif lp < 2:
                lx = bx + int(direction * (0.5 + seg * 0.5))
                ly = by + seg - 1
            else:
                lx = bx + int(direction * (1 + seg * 0.3))
                ly = by + seg - 1
            fp(lx, ly, FA_BODY)

# Idle frames
for frame in range(4):
    img = create_sprite(24, 20)
    draw = ImageDraw.Draw(img)
    breath = math.sin(frame * math.pi / 2) * 0.3
    draw_fireant(draw, leg_phase=0 + breath)
    arr = np.array(img)
    save(apply_pixel_outline(Image.fromarray(arr)), f"fireant_idle_{frame}.png")

# Patrol frames (walking)
for frame in range(6):
    img = create_sprite(24, 20)
    draw = ImageDraw.Draw(img)
    draw_fireant(draw, leg_phase=frame)
    arr = np.array(img)
    save(apply_pixel_outline(Image.fromarray(arr)), f"fireant_walk_{frame}.png")

print("  ✓ fire ant idle (4) + walk (6)")

# ---------- Enemy nest wall tile (32×32) ----------
img = create_sprite(32, 32)
draw = ImageDraw.Draw(img)
noise = fbm((32, 32), octaves=3, scale=6.0, seed=500)
for y in range(32):
    for x in range(32):
        n = noise[y, x]
        if n < 0.3:
            c = darker(P.rust_red, 30)
        elif n < 0.55:
            c = P.rust_red
        elif n < 0.75:
            c = blend(P.rust_red, P.lava_orange, 0.3)
        else:
            c = P.lava_orange
        draw.point((x, y), fill=c)
# Edge blending
for i in range(32):
    img.putpixel((i, 0), blend(img.getpixel((i, 0)), img.getpixel((i, 31)), 0.5))
    img.putpixel((i, 31), blend(img.getpixel((i, 0)), img.getpixel((i, 31)), 0.5))
save(img, "nest_wall_tile.png")

# ---------- Enemy wall block (64×32, 3-layer stack) ----------
for layer in range(3):
    img = create_sprite(64, 32)
    draw = ImageDraw.Draw(img)
    noise = fbm((32, 64), octaves=2, scale=8.0, seed=510+layer)
    for y in range(32):
        for x in range(64):
            n = noise[y, x]
            shade = int((n - 0.5) * 40)
            c = tuple(max(0, min(255, P.rust_red[i] + shade)) for i in range(3)) + (255,)
            draw.point((x, y), fill=c)
    # Crack lines for damage
    rng = random.Random(520+layer)
    for _ in range(2):
        sx = rng.randint(10, 50)
        sy = rng.randint(2, 28)
        for _ in range(rng.randint(3, 8)):
            draw.point((sx, sy), fill=darker(P.rust_red, 40))
            sx += rng.randint(-1, 1)
            sy += rng.randint(0, 1)
            if not (0 <= sx < 64 and 0 <= sy < 32):
                break
    arr = np.array(img)
    save(apply_pixel_outline(Image.fromarray(arr)), f"nest_wall_{layer}.png")

# ---------- Ant acid jar (16×24) ----------
img = create_sprite(16, 24)
draw = ImageDraw.Draw(img)
# Jar body
draw.rectangle([3, 4, 12, 22], fill=(0x40, 0x60, 0x30, 200))
draw.ellipse([3, 16, 12, 23], fill=(0x40, 0x60, 0x30, 200))
# Acid inside (green liquid)
draw.rectangle([4, 10, 11, 21], fill=P.acid_green)
# Acid surface line
draw.line([(4, 11), (11, 11)], fill=lighter(P.acid_green, 30))
# Bubbles
draw.point((7, 14), fill=lighter(P.acid_green, 50))
draw.point((9, 16), fill=lighter(P.acid_green, 40))
# Cork stopper
fill_rect(draw, 4, 1, 11, 5, P.cave_clay)
# Warning glow
draw.point((8, 12), fill=P.pure_white)
arr = np.array(img)
save(apply_pixel_outline(Image.fromarray(arr)), "enemy_acid_jar.png")

# ---------- Larvae pod (24×24) ----------
img = create_sprite(24, 24)
draw = ImageDraw.Draw(img)
# Membrane
draw.ellipse([3, 3, 20, 20], fill=(0xDC, 0xC8, 0x90, 180))
# Larva inside
draw.ellipse([6, 6, 17, 17], fill=(0xF5, 0xE0, 0xA0, 255))
# Larva segments
for lx in [9, 12, 15]:
    draw.line([(lx, 10), (lx, 14)], fill=darker((0xF5, 0xE0, 0xA0, 255), 20))
# Eye spots
draw.point((17, 9), fill=P.pure_black)
draw.point((17, 12), fill=P.pure_black)
# Membrane veins
draw.arc([5, 5, 18, 18], 0, 180, fill=lighter((0xDC, 0xC8, 0x90, 255), 20))
draw.arc([5, 5, 18, 18], 180, 360, fill=darker((0xDC, 0xC8, 0x90, 255), 15))
arr = np.array(img)
save(apply_pixel_outline(Image.fromarray(arr)), "enemy_larvae_pod.png")

print("  ✓ nest wall, 3 wall blocks, acid jar, larvae pod")

# ═══════════════════════════════════════════
# 9. LAB SUPPLEMENTS
# ═══════════════════════════════════════════

print("Generating lab supplements...")

# ---------- Workbench (32×96 stone slab) ----------
img = create_sprite(32, 96)
draw = ImageDraw.Draw(img)
noise = fbm((96, 32), octaves=4, scale=5.0, seed=600)
for y in range(96):
    for x in range(32):
        n = noise[y, x]
        if n < 0.35:
            c = darker(P.cave_stone, 25)
        elif n < 0.6:
            c = P.cave_stone
        elif n < 0.8:
            c = lighter(P.cave_stone, 12)
        else:
            c = lighter(P.cave_stone, 25)
        # Horizontal grain
        if n > 0.85 and y % 4 < 2:
            c = lighter(P.cave_stone, 30)
        draw.point((x, y), fill=c)
# Top surface with slight perspective
for x in range(32):
    draw.point((x, 0), fill=lighter(P.cave_stone, 35))
    draw.point((x, 1), fill=lighter(P.cave_stone, 20))
arr = np.array(img)
save(apply_pixel_outline(Image.fromarray(arr)), "lab_workbench.png")

# ---------- Nut crucible animation frames (bubbling, 8 frames) ----------
for frame in range(8):
    img = create_sprite(32, 24)
    draw = ImageDraw.Draw(img)
    # Shell body
    draw.ellipse([3, 4, 28, 22], fill=(0x8B, 0x6E, 0x50, 255))
    # Shell ridges
    for rx in [8, 14, 20]:
        draw.arc([rx-2, 4, rx+2, 22], 0, 180, fill=darker((0x8B, 0x6E, 0x50, 255), 20), width=1)
    # Inner bowl
    draw.ellipse([8, 6, 23, 18], fill=darker((0x8B, 0x6E, 0x50, 255), 30))
    # Liquid inside (varies by frame)
    liquid_color = blend(P.acid_green, P.firefly, 0.3 + frame * 0.05) if frame < 6 else P.lava_orange
    draw.ellipse([10, 10, 21, 16], fill=liquid_color)
    # Bubbles
    rng = random.Random(700 + frame)
    for _ in range(2 + frame % 3):
        bx = rng.randint(11, 19)
        by = rng.randint(7, 12)
        size = rng.randint(1, 2)
        if size == 1:
            draw.point((bx, by), fill=lighter(liquid_color, 60))
        else:
            draw.ellipse([bx, by, bx+1, by+1], fill=lighter(liquid_color, 40))
    # Steam wisps above
    for sx, sy in [(10, 2+frame%2), (19, 1+(frame+1)%3), (15, 3+frame%2)]:
        alpha = max(30, 180 - frame * 20)
        draw.point((sx, sy), fill=(0x9E, 0x9E, 0x9E, alpha))
    arr = np.array(img)
    save(apply_pixel_outline(Image.fromarray(arr)), f"crucible_bubble_{frame}.png")

print("  ✓ workbench, crucible bubble 8 frames")

# ---------- Fuse burning animation (2×16, 6 frames) ----------
for frame in range(6):
    img = create_sprite(4, 16)
    draw = ImageDraw.Draw(img)
    burn_progress = frame / 5  # 0 = unlit, 1 = fully burned
    for y in range(16):
        progress_at_y = 1 - y / 15
        if progress_at_y > burn_progress:
            # Unburnt fuse
            draw.point((1, y), fill=P.cave_clay)
            draw.point((2, y), fill=P.firefly_dim)
        else:
            # Burnt ash
            draw.point((1, y), fill=P.smoke_gray)
            draw.point((2, y), fill=darker(P.smoke_gray, 20))
    # Spark at burn front
    spark_y = int(15 * (1 - burn_progress))
    if 0 <= spark_y < 16:
        draw.point((2, spark_y), fill=P.firefly)
        draw.point((3, spark_y), fill=P.lava_orange)
        if spark_y > 0:
            draw.point((1, spark_y-1), fill=P.pure_white)  # bright spark
    arr = np.array(img)
    save(apply_pixel_outline(Image.fromarray(arr)), f"fuse_burn_{frame}.png")

print("  ✓ fuse burn 6 frames")

# ═══════════════════════════════════════════
# 10. ANIMATIONS
# ═══════════════════════════════════════════

print("Generating animation frames...")

# ---------- Firefly flicker (6 frames, brightness pulse) ----------
for frame in range(6):
    img = create_sprite(20, 20)
    draw = ImageDraw.Draw(img)
    # Pulsing brightness
    pulse = 0.5 + 0.5 * math.sin(frame * math.pi / 3)
    max_alpha = int(150 + 100 * pulse)
    for dy in range(20):
        for dx in range(20):
            dist = math.sqrt((dx-10)**2 + (dy-10)**2)
            if dist < 9:
                alpha = max(0, int(max_alpha * (1 - dist/9) * (1 - dist/9)))
                draw.point((dx, dy), fill=(0xF5, 0xD0, 0x6B, alpha))
    # Core (brightness varies)
    core_alpha = int(200 + 55 * pulse)
    draw.ellipse([7, 7, 13, 13], fill=(0xFF, 0xFF, 0xE0, core_alpha))
    draw.ellipse([9, 9, 11, 11], fill=(0xFF, 0xFF, 0xFF, core_alpha))
    save(img, f"firefly_flicker_{frame}.png")

# ---------- Explosion flash (4 frames) ----------
flash_colors = [
    (0xFF, 0xFF, 0xFF, 255),  # frame 0: pure white
    (0xFF, 0xFF, 0xE0, 220),  # frame 1: bright yellow-white
    (0xFF, 0xD0, 0x40, 160),  # frame 2: orange-yellow fading
    (0xFF, 0x80, 0x00, 80),   # frame 3: orange, mostly transparent
]
for frame in range(4):
    img = create_sprite(256, 256)
    draw = ImageDraw.Draw(img)
    color = flash_colors[frame]
    # Radial gradient for more natural flash
    for dy in range(256):
        for dx in range(256):
            dist = math.sqrt((dx-128)**2 + (dy-128)**2) / 180
            if dist < 1:
                alpha = int(color[3] * (1 - dist))
                draw.point((dx, dy), fill=color[:3] + (alpha,))
    save(img, f"explosion_flash_{frame}.png")

# ---------- Impact shockwave ring ----------
for frame in range(5):
    radius = 20 + frame * 25
    img = create_sprite(200, 200)
    draw = ImageDraw.Draw(img)
    cx, cy = 100, 100
    # Draw expanding ring
    for angle in range(0, 360, 2):
        rad = math.radians(angle)
        for r_offset in [-1, 0, 1]:
            r = radius + r_offset
            x = int(cx + math.cos(rad) * r)
            y = int(cy + math.sin(rad) * r)
            if 0 <= x < 200 and 0 <= y < 200:
                alpha = max(0, 200 - frame * 40 - abs(r_offset) * 60)
                draw.point((x, y), fill=(0xFF, 0xFF, 0xFF, alpha))
    save(img, f"shockwave_{frame}.png")

print("  ✓ firefly 6 frames, explosion flash 4, shockwave 5")

# ═══════════════════════════════════════════
# 11. UI BUTTONS (64×32)
# ═══════════════════════════════════════════

print("Generating UI buttons...")

def make_button(name, border_color, text_color=None):
    img = create_sprite(96, 32)
    draw = ImageDraw.Draw(img)
    # Background
    fill_rect(draw, 0, 0, 96, 32, P.ui_bg)
    # Border
    draw.rectangle([0, 0, 95, 31], outline=border_color)
    # Inner highlight (top-left)
    for dx in range(1, 5):
        draw.point((dx, 1), fill=lighter(border_color, 30))
    for dy in range(1, 5):
        draw.point((1, dy), fill=lighter(border_color, 30))
    save(img, f"ui_btn_{name}.png")

make_button("default", P.firefly_dim)
make_button("hover", P.firefly)
make_button("disabled", (0x33, 0x33, 0x33, 255))

# Pressed variant
img = create_sprite(96, 32)
draw = ImageDraw.Draw(img)
fill_rect(draw, 0, 0, 96, 32, P.ui_bg_hover)
draw.rectangle([0, 0, 95, 31], outline=P.firefly)
# Inner shadow (pressed — bottom-right instead of top-left)
for dx in range(90, 95):
    draw.point((dx, 30), fill=darker(P.firefly, 20))
for dy in range(27, 31):
    draw.point((94, dy), fill=darker(P.firefly, 20))
save(img, "ui_btn_pressed.png")

print("  ✓ 4 button states")

# ═══════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════

all_pngs = [f for f in os.listdir(OUT) if f.endswith('.png')]
print(f"\n{'='*50}")
print(f"✓ ALL sprites generated in: {OUT}")
print(f"Total: {len(all_pngs)} files")
# Count by category
cats = {}
for f in all_pngs:
    prefix = f.split('_')[0]
    cats[prefix] = cats.get(prefix, 0) + 1
for cat, count in sorted(cats.items()):
    print(f"  {cat}: {count}")
print(f"{'='*50}")
