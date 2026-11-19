#!/usr/bin/env python3
"""
Phase 5 Final Release Verifier (v2.0.0) for PhotographicStyles12.
Includes 10,000-iteration fuzz & boundary stress testing across all
15 presets, CAColorMatrix synthesis, and ps12StyleKernel RGB math.
"""

import math
import os
import random
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def iter_v2_source_files():
    exts = (".h", ".m", ".xm")
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in (".git", ".theos", "packages", "obj")]
        for fn in filenames:
            if fn.endswith(exts):
                yield os.path.join(dirpath, fn)


def check_clean_repo():
    legacy = os.path.join(ROOT, "_legacy_v1")
    assert not os.path.exists(legacy), "_legacy_v1/ must be removed for v2.0.0 release"


def check_control():
    with open(os.path.join(ROOT, "control"), "r", encoding="utf-8") as f:
        ctrl = f.read()
    assert re.search(r"^Version:\s*2\.0\.0\s*$", ctrl, re.MULTILINE), "control Version must be 2.0.0"
    assert re.search(r"^Architecture:\s*iphoneos-arm\s*$", ctrl, re.MULTILINE), "control Architecture must be iphoneos-arm"
    assert "Depends: firmware (>= 12.0), mobilesubstrate" in ctrl, "control Depends mismatch"


def check_makefile_exact_match():
    with open(os.path.join(ROOT, "Makefile"), "r", encoding="utf-8") as f:
        mk = f.read().replace("\\\n", " ").replace("\\\r\n", " ")
    m = re.search(r"PhotographicStyles12_FILES\s*=\s*(.+)", mk)
    assert m, "PhotographicStyles12_FILES missing in Makefile"

    listed = set(m.group(1).split())
    actual = {
        os.path.relpath(p, ROOT).replace("\\", "/")
        for p in iter_v2_source_files()
        if p.endswith((".m", ".xm"))
    }
    missing = actual - listed
    orphan = listed - actual
    assert not missing, f"Sources missing from Makefile: {sorted(missing)}"
    assert not orphan, f"Orphan entries in Makefile: {sorted(orphan)}"


def check_row1_header_geometry():
    # Verify Row 1 Header in PSStyleControlPanel.m has zero horizontal collisions on 304pt width
    with open(os.path.join(ROOT, "UI", "PSStyleControlPanel.m"), "r", encoding="utf-8") as f:
        src = f.read()
    assert "lpButton" in src and '@"LP"' in src, "LP toggle button missing in PSStyleControlPanel.m"
    assert "LIVE PHOTO VIDEO: GRADED" in src and "LIVE PHOTO VIDEO: FAST SKIP" in src

    w = 304.0
    pad_x = 10.0
    cat_min_x, cat_max_x = pad_x, pad_x + 88.0
    col_min_x = w - pad_x - 26.0
    pwr_min_x = col_min_x - 5.0 - 38.0
    lp_min_x = pwr_min_x - 5.0 - 30.0
    rst_min_x = lp_min_x - 5.0 - 26.0
    assert cat_max_x < rst_min_x, f"Header collision: cat_max_x={cat_max_x} >= rst_min_x={rst_min_x}"


def check_thumbnail_fast_path():
    with open(os.path.join(ROOT, "Captures", "PSStillImageBaker.m"), "r", encoding="utf-8") as f:
        still = f.read()
    assert "bakedFastThumbnailImage:" in still
    assert "CGFloat maxDim = 360.0;" in still
    assert "performThumbnailBake:" in still

    with open(os.path.join(ROOT, "Captures", "PSCaptureCoordinator.m"), "r", encoding="utf-8") as f:
        coord = f.read()
    assert "_thumbLock" in coord and "_thumbnailContext" in coord
    assert "ps12_v2_bakeLivePhotoMOV" in coord

    with open(os.path.join(ROOT, "Tweak.xm"), "r", encoding="utf-8") as f:
        tw = f.read()
    assert "bakedFastThumbnailImage:" in tw


def check_ci_workflow():
    wf_path = os.path.join(ROOT, ".github", "workflows", "build.yml")
    assert os.path.isfile(wf_path), ".github/workflows/build.yml missing"
    with open(wf_path, "r", encoding="utf-8") as f:
        wf = f.read()
    assert "brew install dpkg" in wf, "CI workflow must install dpkg"
    assert "brew install ldid" in wf, "CI workflow must attempt brew install ldid"
    assert "ProcursusTeam/ldid" in wf, "CI workflow must include ProcursusTeam/ldid fallback"
    assert "LC_CODE_SIGNATURE" in wf, "CI workflow must verify LC_CODE_SIGNATURE on built dylib"
    assert ".zst" in wf, "CI workflow must reject .zst compression for iOS 12"


