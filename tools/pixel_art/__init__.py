"""
AntChem Pixel Art Engine — procedural high-quality pixel art
Noise, dithering, crystal growth, outline/highlight rendering
"""

import numpy as np
from PIL import Image, ImageDraw
import math, random

# ═══════════════════════════════════════════
# COLOR PALETTE (from DESIGN.md)
# ═══════════════════════════════════════════
class Palette:
    cave_deep    = (0x0D, 0x06, 0x04, 255)
    cave_soil    = (0x3E, 0x27, 0x23, 255)
    cave_stone   = (0x78, 0x90, 0x9C, 255)
    cave_clay    = (0x8D, 0x6E, 0x63, 255)
    firefly      = (0xF5, 0xD0, 0x6B, 255)
    firefly_dim  = (0xC4, 0xA4, 0x4A, 255)
    acid_green   = (0x7C, 0xB3, 0x42, 255)
    rust_red     = (0xA0, 0x52, 0x2D, 255)
    lava_orange  = (0xFF, 0x6F, 0x00, 255)
    surface_green= (0x55, 0x8B, 0x2F, 255)
    smoke_gray   = (0x9E, 0x9E, 0x9E, 255)
    pure_black   = (0x00, 0x00, 0x00, 255)
    pure_white   = (0xFF, 0xFF, 0xFF, 255)
    transparent  = (0, 0, 0, 0)
    ui_bg        = (0x1A, 0x12, 0x10, 255)
    ui_bg_hover  = (0x2A, 0x1F, 0x15, 255)
    
    @classmethod
    def all_except_transparent(cls):
        return [v for k, v in vars(cls).items() 
                if not k.startswith('_') and isinstance(v, tuple) and v[3] > 0]

P = Palette()

# ═══════════════════════════════════════════
# NOISE FUNCTIONS
# ═══════════════════════════════════════════

def _hash22(p):
    """2D -> pseudo-random value in [0,1)"""
    n = np.sin(np.dot(p, np.array([127.1, 311.7]))) * 43758.5453
    return (n - np.floor(n))

def value_noise(shape, scale=4.0, seed=0):
    """Value noise at given shape with grid spacing = scale pixels"""
    rng = np.random.RandomState(seed)
    h, w = shape
    # Create coarse grid of random values
    gh = max(2, int(np.ceil(h / scale)) + 1)
    gw = max(2, int(np.ceil(w / scale)) + 1)
    grid = rng.rand(gh, gw)
    # Interpolate to full resolution
    y_coords = np.arange(h) / scale
    x_coords = np.arange(w) / scale
    yi = np.floor(y_coords).astype(int)
    xi = np.floor(x_coords).astype(int)
    yf = (y_coords - yi).reshape(-1, 1)
    xf = (x_coords - xi).reshape(1, -1)
    # Smoothstep interpolation
    yf = yf * yf * (3 - 2 * yf)
    xf = xf * xf * (3 - 2 * xf)
    # Bilinear interpolation
    yi = np.clip(yi, 0, gh - 1)
    xi = np.clip(xi, 0, gw - 1)
    yi1 = np.clip(yi + 1, 0, gh - 1)
    xi1 = np.clip(xi + 1, 0, gw - 1)
    
    result = (grid[yi.reshape(-1,1), xi.reshape(1,-1)] * (1-yf) * (1-xf) +
              grid[yi1.reshape(-1,1), xi.reshape(1,-1)] * yf * (1-xf) +
              grid[yi.reshape(-1,1), xi1.reshape(1,-1)] * (1-yf) * xf +
              grid[yi1.reshape(-1,1), xi1.reshape(1,-1)] * yf * xf)
    return result

def fbm(shape, octaves=3, scale=4.0, lacunarity=2.0, gain=0.5, seed=0):
    """Fractal Brownian Motion — multi-octave noise"""
    result = np.zeros(shape)
    amplitude = 1.0
    frequency = 1.0
    max_val = 0.0
    for i in range(octaves):
        result += amplitude * value_noise(shape, scale / frequency, seed + i * 100)
        max_val += amplitude
        amplitude *= gain
        frequency *= lacunarity
    return result / max_val

# ═══════════════════════════════════════════
# DITHERING
# ═══════════════════════════════════════════

def bayer_matrix(order=4):
    """Generate Bayer ordered dithering matrix"""
    if order == 0:
        return np.array([[0]])
    prev = bayer_matrix(order - 1)
    n = 2 ** (order - 1)
    top = 4 * prev
    top_right = 4 * prev + 2
    bottom_left = 4 * prev + 3
    bottom_right = 4 * prev + 1
    top_half = np.hstack([top, top_right])
    bottom_half = np.hstack([bottom_left, bottom_right])
    return np.vstack([top_half, bottom_half])

