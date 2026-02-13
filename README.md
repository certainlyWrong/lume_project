# Lume Project

A Flutter/Dart image processing library powered by Rust.

## Structure

```
lume_project/
├── lume/                 # Main Flutter package
│   ├── lib/             # Dart API (LumeImage, LumeCanvas, widgets)
│   ├── rust/            # Rust backend (image + imageproc crates)
│   ├── example/         # Demo app with visual examples
│   └── README.md        # 📖 Full documentation
│
├── mandelbrot/          # 🌀 GLSL fractal demo + Lume processing showcase
│   ├── lib/            # Mandelbrot shader app
│   ├── shaders/        # GLSL fragment shaders
│   └── README.md       # Demo documentation
│
├── lume.code-workspace  # VS Code workspace configuration
└── README.md            # This file
```

## About Lume

**Lume** is a high-performance image processing library for Flutter that leverages Rust's `image` and `imageproc` crates via Flutter Rust Bridge. It provides:

- **LumeImage** — Basic operations (resize, crop, rotate, color adjustments)
- **LumeCanvas** — Advanced operations (filters, edge detection, morphology, drawing)
- **Flutter widgets** — `LumeImageProvider` and `LumeImageWidget` for seamless UI integration

## Quick Links

- 📦 **Package**: [`lume/`](./lume/)
- 📖 **Full Documentation**: [`lume/README.md`](./lume/README.md)
- 🎨 **Example App**: [`lume/example/`](./lume/example/)
- 🌀 **Mandelbrot Demo**: [`mandelbrot/`](./mandelbrot/) — GLSL shaders + Lume processing
- 🔧 **Workspace**: [`lume.code-workspace`](./lume.code-workspace)

## Getting Started

See the [lume README](./lume/README.md) for:

- Installation instructions
- API reference
- Usage examples
- Technical details

## License

MIT
