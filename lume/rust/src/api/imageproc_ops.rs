use anyhow::Result;
use image::Rgba;
use imageproc::contours::BorderType;
use imageproc::contrast::ThresholdType;
use imageproc::distance_transform::Norm as DistNorm;
use imageproc::point::Point;
use imageproc::rect::Rect;

use crate::helpers;

// ===========================================================================
// Structs
// ===========================================================================

pub struct LumePoint {
    pub x: i32,
    pub y: i32,
}

pub struct LumeContour {
    pub points: Vec<LumePoint>,
    pub border_type: String,
    pub parent: i32,
}

// ===========================================================================
// Filters (imageproc::filter)
// ===========================================================================

#[flutter_rust_bridge::frb(sync)]
pub fn gaussian_blur(image_bytes: Vec<u8>, sigma: f32) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_rgba8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let out = imageproc::filter::gaussian_blur_f32(&img, sigma);
    helpers::encode(&image::DynamicImage::ImageRgba8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn median_filter(image_bytes: Vec<u8>, x_radius: u32, y_radius: u32) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_luma8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let out = imageproc::filter::median_filter(&img, x_radius, y_radius);
    helpers::encode(&image::DynamicImage::ImageLuma8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn bilateral_filter(
    image_bytes: Vec<u8>,
    window_size: u32,
    sigma_color: f32,
    sigma_spatial: f32,
) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_luma8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let out =
        imageproc::filter::bilateral_filter(&img, window_size, sigma_color, sigma_spatial);
    helpers::encode(&image::DynamicImage::ImageLuma8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn box_filter(image_bytes: Vec<u8>, x_radius: u32, y_radius: u32) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_luma8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let out = imageproc::filter::box_filter(&img, x_radius, y_radius);
    helpers::encode(&image::DynamicImage::ImageLuma8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn sharpen3x3(image_bytes: Vec<u8>) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_luma8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let out = imageproc::filter::sharpen3x3(&img);
    helpers::encode(&image::DynamicImage::ImageLuma8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn sharpen_gaussian(image_bytes: Vec<u8>, sigma: f32, amount: f32) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_luma8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let out = imageproc::filter::sharpen_gaussian(&img, sigma, amount);
    helpers::encode(&image::DynamicImage::ImageLuma8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn laplacian_filter(image_bytes: Vec<u8>) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_luma8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let out = imageproc::filter::laplacian_filter(&img);
    // laplacian returns Luma<i16>, convert to Luma<u8> for encoding
    let converted: image::GrayImage = image::ImageBuffer::from_fn(out.width(), out.height(), |x, y| {
        let val = out.get_pixel(x, y).0[0];
        image::Luma([val.unsigned_abs().min(255) as u8])
    });
    helpers::encode(&image::DynamicImage::ImageLuma8(converted), fmt)
}

// ===========================================================================
// Edge detection (imageproc::edges)
// ===========================================================================

#[flutter_rust_bridge::frb(sync)]
pub fn canny(image_bytes: Vec<u8>, low_threshold: f32, high_threshold: f32) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_luma8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let out = imageproc::edges::canny(&img, low_threshold, high_threshold);
    helpers::encode(&image::DynamicImage::ImageLuma8(out), fmt)
}

// ===========================================================================
// Gradients (imageproc::gradients)
// ===========================================================================

#[flutter_rust_bridge::frb(sync)]
pub fn sobel_gradients(image_bytes: Vec<u8>) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_luma8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let out = imageproc::gradients::sobel_gradients(&img);
    // sobel returns Luma<u16>, normalize to Luma<u8>
    let converted: image::GrayImage = image::ImageBuffer::from_fn(out.width(), out.height(), |x, y| {
        let val = out.get_pixel(x, y).0[0];
        image::Luma([(val >> 8) as u8])
    });
    helpers::encode(&image::DynamicImage::ImageLuma8(converted), fmt)
}

// ===========================================================================
// Contrast (imageproc::contrast)
// ===========================================================================

#[flutter_rust_bridge::frb(sync)]
pub fn adaptive_threshold(image_bytes: Vec<u8>, block_radius: u32) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_luma8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let out = imageproc::contrast::adaptive_threshold(&img, block_radius);
    helpers::encode(&image::DynamicImage::ImageLuma8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn otsu_threshold(image_bytes: Vec<u8>) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_luma8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let level = imageproc::contrast::otsu_level(&img);
    let out = imageproc::contrast::threshold(&img, level, ThresholdType::Binary);
    helpers::encode(&image::DynamicImage::ImageLuma8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn threshold(image_bytes: Vec<u8>, value: u8, invert: bool) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_luma8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let tt = if invert {
        ThresholdType::BinaryInverted
    } else {
        ThresholdType::Binary
    };
    let out = imageproc::contrast::threshold(&img, value, tt);
    helpers::encode(&image::DynamicImage::ImageLuma8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn equalize_histogram(image_bytes: Vec<u8>) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_luma8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let out = imageproc::contrast::equalize_histogram(&img);
    helpers::encode(&image::DynamicImage::ImageLuma8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn stretch_contrast(
    image_bytes: Vec<u8>,
    input_lower: u8,
    input_upper: u8,
    output_lower: u8,
    output_upper: u8,
) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_luma8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let out = imageproc::contrast::stretch_contrast(
        &img,
        input_lower,
        input_upper,
        output_lower,
        output_upper,
    );
    helpers::encode(&image::DynamicImage::ImageLuma8(out), fmt)
}

// ===========================================================================
// Morphology (imageproc::morphology)
// ===========================================================================

#[flutter_rust_bridge::frb(sync)]
pub fn dilate(image_bytes: Vec<u8>, radius: u8) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_luma8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let out = imageproc::morphology::dilate(&img, DistNorm::LInf, radius);
    helpers::encode(&image::DynamicImage::ImageLuma8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn erode(image_bytes: Vec<u8>, radius: u8) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_luma8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let out = imageproc::morphology::erode(&img, DistNorm::LInf, radius);
    helpers::encode(&image::DynamicImage::ImageLuma8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn morphological_open(image_bytes: Vec<u8>, radius: u8) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_luma8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let out = imageproc::morphology::open(&img, DistNorm::LInf, radius);
    helpers::encode(&image::DynamicImage::ImageLuma8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn morphological_close(image_bytes: Vec<u8>, radius: u8) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_luma8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let out = imageproc::morphology::close(&img, DistNorm::LInf, radius);
    helpers::encode(&image::DynamicImage::ImageLuma8(out), fmt)
}

// ===========================================================================
// Geometric transformations (imageproc::geometric_transformations)
// ===========================================================================

#[flutter_rust_bridge::frb(sync)]
pub fn rotate_about_center(
    image_bytes: Vec<u8>,
    theta: f32,
    bg_r: u8,
    bg_g: u8,
    bg_b: u8,
    bg_a: u8,
) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_rgba8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let default = Rgba([bg_r, bg_g, bg_b, bg_a]);
    let interpolation = imageproc::geometric_transformations::Interpolation::Bilinear;
    let out = imageproc::geometric_transformations::rotate_about_center(
        &img,
        theta,
        interpolation,
        default,
    );
    helpers::encode(&image::DynamicImage::ImageRgba8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn translate(image_bytes: Vec<u8>, tx: i32, ty: i32) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_rgba8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let out = imageproc::geometric_transformations::translate(&img, (tx, ty));
    helpers::encode(&image::DynamicImage::ImageRgba8(out), fmt)
}

// ===========================================================================
// Noise (imageproc::noise)
// ===========================================================================

#[flutter_rust_bridge::frb(sync)]
pub fn gaussian_noise(
    image_bytes: Vec<u8>,
    mean: f64,
    stddev: f64,
    seed: u64,
) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_rgba8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let out = imageproc::noise::gaussian_noise(&img, mean, stddev, seed);
    helpers::encode(&image::DynamicImage::ImageRgba8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn salt_and_pepper_noise(
    image_bytes: Vec<u8>,
    rate: f64,
    seed: u64,
) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_rgba8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let out = imageproc::noise::salt_and_pepper_noise(&img, rate, seed);
    helpers::encode(&image::DynamicImage::ImageRgba8(out), fmt)
}

// ===========================================================================
// Seam carving (imageproc::seam_carving)
// ===========================================================================

#[flutter_rust_bridge::frb(sync)]
pub fn seam_carve_width(image_bytes: Vec<u8>, new_width: u32) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_rgba8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let current_width = img.width();
    if new_width >= current_width {
        return helpers::encode(&image::DynamicImage::ImageRgba8(img), fmt);
    }
    let seams_to_remove = current_width - new_width;
    let mut current = img;
    for _ in 0..seams_to_remove {
        let gray = image::DynamicImage::ImageRgba8(current.clone()).to_luma8();
        let energy_u16 = imageproc::gradients::sobel_gradients(&gray);
        // Convert Luma<u16> → Luma<u8> for find_vertical_seam
        let energy: image::GrayImage = image::ImageBuffer::from_fn(
            energy_u16.width(),
            energy_u16.height(),
            |x, y| image::Luma([(energy_u16.get_pixel(x, y).0[0] >> 8) as u8]),
        );
        let seam = imageproc::seam_carving::find_vertical_seam(&energy);
        current = imageproc::seam_carving::remove_vertical_seam(&current, &seam);
    }
    helpers::encode(&image::DynamicImage::ImageRgba8(current), fmt)
}

// ===========================================================================
// Drawing (imageproc::drawing)
// ===========================================================================

#[flutter_rust_bridge::frb(sync)]
pub fn draw_line(
    image_bytes: Vec<u8>,
    x1: i32,
    y1: i32,
    x2: i32,
    y2: i32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_rgba8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let color = Rgba([r, g, b, a]);
    let out = imageproc::drawing::draw_line_segment(
        &img,
        (x1 as f32, y1 as f32),
        (x2 as f32, y2 as f32),
        color,
    );
    helpers::encode(&image::DynamicImage::ImageRgba8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn draw_antialiased_line(
    image_bytes: Vec<u8>,
    x1: i32,
    y1: i32,
    x2: i32,
    y2: i32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_rgba8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let color = Rgba([r, g, b, a]);
    let out = imageproc::drawing::draw_antialiased_line_segment(
        &img,
        (x1, y1),
        (x2, y2),
        color,
        imageproc::pixelops::interpolate,
    );
    helpers::encode(&image::DynamicImage::ImageRgba8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn draw_hollow_rect(
    image_bytes: Vec<u8>,
    x: i32,
    y: i32,
    width: u32,
    height: u32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_rgba8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let color = Rgba([r, g, b, a]);
    let rect = Rect::at(x, y).of_size(width, height);
    let out = imageproc::drawing::draw_hollow_rect(&img, rect, color);
    helpers::encode(&image::DynamicImage::ImageRgba8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn draw_filled_rect(
    image_bytes: Vec<u8>,
    x: i32,
    y: i32,
    width: u32,
    height: u32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_rgba8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let color = Rgba([r, g, b, a]);
    let rect = Rect::at(x, y).of_size(width, height);
    let out = imageproc::drawing::draw_filled_rect(&img, rect, color);
    helpers::encode(&image::DynamicImage::ImageRgba8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn draw_hollow_circle(
    image_bytes: Vec<u8>,
    cx: i32,
    cy: i32,
    radius: i32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_rgba8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let color = Rgba([r, g, b, a]);
    let out = imageproc::drawing::draw_hollow_circle(&img, (cx, cy), radius, color);
    helpers::encode(&image::DynamicImage::ImageRgba8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn draw_filled_circle(
    image_bytes: Vec<u8>,
    cx: i32,
    cy: i32,
    radius: i32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_rgba8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let color = Rgba([r, g, b, a]);
    let out = imageproc::drawing::draw_filled_circle(&img, (cx, cy), radius, color);
    helpers::encode(&image::DynamicImage::ImageRgba8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn draw_hollow_ellipse(
    image_bytes: Vec<u8>,
    cx: i32,
    cy: i32,
    width_radius: i32,
    height_radius: i32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_rgba8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let color = Rgba([r, g, b, a]);
    let out = imageproc::drawing::draw_hollow_ellipse(
        &img,
        (cx, cy),
        width_radius,
        height_radius,
        color,
    );
    helpers::encode(&image::DynamicImage::ImageRgba8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn draw_filled_ellipse(
    image_bytes: Vec<u8>,
    cx: i32,
    cy: i32,
    width_radius: i32,
    height_radius: i32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_rgba8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let color = Rgba([r, g, b, a]);
    let out = imageproc::drawing::draw_filled_ellipse(
        &img,
        (cx, cy),
        width_radius,
        height_radius,
        color,
    );
    helpers::encode(&image::DynamicImage::ImageRgba8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn draw_filled_polygon(
    image_bytes: Vec<u8>,
    points: Vec<LumePoint>,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_rgba8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let color = Rgba([r, g, b, a]);
    let pts: Vec<Point<i32>> = points.iter().map(|p| Point::new(p.x, p.y)).collect();
    let out = imageproc::drawing::draw_polygon(&img, &pts, color);
    helpers::encode(&image::DynamicImage::ImageRgba8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn draw_hollow_polygon(
    image_bytes: Vec<u8>,
    points: Vec<LumePoint>,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) -> Result<Vec<u8>> {
    let mut img = helpers::load(&image_bytes)?.to_rgba8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let color = Rgba([r, g, b, a]);
    let pts: Vec<Point<f32>> = points.iter().map(|p| Point::new(p.x as f32, p.y as f32)).collect();
    imageproc::drawing::draw_hollow_polygon_mut(&mut img, &pts, color);
    helpers::encode(&image::DynamicImage::ImageRgba8(img), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn draw_cubic_bezier(
    image_bytes: Vec<u8>,
    start_x: f32,
    start_y: f32,
    end_x: f32,
    end_y: f32,
    ctrl1_x: f32,
    ctrl1_y: f32,
    ctrl2_x: f32,
    ctrl2_y: f32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_rgba8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let color = Rgba([r, g, b, a]);
    let out = imageproc::drawing::draw_cubic_bezier_curve(
        &img,
        (start_x, start_y),
        (end_x, end_y),
        (ctrl1_x, ctrl1_y),
        (ctrl2_x, ctrl2_y),
        color,
    );
    helpers::encode(&image::DynamicImage::ImageRgba8(out), fmt)
}

#[flutter_rust_bridge::frb(sync)]
pub fn draw_cross(
    image_bytes: Vec<u8>,
    cx: i32,
    cy: i32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_rgba8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let color = Rgba([r, g, b, a]);
    let out = imageproc::drawing::draw_cross(&img, color, cx, cy);
    helpers::encode(&image::DynamicImage::ImageRgba8(out), fmt)
}

// ===========================================================================
// Contours (imageproc::contours)
// ===========================================================================

#[flutter_rust_bridge::frb(sync)]
pub fn find_contours(image_bytes: Vec<u8>) -> Result<Vec<LumeContour>> {
    let img = helpers::load(&image_bytes)?.to_luma8();
    let contours = imageproc::contours::find_contours::<i32>(&img);
    Ok(contours
        .into_iter()
        .map(|c| LumeContour {
            points: c
                .points
                .into_iter()
                .map(|p| LumePoint { x: p.x, y: p.y })
                .collect(),
            border_type: match c.border_type {
                BorderType::Outer => "outer".to_string(),
                BorderType::Hole => "hole".to_string(),
            },
            parent: c.parent.map(|p| p as i32).unwrap_or(-1),
        })
        .collect())
}

// ===========================================================================
// Distance transform (imageproc::distance_transform)
// ===========================================================================

#[flutter_rust_bridge::frb(sync)]
pub fn distance_transform(image_bytes: Vec<u8>) -> Result<Vec<u8>> {
    let img = helpers::load(&image_bytes)?.to_luma8();
    let fmt = helpers::detect_format(&image_bytes)?;
    let out = imageproc::distance_transform::distance_transform(&img, DistNorm::LInf);
    helpers::encode(&image::DynamicImage::ImageLuma8(out), fmt)
}
