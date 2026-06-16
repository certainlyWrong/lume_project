## 1.0.6

- Fixed rust_lib_lume dependency to use hosted pub.dev version

## 1.0.5

- Fixed local development setup: rust_lib_lume uses path dependency
- Publish workflow converts to hosted dependency automatically

## 1.0.4

- Added CocoaPods support for macOS and iOS
- Added integration tests for Rust function calls
- Fixed GitHub Actions publish workflow (OIDC auth, CHANGELOG validation)

## 1.0.2

- Updated to flutter_rust_bridge 2.12.0
- Updated rust_lib_lume to 1.0.2
- Added Linux and Windows FFI plugin support

## 1.0.1+2

- Updated pubspec dependencies for pub.dev publishing
- Added rust_lib_lume hosted dependency

## 1.0.0

- Initial release
- LumeImage: Basic image operations (resize, crop, rotate, flip, color adjustments, blur, format conversion)
- LumeCanvas: Advanced operations via imageproc (filters, edge detection, morphology, drawing primitives)
- Flutter widgets: LumeImageProvider and LumeImageWidget
- Rust backend using `image` 0.25 and `imageproc` 0.25
- Flutter Rust Bridge 2.11.1 integration