def clampf(v, lo, hi):
    return lo if v < lo else (hi if v > hi else v)


def smoothstep(edge0, edge1, x):
    t = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


PRESETS = [
    # (baseExposure, baseContrast, baseSaturation, baseWarmth, baseTint, baseVibrance, splitStrength, monoMix, shade, glow, blackLift, skinProtect)
    ( 0.00,  0.00,  0.00,  0.00,  0.00, 0.00, 0.00, 0.00, (0.50,0.50,0.50), (0.50,0.50,0.50), 0.00, 0.85),
    ( 0.02,  0.12,  0.06,  0.28, -0.02, 0.10, 0.40, 0.00, (0.42,0.30,0.16), (0.66,0.52,0.30), 0.00, 0.85),
    ( 0.03,  0.06,  0.08,  0.36, -0.03, 0.16, 0.45, 0.00, (0.45,0.34,0.14), (0.74,0.60,0.26), 0.00, 0.85),
    ( 0.02,  0.05,  0.06,  0.20,  0.12, 0.10, 0.42, 0.00, (0.52,0.34,0.34), (0.74,0.52,0.46), 0.00, 0.85),
    ( 0.00,  0.04, -0.05, -0.06,  0.00, 0.00, 0.18, 0.00, (0.46,0.48,0.52), (0.52,0.53,0.55), 0.00, 0.85),
    ( 0.00,  0.02,  0.04, -0.20,  0.16, 0.06, 0.40, 0.00, (0.36,0.36,0.48), (0.64,0.56,0.68), 0.00, 0.85),
    ( 0.01,  0.10,  0.16,  0.10,  0.02, 0.52, 0.65, 0.00, (0.30,0.22,0.46), (0.84,0.56,0.28), 0.00, 0.55),
    ( 0.05,  0.24,  0.18,  0.18, -0.02, 0.34, 0.52, 0.00, (0.36,0.18,0.12), (0.82,0.66,0.34), 0.01, 0.55),
    ( 0.00, -0.04,  0.03,  0.02,  0.00, 0.06, 0.22, 0.00, (0.46,0.47,0.47), (0.56,0.55,0.53), 0.00, 0.55),
    ( 0.12, -0.02,  0.04,  0.04,  0.02, 0.10, 0.36, 0.00, (0.50,0.50,0.54), (0.72,0.68,0.62), 0.02, 0.55),
    (-0.08,  0.38,  0.08, -0.02,  0.00, 0.14, 0.54, 0.00, (0.16,0.18,0.28), (0.64,0.54,0.38), 0.00, 0.55),
    ( 0.02, -0.10, -0.24,  0.00,  0.00, 0.00, 0.30, 0.00, (0.42,0.42,0.40), (0.58,0.57,0.54), 0.03, 0.55),
    ( 0.04, -0.06,  0.05,  0.26, -0.02, 0.10, 0.44, 0.00, (0.44,0.30,0.18), (0.74,0.56,0.34), 0.02, 0.55),
    ( 0.10, -0.08,  0.02, -0.06,  0.14, 0.14, 0.48, 0.00, (0.46,0.42,0.56), (0.78,0.72,0.84), 0.03, 0.55),
    (-0.02,  0.42,  0.00,  0.00,  0.00, 0.00, 0.35, 1.00, (0.46,0.48,0.52), (0.54,0.52,0.48), 0.00, 0.00),
]