def apply_dither(pixels, color_a, color_b, threshold_map=None):
    """Dither between two colors using Bayer matrix"""
    h, w = pixels.shape[:2]
    if threshold_map is None:
        bm = bayer_matrix(4)
    else:
        bm = threshold_map
    bm_norm = bm / (bm.max() + 1)
    # Tile the matrix to match image size
    tiled = np.tile(bm_norm, (int(np.ceil(h/bm.shape[0])), int(np.ceil(w/bm.shape[1]))))[:h, :w]
    result = np.zeros((h, w, 4), dtype=np.uint8)
    for c in range(4):
        result[:,:,c] = np.where(tiled > 0.5, color_a[c], color_b[c])
    return result

# ═══════════════════════════════════════════
# RENDERING UTILITIES
# ═══════════════════════════════════════════

def create_sprite(w, h):
    """Create a new RGBA sprite"""
    return Image.new("RGBA", (w, h), P.transparent)

def outline_rect(draw, x, y, w, h, color=P.pure_black):
    """1px outline rectangle"""
    draw.rectangle([x, y, x+w-1, y+h-1], outline=color)

def fill_rect(draw, x, y, w, h, color):
    """Fill rectangle"""
    draw.rectangle([x, y, x+w-1, y+h-1], fill=color)

def rim_light(draw, x, y, w, h, light_color, thickness=1):
    """Top-left rim light highlight (single light source at 45° top-left)"""
    # Top edge highlight
    for dx in range(thickness, min(w-1, 5)):
        draw.point((x+dx, y+1), fill=light_color)
    # Left edge highlight
    for dy in range(thickness, min(h-1, 5)):
        draw.point((x+1, y+dy), fill=light_color)

def lighter(color, amount=40):
    """Lighten a color"""
    return tuple(min(255, c + amount) for c in color[:3]) + (255,)

def darker(color, amount=40):
    """Darken a color"""
    return tuple(max(0, c - amount) for c in color[:3]) + (255,)

def blend(c1, c2, t=0.5):
    """Blend two colors"""
    return tuple(int(c1[i] * (1-t) + c2[i] * t) for i in range(3)) + (255,)

# ═══════════════════════════════════════════
# CRYSTAL GROWTH
# ═══════════════════════════════════════════

def crystal_cluster(shape, num_seeds=3, growth_steps=8):
    """Grow crystal-like formations using simplified DLA"""
    h, w = shape
    grid = np.zeros((h, w), dtype=np.int32)
    rng = np.random.RandomState(42)
    
    # Place seeds
    seeds = []
    for _ in range(num_seeds):
        sx = rng.randint(w//4, 3*w//4)
        sy = rng.randint(h//4, 3*h//4)
        seeds.append((sx, sy))
        grid[sy, sx] = 1
    
    # Growth
    directions = [(0,1),(1,0),(0,-1),(-1,0),(1,1),(-1,1),(1,-1),(-1,-1)]
    for step in range(growth_steps):
        # For each occupied cell, possibly grow to adjacent empty cells
        occupied = np.argwhere(grid > 0)
        rng.shuffle(occupied)
        growths_this_step = 0
        for y, x in occupied:
            if growths_this_step >= len(occupied) // 2:
                break
            # Try each direction
            for dx, dy in directions:
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and grid[ny, nx] == 0:
                    if rng.random() < 0.4:
                        grid[ny, nx] = 1
                        growths_this_step += 1
                        break  # Only grow one cell per occupied cell per step
    
    return grid

# ═══════════════════════════════════════════
# STONE/CONCRETE TEXTURE
# ═══════════════════════════════════════════

def stone_texture(shape, base_color, grain_scale=3.0, seed=0):
    """Generate textured stone surface"""
    noise = fbm(shape, octaves=3, scale=grain_scale, seed=seed)
    h, w = shape
    result = np.zeros((h, w, 4), dtype=np.uint8)
    for y in range(h):
        for x in range(w):
            t = noise[y, x]
            if t < 0.33:
                c = darker(base_color, int(30 * (0.33 - t) / 0.33))
            elif t < 0.66:
                c = base_color
            else:
                c = lighter(base_color, int(20 * (t - 0.66) / 0.34))
            result[y, x] = c
    return result

# ═══════════════════════════════════════════
# WOOD TEXTURE
# ═══════════════════════════════════════════

def wood_texture(shape, base_color, ring_scale=4.0, seed=0):
    """Generate wood grain texture using stripes + noise"""
    h, w = shape
    result = np.zeros((h, w, 4), dtype=np.uint8)
    # Vertical grain lines
    noise = value_noise(shape, scale=ring_scale, seed=seed)
    for y in range(h):
        for x in range(w):
            n = noise[y, x]
            # Alternate light/dark bands
            band = int((x + n * 3) / ring_scale) % 3
            if band == 0:
                c = base_color
            elif band == 1:
                c = darker(base_color, 20)
            else:
                c = darker(base_color, 40)
            result[y, x] = c
    return result

print("✅ Pixel art engine loaded")
