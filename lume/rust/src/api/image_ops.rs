use anyhow::Result;
use image::{ImageFormat, ImageReader};
use std::io::Cursor;

use crate::helpers;

// ---------------------------------------------------------------------------
// Structs
// ---------------------------------------------------------------------------

pub struct LumeImageInfo {
    pub width: u32,
    pub height: u32,
    pub format: String,
    pub size_bytes: u32,
}

// ---------------------------------------------------------------------------
// Info
// ---------------------------------------------------------------------------

#[flutter_rust_bridge::frb(sync)]
pub fn get_image_info(image_bytes: Vec<u8>) -> Result<LumeImageInfo> {
    let reader = ImageReader::new(Cursor::new(&image_bytes)).with_guessed_format()?;
    let format = reader
        .format()
        .map(helpers::format_to_string)
        .unwrap_or_else(|| "unknown".to_string());
    let (width, height) = reader.into_dimensions()?;

    Ok(LumeImageInfo {
        width,
        height,
        format,
        size_bytes: image_bytes.len() as u32,
    })
}

// ---------------------------------------------------------------------------
// Resize
// ---------------------------------------------------------------------------

#[flutter_rust_bridge::frb(sync)]
pub fn resize(
    image_bytes: Vec<u8>,
    width: u32,
    height: u32,
    keep_aspect_ratio: bool,
) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?;
    let fmt = helpers::detect_format(&image_bytes)?;

    let resized = if keep_aspect_ratio {
        img.resize(width, height, image::imageops::FilterType::Lanczos3)
    } else {
        img.resize_exact(width, height, image::imageops::FilterType::Lanczos3)
    };

    helpers::encode(&resized, fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn resize_with_filter(
    image_bytes: Vec<u8>,
    width: u32,
    height: u32,
    filter: String,
) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?;
    let fmt = helpers::detect_format(&image_bytes)?;

    let filter_type = match filter.to_lowercase().as_str() {
        "nearest" => image::imageops::FilterType::Nearest,
        "triangle" | "bilinear" => image::imageops::FilterType::Triangle,
        "catmullrom" | "cubic" => image::imageops::FilterType::CatmullRom,
        "gaussian" => image::imageops::FilterType::Gaussian,
        "lanczos" | "lanczos3" => image::imageops::FilterType::Lanczos3,
        _ => image::imageops::FilterType::Lanczos3,
    };

    helpers::encode(&img.resize_exact(width, height, filter_type), fmt)
}

// ---------------------------------------------------------------------------
// Crop
// ---------------------------------------------------------------------------

#[flutter_rust_bridge::frb(sync)]
pub fn crop(
    image_bytes: Vec<u8>,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
) -> Result<Vec<u8>> {
    let mut img = helpers::load(&image_bytes)?;
    let fmt = helpers::detect_format(&image_bytes)?;
    let cropped = img.crop(x, y, width, height);
    helpers::encode(&cropped, fmt)
}

// ---------------------------------------------------------------------------
// Rotate & Flip
// ---------------------------------------------------------------------------