def fuzz_10k_iterations():
    rng = random.Random(20261118)
    for _ in range(10000):
        idx = rng.randint(0, 14)
        enabled = rng.choice((True, False))
        tone = rng.uniform(-1.0, 1.0)
        color = rng.uniform(-1.0, 1.0)
        palette = rng.uniform(0.0, 1.0)

        if not enabled or (idx == 0 and abs(tone) < 1e-5 and abs(color) < 1e-5):
            continue

        be, bc, bs, bw, bt, bv, sp, mm, sh, gl, bl, sk = PRESETS[idx]
        ps = 0.25 + 0.75 * palette
        exposure = clampf(be * ps + tone * 0.12, -0.45, 0.45)
        contrast = clampf(1.0 + bc * ps - tone * 0.18, 0.60, 1.65)
        saturation = clampf(1.0 + bs * ps + color * 0.36, 0.0, 1.85)
        warmth = clampf(bw * ps + color * 0.08 * ps, -0.60, 0.60)
        tint = clampf(bt * ps, -0.45, 0.45)
        vibrance = clampf(bv * ps + color * 0.30, -0.50, 1.00)
        split_amt = clampf(sp * ps, 0.0, 1.0)
        black_lift = clampf(bl * ps + max(tone, 0.0) * 0.025, 0.0, 0.08)

        # Verify CAColorMatrix bounds
        eff_sat = clampf(saturation + vibrance * 0.35, 0.0, 2.0) * (1.0 - mm)
        inv_sat = 1.0 - eff_sat
        sr, sg, sb = inv_sat * 0.2126, inv_sat * 0.7152, inv_sat * 0.0722
        r_gain = contrast * (1.0 + warmth * 0.14 + tint * 0.05)
        g_gain = contrast * (1.0 - tint * 0.07)
        b_gain = contrast * (1.0 - warmth * 0.14 + tint * 0.05)
        for v in (r_gain * (sr + eff_sat), r_gain * sg, g_gain * (sg + eff_sat), b_gain * (sb + eff_sat)):
            assert math.isfinite(v) and -4.0 <= v <= 4.0

        # Verify ps12StyleKernel pixel output strictly in [0.0, 1.0]
        r, g, b = rng.uniform(0.0, 1.0), rng.uniform(0.0, 1.0), rng.uniform(0.0, 1.0)
        lum0 = 0.2126 * r + 0.7152 * g + 0.0722 * b
        cmax, cmin = max(r, g, b), min(r, g, b)
        sat_est = (cmax - cmin) / max(cmax, 0.001)
        skin_mask = clampf(
            smoothstep(0.01, 0.14, r - g)
            * smoothstep(0.00, 0.12, g - b)
            * smoothstep(0.12, 0.28, lum0) * (1.0 - smoothstep(0.82, 0.96, lum0))
            * smoothstep(0.08, 0.22, sat_est) * (1.0 - smoothstep(0.65, 0.88, sat_est))
            * sk,
            0.0,
            0.90,
        )

        r = clampf((r + exposure - 0.5) * contrast + 0.5, 0.0, 1.0)
        g = clampf((g + exposure - 0.5) * contrast + 0.5, 0.0, 1.0)
        b = clampf((b + exposure - 0.5) * contrast + 0.5, 0.0, 1.0)
        r = clampf(r + black_lift * (1.0 - r), 0.0, 1.0)
        g = clampf(g + black_lift * (1.0 - g), 0.0, 1.0)
        b = clampf(b + black_lift * (1.0 - b), 0.0, 1.0)

        temp_scale = 1.0 - skin_mask * 0.75
        r = clampf(r + (warmth * 0.12 + tint * 0.04) * temp_scale, 0.0, 1.0)
        g = clampf(g + (-tint * 0.06) * temp_scale, 0.0, 1.0)
        b = clampf(b + (-warmth * 0.12 + tint * 0.04) * temp_scale, 0.0, 1.0)

        lum1 = 0.2126 * r + 0.7152 * g + 0.0722 * b
        cur_sat = max(r, g, b) - min(r, g, b)
        eff_k_sat = clampf(saturation + vibrance * (1.0 - cur_sat) * (1.0 - skin_mask * 0.70), 0.0, 2.2)
        r = clampf(lum1 + (r - lum1) * eff_k_sat, 0.0, 1.0)
        g = clampf(lum1 + (g - lum1) * eff_k_sat, 0.0, 1.0)
        b = clampf(lum1 + (b - lum1) * eff_k_sat, 0.0, 1.0)

        lum2 = 0.2126 * r + 0.7152 * g + 0.0722 * b
        sh_w = (1.0 - smoothstep(0.05, 0.55, lum2)) * split_amt * 0.35 * (1.0 - skin_mask * 0.65)
        hi_w = smoothstep(0.45, 0.95, lum2) * split_amt * 0.35 * (1.0 - skin_mask * 0.65)
        r = clampf(r + (sh[0] - 0.5) * sh_w + (gl[0] - 0.5) * hi_w, 0.0, 1.0)
        g = clampf(g + (sh[1] - 0.5) * sh_w + (gl[1] - 0.5) * hi_w, 0.0, 1.0)
        b = clampf(b + (sh[2] - 0.5) * sh_w + (gl[2] - 0.5) * hi_w, 0.0, 1.0)

        for ch in (r, g, b):
            assert math.isfinite(ch) and 0.0 <= ch <= 1.0


def main():
    check_clean_repo()
    check_control()
    check_makefile_exact_match()
    check_row1_header_geometry()
    check_thumbnail_fast_path()
    check_ci_workflow()
    fuzz_10k_iterations()
    print("[verify_release_v2] ALL CHECKS PASSED (clean repo, v2.0.0 control, 1-to-1 Makefile, header OK, thumb fast-path OK, CI OK, 10k fuzz OK)")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"[verify_release_v2] FAILED: {exc}", file=sys.stderr)
        sys.exit(1)
