#!/usr/bin/env python3
"""
PulseFit AI - Recruiter Showcase 15-Second Demo Animation Generator
===================================================================
Composes high-resolution live application captures from https://joelaah.github.io/fitness_app/
into an optimized, high-impact animated GIF/WebP for the GitHub repository README.
"""

import os
import sys

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

from PIL import Image, ImageDraw, ImageFont

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_GIF = os.path.join(BASE_DIR, "assets", "demo.gif")
OUTPUT_WEBP = os.path.join(BASE_DIR, "assets", "demo.webp")

TARGET_WIDTH = 960
TARGET_HEIGHT = 600

SCENES = [
    {
        "file": os.path.join(BASE_DIR, "screen_1_home.png"),
        "title": "HOME DASHBOARD & LOCAL-FIRST TRACKING",
        "badge": "📱 Offline-First Sync & Activity Streaks",
        "duration_sec": 3.5,
    },
    {
        "file": os.path.join(BASE_DIR, "screen_4_exercises.png"),
        "title": "1,324+ EXERCISE CATALOG & BIOMECHANICS ENGINE",
        "badge": "🏋️ Full Library with Equipment & Muscle Filters",
        "duration_sec": 3.5,
    },
    {
        "file": os.path.join(BASE_DIR, "screen_2_routines.png"),
        "title": "PERIODIZATION SPLITS & CUSTOM ROUTINE BUILDER",
        "badge": "⚡ Evidence-Based Splits (PPL, Upper/Lower, PHUL)",
        "duration_sec": 3.5,
    },
    {
        "file": os.path.join(BASE_DIR, "screen_3_aicoach.png"),
        "title": "TWO-STAGE RAG FITNESS COPILOT (QDRANT + COHERE + GEMINI)",
        "badge": "🤖 Exercise Science AI Coach & Progressive Overload",
        "duration_sec": 4.5,
    },
]


def load_and_scale_image(path: str) -> Image.Image:
    """Loads and resizes an app screenshot to the target viewport."""
    if not os.path.exists(path):
        raise FileNotFoundError(f"Missing screenshot: {path}")
    img = Image.open(path).convert("RGB")
    return img.resize((TARGET_WIDTH, TARGET_HEIGHT), Image.Resampling.LANCZOS)


def add_recruiter_overlay(img: Image.Image, scene_info: dict, progress_ratio: float) -> Image.Image:
    """Renders a sleek modern dark glassmorphism overlay bar with badge and live indicator."""
    canvas = img.copy()
    draw = ImageDraw.Draw(canvas, "RGBA")

    # 1. Top Header Glass Bar
    draw.rectangle([(0, 0), (TARGET_WIDTH, 44)], fill=(10, 15, 29, 230))
    # PulseFit AI Brand + Live status
    draw.ellipse([(16, 17), (26, 27)], fill=(0, 230, 118, 255))  # Green glowing pulse
    draw.text((34, 13), "PulseFit AI", fill=(255, 255, 255, 255))
    draw.text((120, 14), "· Live Web Ecosystem", fill=(148, 163, 184, 255))

    # Right side: Architecture Pill
    draw.text((TARGET_WIDTH - 280, 14), "Flutter Web · FastAPI · Supabase", fill=(56, 189, 248, 255))

    # 2. Bottom Floating Feature Callout Card
    badge_text = scene_info["badge"]
    badge_w = 460
    badge_h = 36
    badge_x = (TARGET_WIDTH - badge_w) // 2
    badge_y = TARGET_HEIGHT - 64

    # Rounded pill container
    draw.rounded_rectangle(
        [(badge_x, badge_y), (badge_x + badge_w, badge_y + badge_h)],
        radius=18,
        fill=(15, 23, 42, 235),
        outline=(0, 230, 118, 180),
        width=1,
    )
    # Centered text in pill
    draw.text((badge_x + 22, badge_y + 9), badge_text, fill=(241, 245, 249, 255))

    # 3. Bottom Timeline Progress Bar
    bar_h = 4
    draw.rectangle([(0, TARGET_HEIGHT - bar_h), (TARGET_WIDTH, TARGET_HEIGHT)], fill=(30, 41, 59, 255))
    filled_w = int(TARGET_WIDTH * progress_ratio)
    if filled_w > 0:
        draw.rectangle([(0, TARGET_HEIGHT - bar_h), (filled_w, TARGET_HEIGHT)], fill=(0, 230, 118, 255))

    return canvas


def main():
    print("🎬 Generating 15-second recruiter showcase animation...")
    fps = 8  # 8 frames per second provides fluid motion while maintaining small GIF size
    frames = []

    total_duration = sum(s["duration_sec"] for s in SCENES)
    accumulated_time = 0.0

    raw_images = [load_and_scale_image(s["file"]) for s in SCENES]

    for idx, scene in enumerate(SCENES):
        scene_dur = scene["duration_sec"]
        num_frames = int(scene_dur * fps)
        current_img = raw_images[idx]
        next_img = raw_images[(idx + 1) % len(SCENES)]

        transition_frames = 4  # 0.5s transition at the end of scene

        for f in range(num_frames):
            frame_time = accumulated_time + (f / fps)
            progress = min(1.0, frame_time / total_duration)

            # Check if in transition to next scene
            if f >= (num_frames - transition_frames):
                alpha = (f - (num_frames - transition_frames)) / transition_frames
                blended = Image.blend(current_img, next_img, alpha)
                rendered = add_recruiter_overlay(blended, scene, progress)
            else:
                rendered = add_recruiter_overlay(current_img, scene, progress)

            # Convert to palette mode (adaptive 128 colors for clean GIF compression)
            frames.append(rendered.convert("P", palette=Image.Palette.ADAPTIVE, colors=128))

        accumulated_time += scene_dur

    os.makedirs(os.path.dirname(OUTPUT_GIF), exist_ok=True)

    print(f"💾 Saving {len(frames)} frames to {OUTPUT_GIF}...")
    frame_duration_ms = int(1000 / fps)
    frames[0].save(
        OUTPUT_GIF,
        save_all=True,
        append_images=frames[1:],
        duration=frame_duration_ms,
        loop=0,
        optimize=True,
    )
    gif_size_mb = os.path.getsize(OUTPUT_GIF) / (1024 * 1024)
    print(f"✅ Generated {OUTPUT_GIF} ({gif_size_mb:.2f} MB)")

    # Also save as WebP animation (higher quality, smaller footprint)
    print(f"💾 Saving WebP animation to {OUTPUT_WEBP}...")
    rgb_frames = [f.convert("RGB") for f in frames]
    rgb_frames[0].save(
        OUTPUT_WEBP,
        save_all=True,
        append_images=rgb_frames[1:],
        duration=frame_duration_ms,
        loop=0,
        quality=80,
    )
    webp_size_mb = os.path.getsize(OUTPUT_WEBP) / (1024 * 1024)
    print(f"✅ Generated {OUTPUT_WEBP} ({webp_size_mb:.2f} MB)")


if __name__ == "__main__":
    main()