#[flutter_rust_bridge::frb(sync)]
pub fn rotate(image_bytes: Vec<u8>, degrees: u32) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?;
    let fmt = helpers::detect_format(&image_bytes)?;

    let rotated = match degrees % 360 {
        90 => img.rotate90(),
        180 => img.rotate180(),
        270 => img.rotate270(),
        _ => img,
    };

    helpers::encode(&rotated, fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn flip_horizontal(image_bytes: Vec<u8>) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?;
    let fmt = helpers::detect_format(&image_bytes)?;
    helpers::encode(&img.fliph(), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn flip_vertical(image_bytes: Vec<u8>) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?;
    let fmt = helpers::detect_format(&image_bytes)?;
    helpers::encode(&img.flipv(), fmt)
}

// ---------------------------------------------------------------------------
// Color adjustments
// ---------------------------------------------------------------------------

#[flutter_rust_bridge::frb(sync)]
pub fn grayscale(image_bytes: Vec<u8>) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?;
    let fmt = helpers::detect_format(&image_bytes)?;
    helpers::encode(&img.grayscale(), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn adjust_brightness(image_bytes: Vec<u8>, value: i32) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?;
    let fmt = helpers::detect_format(&image_bytes)?;
    helpers::encode(&img.brighten(value), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn adjust_contrast(image_bytes: Vec<u8>, value: f32) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?;
    let fmt = helpers::detect_format(&image_bytes)?;
    helpers::encode(&img.adjust_contrast(value), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn blur(image_bytes: Vec<u8>, sigma: f32) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?;
    let fmt = helpers::detect_format(&image_bytes)?;
    helpers::encode(&img.blur(sigma), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn sharpen(image_bytes: Vec<u8>, sigma: f32, threshold: i32) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?;
    let fmt = helpers::detect_format(&image_bytes)?;
    helpers::encode(&img.unsharpen(sigma, threshold), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn invert_colors(image_bytes: Vec<u8>) -> Result<Vec<u8>> {
    let mut img = helpers::load(&image_bytes)?;
    let fmt = helpers::detect_format(&image_bytes)?;
    img.invert();
    helpers::encode(&img, fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn huerotate(image_bytes: Vec<u8>, degrees: i32) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?;
    let fmt = helpers::detect_format(&image_bytes)?;
    helpers::encode(&img.huerotate(degrees), fmt)
}

// ---------------------------------------------------------------------------
// Format conversion
// ---------------------------------------------------------------------------

#[flutter_rust_bridge::frb(sync)]
pub fn convert_format(image_bytes: Vec<u8>, target_format: String) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?;
    let fmt = helpers::string_to_format(&target_format)?;
    helpers::encode(&img, fmt)
}

// ---------------------------------------------------------------------------
// Thumbnail
// ---------------------------------------------------------------------------

#[flutter_rust_bridge::frb(sync)]
pub fn thumbnail(image_bytes: Vec<u8>, max_width: u32, max_height: u32) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?;
    let fmt = helpers::detect_format(&image_bytes)?;
    helpers::encode(&img.thumbnail(max_width, max_height), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn thumbnail_exact(image_bytes: Vec<u8>, width: u32, height: u32) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?;
    let fmt = helpers::detect_format(&image_bytes)?;
    helpers::encode(&img.thumbnail_exact(width, height), fmt)
}

// ---------------------------------------------------------------------------
// Overlay / Compose
// ---------------------------------------------------------------------------

#[flutter_rust_bridge::frb(sync)]
pub fn overlay(
    base_bytes: Vec<u8>,
    overlay_bytes: Vec<u8>,
    x: i64,
    y: i64,
) -> Result<Vec<u8>> {
    let mut base = helpers::load(&base_bytes)?;
    let fmt = helpers::detect_format(&base_bytes)?;
    let top = helpers::load(&overlay_bytes)?;
    image::imageops::overlay(&mut base, &top, x, y);
    helpers::encode(&base, fmt)
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

#[flutter_rust_bridge::frb(sync)]
pub fn tile(image_bytes: Vec<u8>, cols: u32, rows: u32) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?;
    let fmt = helpers::detect_format(&image_bytes)?;
    let (w, h) = (img.width(), img.height());
    let mut canvas = image::DynamicImage::new_rgba8(w * cols, h * rows);
    for r in 0..rows {
        for c in 0..cols {
            image::imageops::overlay(&mut canvas, &img, (c * w) as i64, (r * h) as i64);
        }
    }
    helpers::encode(&canvas, fmt)
}

// ---------------------------------------------------------------------------
// Create blank image
// ---------------------------------------------------------------------------

#[flutter_rust_bridge::frb(sync)]
pub fn create_blank(width: u32, height: u32, r: u8, g: u8, b: u8, a: u8) -> Result<Vec<u8>> {
    let img = image::RgbaImage::from_pixel(width, height, image::Rgba([r, g, b, a]));
    let dyn_img = image::DynamicImage::ImageRgba8(img);
    helpers::encode(&dyn_img, ImageFormat::Png)
}

// ---------------------------------------------------------------------------
// Extract channel
// ---------------------------------------------------------------------------

#[flutter_rust_bridge::frb(sync)]
pub fn extract_channel(image_bytes: Vec<u8>, channel: u8) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_rgba8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let (w, h) = img.dimensions();
    let mut out = image::GrayImage::new(w, h);
    for (x, y, pixel) in img.enumerate_pixels() {
        let val = pixel.0[channel.min(3) as usize];
        out.put_pixel(x, y, image::Luma([val]));
    }
    helpers::encode(&image::DynamicImage::ImageLuma8(out), fmt)
}

// ---------------------------------------------------------------------------
// Pixel access
// ---------------------------------------------------------------------------

pub struct LumeColor {
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub a: u8,
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_pixel(image_bytes: Vec<u8>, x: u32, y: u32) -> Result<LumeColor> {
    let img = helpers::load(&image_bytes)?.to_rgba8();
    let pixel = img.get_pixel(x, y);
    Ok(LumeColor {
        r: pixel.0[0],
        g: pixel.0[1],
        b: pixel.0[2],
        a: pixel.0[3],
    })
}
