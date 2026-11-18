# PhotographicStyles12 (v2.0.0)

iPhone 16 Pro Max **Photographic Styles** (15 Presets: 6 Undertones + 9 Mood) tái thiết kế sạch từ con số 0 cho **iPhone 5s / iOS 12.0–12.5.8 (`arm64`)**, tương thích hoàn toàn với **Iris** Live Photo.

## Kiến trúc Zero-Intrusion (v2.0.0)
- **Viewfinder 60fps không xâm lấn**: Sử dụng `CAFilter` (`colorMatrix`, keypath `filters.ps12LiveMatrix.inputColorMatrix`) gắn trực tiếp lên `CAMPreviewView`. **Không** gắn thêm `AVCaptureVideoDataOutput`, **không** hook `CIContext` hoặc `CALayer` toàn cục — loại bỏ triệt để xung đột crash với Iris Live Photo.
- **Unified Color Science + Skin-Tone Protection**: Cùng một hệ tham số `PSResolveParameters` cho cả viewfinder (`CAColorMatrix`) và ảnh chụp (`CIColorKernel` 6 uniforms tối ưu Apple A7, bảo vệ tông da bằng `smoothstep`).
- **Bảo toàn Metadata & Jetsam Guard**:
  - `PSStillImageBaker` giữ nguyên 100% `{MakerApple}` (key 17 `ContentIdentifier`), `{Exif}`, `{TIFF}`, `{GPS}`, `Orientation`.
  - `PSLivePhotoVideoBaker` chỉ xử lý Live Photo `.MOV` (`<= 6.5s`), tự động bỏ qua khi có memory warning.
  - Thumbnail `CAMStillImageCaptureResponse` dùng `bakedFastThumbnailImage:` (giới hạn `<= 360px`) trên `CIContext` tách biệt khỏi `_bakeSemaphore`.

## Hướng dẫn sử dụng trên iPhone 5s (320×568)
- **Chạm nút lưới chấm góc trên bên phải**: Mở/đóng bảng điều khiển Photographic Styles.
- **Nhấn giữ nút góc trên bên phải (`0.45s`)**: Bật/tắt nhanh Styles.
- **Chạm đúp (Double-tap) vào bảng 2D Tone/Color**: Đưa `Tone` và `Color` về mặc định của preset hiện tại.
- **Nút `[LP]` trên thanh tiêu đề bảng**: Chuyển đổi giữa **Live Photo Video: Graded** (vàng, grade cả ảnh + `.MOV`) và **Fast Skip** (xám, chỉ grade ảnh tĩnh để chụp liên tiếp siêu nhanh).

## Build `.deb` qua GitHub Actions & Cài đặt
1. Cài Git trên Windows (nếu chưa có): `winget install --id Git.Git -e`
2. Đẩy mã nguồn lên GitHub:
   ```powershell
   .\tools\publish_to_github.ps1 -RemoteUrl "https://github.com/<user>/<repo>.git"
   ```
3. Mở tab **Actions** trên GitHub, tải artifact `PhotographicStyles12-v2.0.0-deb` (file `.deb` chuẩn `gzip` cho iOS 12).
4. Cài qua Filza hoặc SSH:
   ```bash
   dpkg -i com.ps12.photographicstyles12_2.0.0_iphoneos-arm.deb
   killall -9 Camera
   ```
