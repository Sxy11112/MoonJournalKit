///|
test "crc32c empty vector" {
  assert_eq(@moonjournalkit.crc32c(b""), 0U)
}

///|
test "crc32c standard check vector" {
  assert_eq(@moonjournalkit.crc32c(b"123456789"), 0xE3069283U)
}

///|
test "crc32c detects one byte change" {
  let first = @moonjournalkit.crc32c(b"journal-record")
  let second = @moonjournalkit.crc32c(b"journal-recorD")
  assert_true(first != second)
}

///|
test "crc32c incremental update equals one-shot" {
  let first = @moonjournalkit.crc32c(b"Moon")
  let combined = @moonjournalkit.crc32c_extend(first, b"JournalKit")
  assert_eq(combined, @moonjournalkit.crc32c(b"MoonJournalKit"))
}

///|
test "crc32c is deterministic across repeated calls" {
  let expected = @moonjournalkit.crc32c(b"deterministic")
  for attempt = 0; attempt < 100; attempt = attempt + 1 {
    assert_eq(@moonjournalkit.crc32c(b"deterministic"), expected)
  }
}
