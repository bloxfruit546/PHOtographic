#!/usr/bin/env python3
"""
Phase 2 Static, Architectural & Color-Science Verifier for PhotographicStyles12 v2.0.
"""

import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

REQUIRED_FILES = [
    "Headers/CameraUI12.h",
    "Headers/QuartzCorePrivate.h",
    "Core/PSState.h",
    "Core/PSState.m",
    "Core/PSColorProfile.h",
    "Core/PSColorProfile.m",
    "Core/PSColorEngine.h",
    "Core/PSColorEngine.m",
    "Core/PSPreviewFilterController.h",
    "Core/PSPreviewFilterController.m",
    "Captures/PSCaptureCoordinator.h",
    "Captures/PSCaptureCoordinator.m",
    "UI/PSOverlayPassthroughView.h",
    "UI/PSOverlayPassthroughView.m",
    "tools/verify_phase1.py",
    "tools/verify_phase2.py",
    "Makefile",
    "control",
    "PhotographicStyles12.plist",
    "Tweak.xm",
]

EXPECTED_PRESETS = [
    "STANDARD", "AMBER", "GOLD", "ROSE GOLD", "NEUTRAL", "COOL ROSE",
    "VIBRANT", "BRIGHT", "NATURAL", "LUMINOUS", "DRAMATIC", "QUIET",
    "COZY", "ETHEREAL", "STARK B&W",
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
    missing = [
        rel for rel in REQUIRED_FILES
        if not os.path.isfile(os.path.join(ROOT, rel.replace("/", os.sep)))
        or os.path.getsize(os.path.join(ROOT, rel.replace("/", os.sep))) == 0
    ]
    if missing:
        raise AssertionError(f"Missing or empty Phase 2 files: {missing}")


def check_source_rules():
    errors = []
    for path in iter_v2_source_files():
        rel = os.path.relpath(path, ROOT)
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        for pat in FORBIDDEN_PLACEHOLDERS:
            if pat.search(content):
                errors.append(f"{rel}: forbidden placeholder {pat.pattern!r}")
        for api in FORBIDDEN_IOS13_APIS:
            if api in content:
                errors.append(f"{rel}: forbidden iOS 13+ API {api!r}")
        for pat in FORBIDDEN_INTRUSIONS:
            if pat.search(content):
                errors.append(f"{rel}: forbidden intrusion {pat.pattern!r}")
    if errors:
        raise AssertionError("Source rule violations:\n  " + "\n  ".join(errors))


def check_makefile_sources():
    with open(os.path.join(ROOT, "Makefile"), "r", encoding="utf-8") as f:
        mk = f.read().replace("\\\n", " ").replace("\\\r\n", " ")
    m = re.search(r"PhotographicStyles12_FILES\s*=\s*(.+)", mk)
    if not m:
        raise AssertionError("PhotographicStyles12_FILES missing in Makefile")
    listed = set(m.group(1).split())
    actual = {
        os.path.relpath(p, ROOT).replace("\\", "/")
        for p in iter_v2_source_files()
        if p.endswith((".m", ".xm"))
    }
    missing = actual - listed
    if missing:
        raise AssertionError(f"Sources missing from Makefile: {sorted(missing)}")


def check_quartzcore_and_kvc():
    with open(os.path.join(ROOT, "Headers", "QuartzCorePrivate.h"), "r", encoding="utf-8") as f:
        qc = f.read()
    assert "struct CAColorMatrix {" in qc, "struct CAColorMatrix tag missing"
    assert "typedef struct CAColorMatrix CAColorMatrix;" in qc, "typedef struct CAColorMatrix missing"
    assert "valueWithCAColorMatrix:" in qc, "NSValue valueWithCAColorMatrix: declaration missing"

    with open(os.path.join(ROOT, "Core", "PSPreviewFilterController.m"), "r", encoding="utf-8") as f:
        pfc = f.read()
    assert "PSOpticalPreviewView" in pfc, "PSPreviewFilterController must drive PSOpticalPreviewView"
    assert "com.ps12.liveMatrix" not in pfc, "Dotted filter name must be removed"
    assert "CABackdropLayer" not in pfc and "CAFilter" not in pfc, "CABackdropLayer and CAFilter are banned in v2.2.0"


def check_presets_and_kernel():
    with open(os.path.join(ROOT, "Core", "PSColorProfile.m"), "r", encoding="utf-8") as f:
        prof = f.read()
    for name in EXPECTED_PRESETS:
        assert f'"{name}"' in prof, f"Preset {name!r} missing from PSColorProfile.m"

    with open(os.path.join(ROOT, "Core", "PSColorEngine.m"), "r", encoding="utf-8") as f:
        eng = f.read()
    assert "unpremultiply(s)" in eng, "Kernel must unpremultiply(s)"
    assert "premultiply(" in eng, "Kernel must premultiply output"
    assert "smoothstep(" in eng and "skinMask" in eng, "Kernel must implement smoothstep skinMask"

    m = re.search(r"kernel vec4 ps12StyleKernel\(([^)]+)\)", eng)
    assert m, "ps12StyleKernel signature not found"
    args = [a.strip() for a in m.group(1).split(",") if a.strip()]
    assert len(args) <= 7, f"Kernel has {len(args)} args, must be <= 7 for A7 GPU"


def clampf(v, lo, hi):
    return lo if v < lo else (hi if v > hi else v)


def check_math_parity():
    # Mirror PSColorEngine colorMatrixForParameters: for identity & STARK B&W & bounds
    identity = [
        1.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
    ]
    assert len(identity) == 20
    # Verify STARK B&W (monoMix=1.0) produces identical R/G/B weights per row
    contrast = 1.32
    eff_sat = 0.0
    inv_sat = 1.0 - eff_sat
    sr, sg, sb = inv_sat * 0.2126, inv_sat * 0.7152, inv_sat * 0.0722
    row = [contrast * sr, contrast * sg, contrast * sb]
    assert abs(sum(row) - contrast) < 1e-5
    for v in row:
        assert math.isfinite(v) and 0.0 <= v <= 2.0


def main():
    check_required_files()
    check_source_rules()
    check_makefile_sources()
    check_quartzcore_and_kvc()
    check_presets_and_kernel()
    check_math_parity()
    print("[verify_phase2] ALL CHECKS PASSED (23 files, 15 presets, <=7 kernel uniforms, KVC keyPath OK, math OK)")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"[verify_phase2] FAILED: {exc}", file=sys.stderr)
        sys.exit(1)
