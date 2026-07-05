///|
test "record roundtrip preserves binary payload" {
  let record = @moonjournalkit.JournalRecord::new(
    Put,
    7U,
    42U,
    payload=Bytes::from_array([0, 1, 2, 0xFF]),
  )
  let encoded = @moonjournalkit.encode_record(record)
  assert_eq(encoded.length(), 28)
  let decoded = @moonjournalkit.decode_record(encoded)
  assert_true(decoded.status == Decoded)
  assert_eq(decoded.next_offset, 28)
  guard decoded.record is Some(actual) else { fail("missing record") }
  assert_true(actual == record)
}

///|
test "all record kinds have stable roundtrips" {
  let kinds : Array[@moonjournalkit.RecordKind] = [
    Begin,
    Put,
    Delete,
    Commit,
    Abort,
    Checkpoint,
  ]
  for index, kind in kinds {
    let record = @moonjournalkit.JournalRecord::new(
      kind,
      (index + 1).reinterpret_as_uint(),
      9U,
      payload=b"x",
    )
    let decoded = @moonjournalkit.decode_record(
      @moonjournalkit.encode_record(record),
    )
    guard decoded.record is Some(actual) else { fail("missing record") }
    assert_true(actual == record)
  }
}

///|
test "decoder advances from a nonzero offset" {
  let first = @moonjournalkit.encode_record(
    @moonjournalkit.JournalRecord::new(Begin, 1U, 1U),
  )
  let second = @moonjournalkit.encode_record(
    @moonjournalkit.JournalRecord::new(Commit, 2U, 1U),
  )
  let buffer = Buffer()
  buffer.write_bytes(first)
  buffer.write_bytes(second)
  let bytes = buffer.to_bytes()
  let decoded = @moonjournalkit.decode_record(bytes, offset=first.length())
  guard decoded.record is Some(record) else { fail("missing record") }
  assert_true(record.kind == Commit)
  assert_eq(decoded.next_offset, first.length() + second.length())
}

///|
test "truncated header requests more data" {
  let decoded = @moonjournalkit.decode_record(b"MWAL")
  assert_true(decoded.status == NeedMoreData)
  assert_eq(decoded.next_offset, 0)
}

///|
test "truncated payload requests more data" {
  let encoded = @moonjournalkit.encode_record(
    @moonjournalkit.JournalRecord::new(Put, 1U, 1U, payload=b"payload"),
  )
  let decoded = @moonjournalkit.decode_record(encoded[0:encoded.length() - 1])
  assert_true(decoded.status == NeedMoreData)
}

///|
test "bad magic is corrupt" {
  let encoded = @moonjournalkit.encode_record(
    @moonjournalkit.JournalRecord::new(Begin, 1U, 1U),
  )
  let bytes = encoded.to_array()
  bytes[0] = 0
  let decoded = @moonjournalkit.decode_record(Bytes::from_array(bytes))
  assert_true(decoded.status == Corrupt)
  assert_eq(decoded.message, "journal magic mismatch")
}

///|
test "unsupported version is distinct from corruption" {
  let encoded = @moonjournalkit.encode_record(
    @moonjournalkit.JournalRecord::new(Begin, 1U, 1U),
  )
  let bytes = encoded.to_array()
  bytes[4] = 2
  let decoded = @moonjournalkit.decode_record(Bytes::from_array(bytes))
  assert_true(decoded.status == Unsupported)
}

///|
test "unknown kind is corrupt" {
  let encoded = @moonjournalkit.encode_record(
    @moonjournalkit.JournalRecord::new(Begin, 1U, 1U),
  )
  let bytes = encoded.to_array()
  bytes[5] = 99
  let decoded = @moonjournalkit.decode_record(Bytes::from_array(bytes))
  assert_true(decoded.status == Corrupt)
}

///|
test "payload bit flip fails checksum" {
  let encoded = @moonjournalkit.encode_record(
    @moonjournalkit.JournalRecord::new(Put, 1U, 1U, payload=b"payload"),
  )
  let bytes = encoded.to_array()
  bytes[24] = bytes[24] ^ 1
  let decoded = @moonjournalkit.decode_record(Bytes::from_array(bytes))
  assert_true(decoded.status == Corrupt)
  assert_eq(decoded.message, "record checksum mismatch")
}

///|
test "configured payload limit is enforced before allocation" {
  let encoded = @moonjournalkit.encode_record(
    @moonjournalkit.JournalRecord::new(Put, 1U, 1U, payload=b"12345"),
  )
  let decoded = @moonjournalkit.decode_record(encoded, max_payload=4)
  assert_true(decoded.status == Corrupt)
  assert_eq(decoded.message, "payload exceeds configured limit")
}
