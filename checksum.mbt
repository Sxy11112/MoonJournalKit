///|
/// Computes CRC32C (Castagnoli) with the reflected polynomial.
pub fn crc32c(data : BytesView) -> UInt {
  let mut crc = 0xFFFFFFFFU
  for byte in data {
    crc = crc ^ byte.to_uint()
    for bit = 0; bit < 8; bit = bit + 1 {
      if (crc & 1U) == 1U {
        crc = (crc >> 1) ^ 0x82F63B78U
      } else {
        crc = crc >> 1
      }
    }
  }
  crc ^ 0xFFFFFFFFU
}

///|
/// Incrementally updates a CRC32C state before final xor.
pub fn crc32c_extend(state : UInt, data : BytesView) -> UInt {
  let mut crc = state ^ 0xFFFFFFFFU
  for byte in data {
    crc = crc ^ byte.to_uint()
    for bit = 0; bit < 8; bit = bit + 1 {
      if (crc & 1U) == 1U {
        crc = (crc >> 1) ^ 0x82F63B78U
      } else {
        crc = crc >> 1
      }
    }
  }
  crc ^ 0xFFFFFFFFU
}
