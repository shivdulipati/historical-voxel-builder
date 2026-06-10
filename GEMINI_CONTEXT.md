Act as my Game Producer and Architect. We are building a Godot mobile game. Read the project context below to understand our current state and our AI workflow.
# GEMINI_CONTEXT.md

# GEMINI_CONTEXT.md

## Project Overview
* **Game:** Mobile 3D historical voxel-builder (digital LEGO style).
* **Engine:** Godot 4 (GDScript).
* **Target:** iOS (portrait orientation) via TestFlight.

## Sprint History & Current State
* **Sprint 1 (Solo Game Dev Prototyping):** Established basic draggable blocks and raycast plane intersections.
* **Sprint 2 (3D Stacking & Physics):** Locked the game board to a mathematically absolute 3x3 layout centered at Vector3(0, 0, 0). Patched snapping math to use strict round() whole-integer calculations. Replaced solid target meshes with custom transparent wireframe shaders (grid_box.gdshader) for both the Holographic Grid and the Ghost Block.
* **Current Mechanics:** Blocks freeze upon placement. Movement is touch-based raycast. Y-axis stacking uses downward PhysicsRayQueryParameters3D.

## AI Collaboration Workflow & Rules
1. **The Division of Labor (Cursor vs. Gemini):** Cursor handles line-by-line coding (scripts, shaders, JSON). Gemini handles architectural decisions, game design logic, and Godot Editor UI instructions. *Exception:* Completely ignore Cursor if it suggests modifying the Scene Tree or adding nodes manually; wait for Gemini's Editor steps.
2. **Cursor Prompt Formatting:** Gemini must wrap all prompts intended for Cursor inside standard markdown code blocks for easy one-click copying.
3. **The "No Eyeballing" Rule (Pure Math Integration):** Visual estimation is prohibited. All board layouts, node positions, and grid bounds must be rooted in pure mathematics (e.g., centering the world exactly at `Vector3(0, 0, 0)`, odd-numbered dimensions, and using `round()`).
4. **The Code-First Discovery Rule:** Provide Gemini with exact script contents or Scene Tree screenshots before asking for structural fixes. Force Cursor to read specific files before asking it to write a solution.
5. **Context Maintenance & Pruning:** Gemini will automatically generate an updated `GEMINI_CONTEXT.md` block when a new workflow rule is established. Type "Context Check" at any time for a full review.
6. **Brevity is Gold:** Keep all conversations and responses short, direct, and to the point. No unnecessary conversational filler.

## Today's Objective
* **Dynamic Level Generation Architecture:** Implement pre-populated library levels via `levels.json` that dynamically scale the holographic grid and math boundaries at runtime.