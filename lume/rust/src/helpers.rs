use anyhow::Result;
use image::{DynamicImage, ImageFormat, ImageReader};
use std::io::Cursor;

pub fn load(bytes: &[u8]) -> Result<DynamicImage> {
    Ok(ImageReader::new(Cursor::new(bytes))
        .with_guessed_format()?
        .decode()?)
}

pub fn detect_format(bytes: &[u8]) -> Result<ImageFormat> {
    ImageReader::new(Cursor::new(bytes))
        .with_guessed_format()?
        .format()
        .ok_or_else(|| anyhow::anyhow!("Could not detect image format"))
}

pub fn encode(img: &DynamicImage, format: ImageFormat) -> Result<Vec<u8>> {
    let mut buf: Vec<u8> = Vec::new();
    img.write_to(&mut Cursor::new(&mut buf), format)?;
    Ok(buf)
}

pub fn format_to_string(fmt: ImageFormat) -> String {
    match fmt {
        ImageFormat::Png => "png",
        ImageFormat::Jpeg => "jpeg",
        ImageFormat::Gif => "gif",
        ImageFormat::WebP => "webp",
        ImageFormat::Bmp => "bmp",
        ImageFormat::Tiff => "tiff",
        ImageFormat::Ico => "ico",
        _ => "unknown",
    }
    .to_string()
}

pub fn string_to_format(s: &str) -> Result<ImageFormat> {
    match s.to_lowercase().as_str() {
        "png" => Ok(ImageFormat::Png),
        "jpeg" | "jpg" => Ok(ImageFormat::Jpeg),
        "gif" => Ok(ImageFormat::Gif),
        "webp" => Ok(ImageFormat::WebP),
        "bmp" => Ok(ImageFormat::Bmp),
        "tiff" | "tif" => Ok(ImageFormat::Tiff),
        "ico" => Ok(ImageFormat::Ico),
        other => Err(anyhow::anyhow!("Unsupported format: {}", other)),
    }
}
