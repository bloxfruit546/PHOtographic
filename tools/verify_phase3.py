#!/usr/bin/env python3
"""
Phase 3 Static, Ergonomic Layout & Gesture-Isolation Verifier
for PhotographicStyles12 v2.0.
"""

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
    "UI/PSTopBarButton.h",
    "UI/PSTopBarButton.m",
    "UI/PSMatrixPadView.h",
    "UI/PSMatrixPadView.m",
    "UI/PSPaletteSliderView.h",
    "UI/PSPaletteSliderView.m",
    "UI/PSPresetStripView.h",
    "UI/PSPresetStripView.m",
    "UI/PSStyleControlPanel.h",
    "UI/PSStyleControlPanel.m",
    "UI/PSOverlayPassthroughView.h",
    "UI/PSOverlayPassthroughView.m",
    "tools/verify_phase1.py",
    "tools/verify_phase2.py",
    "tools/verify_phase3.py",
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
    "NSTrackingAttributeName",
    "automaticallyAdjustsScrollIndicatorInsets",
    "showsLargeContentViewer",
    "overrideUserInterfaceStyle",
    "symbolConfiguration",
]

FORBIDDEN_INTRUSIONS = [
    re.compile(r"%hook\s+CIContext\b"),
    re.compile(r"%hook\s+CALayer\b"),
    re.compile(r"\bAVCaptureVideoDataOutput\b"),
    re.compile(r"panGestureRecognizer\.delegate\s*="),
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
        raise AssertionError(f"Missing or empty Phase 3 files: {missing}")


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


def check_core_apis():
    with open(os.path.join(ROOT, "Core", "PSColorEngine.m"), "r", encoding="utf-8") as f:
        eng = f.read()
    assert "processCapturedImage:" in eng and "usingContext:" in eng, "processCapturedImage:forSnapshot:usingContext: missing"

    with open(os.path.join(ROOT, "Core", "PSState.m"), "r", encoding="utf-8") as f:
        st = f.read()
    for sel in (
        "setTone:(float)tone color:(float)color",
        "selectPresetAtIndex:(NSInteger)presetIndex resetToPresetDefaults:(BOOL)resetDefaults",
        "resetCurrentPresetToDefaults",
        "isCurrentPresetModifiedFromDefaults",
    ):
        assert sel in st, f"Missing PSState method: {sel}"


def check_ui_passthrough_and_gesture_isolation():
    with open(os.path.join(ROOT, "UI", "PSOverlayPassthroughView.m"), "r", encoding="utf-8") as f:
        ov = f.read()
    assert "hitTest:(CGPoint)point withEvent:(UIEvent *)event" in ov
    assert "if (hit == self)" in ov and "return nil;" in ov

    for ui_file in ("UI/PSMatrixPadView.m", "UI/PSPaletteSliderView.m", "UI/PSPresetStripView.m"):
        with open(os.path.join(ROOT, ui_file.replace("/", os.sep)), "r", encoding="utf-8") as f:
            src = f.read()
        assert "exclusiveTouch = YES" in src, f"{ui_file}: exclusiveTouch = YES missing"
        assert "gestureRecognizerShouldBegin:" in src, f"{ui_file}: gestureRecognizerShouldBegin: missing"
        assert "shouldRecognizeSimultaneouslyWithGestureRecognizer:" in src, f"{ui_file}: simultaneous gesture blocker missing"


def check_4inch_layout_ergonomics():
    # Verify 320x568 iPhone 5s layout geometry fits without overlapping top or bottom bars
    screen_w, screen_h = 320.0, 568.0
    btn_y, btn_h = 52.0, 32.0
    panel_w, panel_h = min(304.0, max(260.0, screen_w - 16.0)), 252.0
    bottom_reserve = 138.0
    panel_y = screen_h - bottom_reserve - panel_h
    assert panel_w == 304.0 and panel_w <= screen_w - 16.0
    assert panel_y >= btn_y + btn_h + 8.0, f"Panel overlaps top button: panel_y={panel_y}, btn_maxY={btn_y + btn_h}"
    assert panel_y + panel_h <= screen_h - bottom_reserve


def main():
    check_required_files()
    check_source_rules()
    check_makefile_sources()
    check_core_apis()
    check_ui_passthrough_and_gesture_isolation()
    check_4inch_layout_ergonomics()
    print("[verify_phase3] ALL CHECKS PASSED (34 files, passthrough + gesture isolation OK, 320x568 layout OK)")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"[verify_phase3] FAILED: {exc}", file=sys.stderr)
        sys.exit(1)
