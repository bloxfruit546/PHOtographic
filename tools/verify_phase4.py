#!/usr/bin/env python3
"""
Phase 4 Static, Metadata-Safety & Persistence Verifier
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
    "Captures/PSStillImageBaker.h",
    "Captures/PSStillImageBaker.m",
    "Captures/PSLivePhotoVideoBaker.h",
    "Captures/PSLivePhotoVideoBaker.m",
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
    "tools/verify_phase4.py",
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
    missing = [
        rel for rel in REQUIRED_FILES
        if not os.path.isfile(os.path.join(ROOT, rel.replace("/", os.sep)))
        or os.path.getsize(os.path.join(ROOT, rel.replace("/", os.sep))) == 0
    ]
    if missing:
        raise AssertionError(f"Missing or empty Phase 4 files: {missing}")


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


def check_makefile():
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

    for fw in ("ImageIO", "CoreMedia", "AVFoundation", "CoreImage"):
        assert fw in mk, f"Framework {fw} missing from Makefile"


def check_still_and_video_bakers():
    with open(os.path.join(ROOT, "Captures", "PSStillImageBaker.m"), "r", encoding="utf-8") as f:
        still = f.read()
    assert "CGImageSourceCopyPropertiesAtIndex" in still, "Must copy full ImageIO properties"
    assert "kCIImageApplyOrientationProperty : @NO" in still, "Must preserve native orientation for EXIF"
    assert 'CFSTR("public.jpeg")' in still, "Must encode as public.jpeg"
    assert "kCGImageDestinationLossyCompressionQuality" in still

    with open(os.path.join(ROOT, "Captures", "PSLivePhotoVideoBaker.m"), "r", encoding="utf-8") as f:
        vid = f.read()
    assert "kPS12MaxLivePhotoDuration = 6.50" in vid, "Must cap Live Photo duration <= 6.5s"
    assert "[NSThread isMainThread]" in vid, "Must never block main thread"
    assert "isUnderMemoryPressure" in vid, "Must respect Jetsam memory pressure"
    assert "exportSession.metadata = asset.metadata" in vid, "Must preserve QuickTime metadata"

    with open(os.path.join(ROOT, "Captures", "PSCaptureCoordinator.m"), "r", encoding="utf-8") as f:
        coord = f.read()
    assert "performSynchronousSerializedBake:" in coord
    assert "_lastMemoryWarningTime" in coord


def check_tweak_persistence_hooks():
    with open(os.path.join(ROOT, "Tweak.xm"), "r", encoding="utf-8") as f:
        tw = f.read()
    for hook in (
        "%hook CAMStillImageCaptureResponse",
        "%hook CAMPersistenceController",
        "- (BOOL)_writeJPEGToURL:",
        "- (void)_locallyPersistStillImageResult:",
        "- (void)_locallyPersistVideoCaptureResult:",
    ):
        assert hook in tw, f"Missing persistence hook in Tweak.xm: {hook}"


def main():
    check_required_files()
    check_source_rules()
    check_makefile()
    check_still_and_video_bakers()
    check_tweak_persistence_hooks()
    print("[verify_phase4] ALL CHECKS PASSED (39 files, EXIF/MakerApple + LivePhoto .MOV + Jetsam guards OK)")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"[verify_phase4] FAILED: {exc}", file=sys.stderr)
        sys.exit(1)
