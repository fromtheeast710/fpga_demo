use core::time::Duration;
use image::{ExtendedColorType::Rgb8, ImageReader};
use std::{
  error::Error,
  io::{ErrorKind::WouldBlock, Write},
};
use tokio_serial;

#[tokio::main(flavor = "current_thread")]
async fn main() -> Result<(), Box<dyn Error>> {
  const IMG_CHUNK: usize = 131072;

  let mut data = vec![0u8; IMG_CHUNK];

  let serial = tokio_serial::new("/dev/ttyACM0", 115200).timeout(Duration::from_millis(10));

  let mut port = tokio_serial::SerialStream::open(&serial)?;

  // TODO: support full rgba8
  let img = ImageReader::open("test/10x10_green.png")?.decode()?.to_rgb8();
  let raw = img.as_raw();

  let _ = port.write_all(raw);
  let _ = port.flush();

  println!("Input data: {:?}", raw);

  loop {
    // BUG: lost bits on big images leading to invalid buffer length
    match port.try_read(&mut data) {
      Ok(0) => (),
      Ok(n) => {
        let slice = &data[..n];

        image::save_buffer(
          "build/test.png",
          slice,
          img.dimensions().0,
          img.dimensions().1,
          Rgb8,
        )
        .unwrap();

        break Ok(println!("Processed data: {:?}", slice));
      }
      Err(e) if e.kind() == WouldBlock => (),
      Err(e) => return Err(e.into()),
    }
  }
}
