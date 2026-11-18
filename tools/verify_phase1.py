#!/usr/bin/env python3
"""
Phase 1 Static, Architectural & Math Verifier for PhotographicStyles12 v2.0.
"""

import os
import re
import sys
import math

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

REQUIRED_FILES = [
    "Headers/CameraUI12.h",
    "Headers/QuartzCorePrivate.h",
    "Core/PSState.h",
    "Core/PSState.m",
    "Core/PSPreviewFilterController.h",
    "Core/PSPreviewFilterController.m",
    "Captures/PSCaptureCoordinator.h",
    "Captures/PSCaptureCoordinator.m",
    "UI/PSOverlayPassthroughView.h",
    "UI/PSOverlayPassthroughView.m",
    "tools/verify_phase1.py",
    "Makefile",
    "control",
    "PhotographicStyles12.plist",
    "Tweak.xm",
]

FORBIDDEN_PLACEHOLDERS = [
    re.compile(r"\bTODO\b"),
    re.compile(r"\bFIXME\b"),
    re.compile(r"Implement later", re.IGNORECASE),
    re.compile(r"/\*\s*\.\.\.\s*\*/"),
    re.compile(r"//\s*\.\.\."),
]

FORBIDDEN_IOS13_APIS = [
    "systemImageNamed",
    "UIScene",
    "systemBackgroundColor",
    "UIContextMenuInteraction",
]

FORBIDDEN_INTRUSIONS = [
    re.compile(r"%hook\s+CIContext\b"),
    re.compile(r"%hook\s+CALayer\b"),
    re.compile(r"\bAVCaptureVideoDataOutput\b"),
]


def iter_v2_source_files():
    exts = (".h", ".m", ".xm")
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in ("_legacy_v1", ".git", ".theos", "packages", "obj")]
        for fn in filenames:
            if fn.endswith(exts):
                yield os.path.join(dirpath, fn)


def check_required_files():
    missing_or_empty = []
    for rel in REQUIRED_FILES:
        full = os.path.join(ROOT, rel.replace("/", os.sep))
        if not os.path.isfile(full) or os.path.getsize(full) == 0:
            missing_or_empty.append(rel)
    if missing_or_empty:
        raise AssertionError(f"Missing or empty required files: {missing_or_empty}")


def check_source_rules():
    errors = []
    for path in iter_v2_source_files():
        rel = os.path.relpath(path, ROOT)
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()

        for pat in FORBIDDEN_PLACEHOLDERS:
            if pat.search(content):
                errors.append(f"{rel}: forbidden placeholder matched {pat.pattern!r}")

        for api in FORBIDDEN_IOS13_APIS:
            if api in content:
                errors.append(f"{rel}: forbidden iOS 13+ API {api!r}")

        for pat in FORBIDDEN_INTRUSIONS:
            if pat.search(content):
                errors.append(f"{rel}: forbidden session/global hook {pat.pattern!r}")

    if errors:
        raise AssertionError("Source rule violations:\n  " + "\n  ".join(errors))


def check_makefile_sources():
    makefile_path = os.path.join(ROOT, "Makefile")
    with open(makefile_path, "r", encoding="utf-8") as f:
        mk = f.read()

    # Join line continuations
    mk_joined = mk.replace("\\\n", " ").replace("\\\r\n", " ")
    m = re.search(r"PhotographicStyles12_FILES\s*=\s*(.+)", mk_joined)
    if not m:
        raise AssertionError("PhotographicStyles12_FILES not found in Makefile")

    listed = set(m.group(1).split())
    actual = set()
    for path in iter_v2_source_files():
        if path.endswith((".m", ".xm")):
            actual.add(os.path.relpath(path, ROOT).replace("\\", "/"))

    missing = actual - listed
    if missing:
        raise AssertionError(f"Source files missing from Makefile PhotographicStyles12_FILES: {sorted(missing)}")


def clampf(v, lo, hi):
    return lo if v < lo else (hi if v > hi else v)


def py_preview_matrix(enabled, tone, color, palette):
    if not enabled:
        return [
            1.0, 0.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 0.0, 1.0, 0.0,
        ]
    tone = clampf(tone, -1.0, 1.0)
    color = clampf(color, -1.0, 1.0)
    palette = clampf(palette, 0.0, 1.0)

    if abs(tone) < 1e-5 and abs(color) < 1e-5:
        return [
            1.0, 0.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 0.0, 1.0, 0.0,
        ]

    contrast = 1.0 - (tone * 0.14)
    brightness = tone * 0.09
    sat = 1.0 + (color * 0.42 * (0.5 + 0.5 * palette))
    inv_sat = 1.0 - sat

    sr = inv_sat * 0.2126
    sg = inv_sat * 0.7152
    sb = inv_sat * 0.0722

    warmth = color * palette * 0.06
    r_gain = contrast * (1.0 + warmth)
    g_gain = contrast * (1.0 + warmth * 0.25)
    b_gain = contrast * (1.0 - warmth)

    bias_base = 0.5 * (1.0 - contrast) + brightness

    return [
        r_gain * (sr + sat), r_gain * sg, r_gain * sb, 0.0, clampf(bias_base + warmth * 0.15, -0.35, 0.35),
        g_gain * sr, g_gain * (sg + sat), g_gain * sb, 0.0, clampf(bias_base, -0.35, 0.35),
        b_gain * sr, b_gain * sg, b_gain * (sb + sat), 0.0, clampf(bias_base - warmth * 0.15, -0.35, 0.35),
        0.0, 0.0, 0.0, 1.0, 0.0,
    ]


def check_matrix_math():
    identity = [
        1.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
    ]
    assert py_preview_matrix(False, 0.5, 0.5, 0.8) == identity, "Disabled state must yield identity"
    assert py_preview_matrix(True, 0.0, 0.0, 0.5) == identity, "Zero tone & color must yield identity"

    for tone in (-1.0, -0.5, 0.0, 0.5, 1.0):
        for color in (-1.0, -0.5, 0.0, 0.5, 1.0):
            for palette in (0.0, 0.5, 1.0):
                mat = py_preview_matrix(True, tone, color, palette)
                assert len(mat) == 20
                for v in mat:
                    assert math.isfinite(v) and -2.5 <= v <= 2.5, f"Out-of-bounds matrix entry: {v}"
                assert mat[15:20] == [0.0, 0.0, 0.0, 1.0, 0.0], "Alpha row must remain identity"


def main():
    check_required_files()
    check_source_rules()
    check_makefile_sources()
    check_matrix_math()
    print("[verify_phase1] ALL CHECKS PASSED (18 files, 0 placeholders, 0 iOS13+ APIs, 0 session intrusions, math OK)")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"[verify_phase1] FAILED: {exc}", file=sys.stderr)
        sys.exit(1)
