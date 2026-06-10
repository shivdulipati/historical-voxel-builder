#!/usr/bin/env python3
"""
level_compiler.py
Generates 50 escalating levels for levels.json.
Run from the project root:  python3 level_compiler.py

Change or remove the seed below to get a different random set of levels.
"""

import json
import os
import random
import shutil

random.seed(42)  # fixed seed → identical levels on every run

ALL_COLORS = ["Red", "Blue", "Green", "Yellow", "Orange", "White"]


# ---------------------------------------------------------------------------
# Generators — return {(x, y, z): color_string}
# ---------------------------------------------------------------------------

def generate_stack(height: int, colors: list) -> dict:
    """
    Vertical tower at x=0, z=0.
    Colors cycle through the list bottom-to-top.
    """
    return {(0, y, 0): colors[y % len(colors)] for y in range(height)}


def generate_pyramid(base_size: int, colors: list) -> dict:
    """
    Stepped pyramid centered at origin.
    At layer h: extent = (base_size - 1) // 2 - h
    Each layer receives the next color in the list.
    base_size must be a positive odd integer.
    """
    if base_size % 2 == 0 or base_size < 1:
        raise ValueError(f"base_size must be a positive odd integer, got {base_size}")

    blocks = {}
    num_layers = (base_size + 1) // 2
    for h in range(num_layers):
        extent = (base_size - 1) // 2 - h
        color = colors[h % len(colors)]
        for x in range(-extent, extent + 1):
            for z in range(-extent, extent + 1):
                blocks[(x, h, z)] = color
    return blocks


def generate_symmetric_cluster(base_size: int, height: int, colors: list) -> dict:
    """
    Checkerboard arrangement of vertical pillars centered at origin.
    Only positions where (x + z) % 2 == 0 receive a pillar.
    Each y-layer receives the next color in the list.
    base_size must be a positive odd integer.
    """
    if base_size % 2 == 0 or base_size < 1:
        raise ValueError(f"base_size must be a positive odd integer, got {base_size}")

    half = (base_size - 1) // 2
    blocks = {}
    for y in range(height):
        color = colors[y % len(colors)]
        for x in range(-half, half + 1):
            for z in range(-half, half + 1):
                if (x + z) % 2 == 0:
                    blocks[(x, y, z)] = color
    return blocks


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def calc_dimensions(blocks: dict, grid_xz: int) -> dict:
    """
    X and Z are fixed by the difficulty tier (always odd integers).
    Y is derived from the tallest occupied block + 1.
    """
    if not blocks:
        return {"x": grid_xz, "y": 1, "z": grid_xz}
    max_y = max(p[1] for p in blocks)
    return {"x": grid_xz, "y": max_y + 1, "z": grid_xz}


def to_string_keys(blocks: dict) -> dict:
    """Convert {(x, y, z): color} → {"x,y,z": color} for JSON serialisation."""
    return {f"{x},{y},{z}": color for (x, y, z), color in blocks.items()}


def build_level(level_id: int, blocks: dict, allowed_blocks: list, grid_xz: int) -> dict:
    return {
        "level_id":       level_id,
        "dimensions":     calc_dimensions(blocks, grid_xz),
        "allowed_blocks": allowed_blocks,
        "target_puzzle":  to_string_keys(blocks),
    }


def random_colors(n: int) -> list:
    """Return a random subset of n colors (minimum 2) from ALL_COLORS."""
    return random.sample(ALL_COLORS, max(2, min(n, len(ALL_COLORS))))


# ---------------------------------------------------------------------------
# Level generation loop
# ---------------------------------------------------------------------------

GENERATORS = [generate_stack, generate_pyramid, generate_symmetric_cluster]


def make_level(level_id: int) -> dict:
    # --- Difficulty tier ---
    if level_id <= 10:
        grid_xz  = 3
        height   = random.randint(2, 4)
        n_colors = random.randint(2, 3)
    elif level_id <= 30:
        grid_xz  = 5
        height   = random.randint(3, 6)
        n_colors = random.randint(2, 4)
    else:
        grid_xz  = 7
        height   = random.randint(4, 8)
        n_colors = random.randint(3, 5)

    colors = random_colors(n_colors)
    gen    = random.choice(GENERATORS)

    # --- Dispatch ---
    if gen is generate_stack:
        blocks = generate_stack(height=height, colors=colors)
    elif gen is generate_pyramid:
        blocks = generate_pyramid(base_size=grid_xz, colors=colors)
    else:
        blocks = generate_symmetric_cluster(base_size=grid_xz, height=height, colors=colors)

    return build_level(level_id, blocks, allowed_blocks=colors, grid_xz=grid_xz)


LEVELS = [make_level(i) for i in range(1, 51)]


# ---------------------------------------------------------------------------
# Export — write root copy and sync into the Godot project
# ---------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_JSON  = os.path.join(SCRIPT_DIR, "levels.json")
GODOT_JSON = os.path.join(SCRIPT_DIR, "new-game-project", "levels.json")

payload = json.dumps(LEVELS, indent=2)

with open(ROOT_JSON, "w") as fh:
    fh.write(payload + "\n")

shutil.copy(ROOT_JSON, GODOT_JSON)

print(f"Written {len(LEVELS)} level(s) → {ROOT_JSON}")
print(f"Synced                        → {GODOT_JSON}")
