///|
fn sample_records() -> Array[@moonjournalkit.JournalRecord] {
  [
    @moonjournalkit.JournalRecord::new(Begin, 1U, 7U),
    @moonjournalkit.JournalRecord::new(Put, 2U, 7U, payload=b"k=v"),
    @moonjournalkit.JournalRecord::new(Commit, 3U, 7U),
  ]
}

///|
test "empty journal is a clean stream" {
  let scan = @moonjournalkit.scan_journal(b"")
  assert_true(scan.stop == CleanEnd)
  assert_eq(scan.records.length(), 0)
  assert_eq(scan.valid_bytes, 0)
}

///|
test "scanner decodes ordered records" {
  let records = sample_records()
  let encoded = @moonjournalkit.encode_records(records)
  let scan = @moonjournalkit.scan_journal(encoded)
  assert_true(scan.stop == CleanEnd)
  assert_eq(scan.records.length(), 3)
  assert_eq(scan.valid_bytes, encoded.length())
  assert_true(scan.records == records)
}

///|
test "truncated final record preserves prior boundary" {
  let records = sample_records()
  let encoded = @moonjournalkit.encode_records(records)
  let expected_valid = records[0].encoded_size() + records[1].encoded_size()
  let scan = @moonjournalkit.scan_journal(encoded[0:encoded.length() - 2])
  assert_true(scan.stop == TruncatedTail)
  assert_eq(scan.records.length(), 2)
  assert_eq(scan.valid_bytes, expected_valid)
  assert_eq(scan.valid_prefix(encoded).length(), expected_valid)
}

///|
test "checksum failure stops before corrupt record" {
  let records = sample_records()
  let encoded = @moonjournalkit.encode_records(records)
  let bytes = encoded.to_array()
  let second_offset = records[0].encoded_size()
  bytes[second_offset + 24] = bytes[second_offset + 24] ^ 1
  let scan = @moonjournalkit.scan_journal(Bytes::from_array(bytes))
  assert_true(scan.stop == Corruption)
  assert_eq(scan.records.length(), 1)
  assert_eq(scan.valid_bytes, second_offset)
}

///|
test "strict sequence rejects gaps" {
  let records = [
    @moonjournalkit.JournalRecord::new(Begin, 1U, 7U),
    @moonjournalkit.JournalRecord::new(Commit, 3U, 7U),
  ]
  let scan = @moonjournalkit.scan_journal(
    @moonjournalkit.encode_records(records),
  )
  assert_true(scan.stop == SequenceViolation)
  assert_eq(scan.records.length(), 1)
}

///|
test "non-strict sequence permits gaps but not rollback" {
  let gap = [
    @moonjournalkit.JournalRecord::new(Begin, 1U, 7U),
    @moonjournalkit.JournalRecord::new(Commit, 3U, 7U),
  ]
  let accepted = @moonjournalkit.scan_journal(
    @moonjournalkit.encode_records(gap),
    strict_sequence=false,
  )
  assert_true(accepted.stop == CleanEnd)
  let rollback = [
    @moonjournalkit.JournalRecord::new(Begin, 3U, 7U),
    @moonjournalkit.JournalRecord::new(Commit, 2U, 7U),
  ]
  let rejected = @moonjournalkit.scan_journal(
    @moonjournalkit.encode_records(rollback),
    strict_sequence=false,
  )
  assert_true(rejected.stop == SequenceViolation)
}

///|
test "record limit stops at a valid boundary" {
  let records = sample_records()
  let scan = @moonjournalkit.scan_journal(
    @moonjournalkit.encode_records(records),
    max_records=2,
  )
  assert_true(scan.stop == RecordLimit)
  assert_eq(scan.records.length(), 2)
  assert_eq(
    scan.valid_bytes,
    records[0].encoded_size() + records[1].encoded_size(),
  )
}

///|
test "unsupported version is preserved as scan reason" {
  let bytes = @moonjournalkit.encode_records(sample_records()).to_array()
  bytes[4] = 2
  let scan = @moonjournalkit.scan_journal(Bytes::from_array(bytes))
  assert_true(scan.stop == UnsupportedVersion)
  assert_eq(scan.valid_bytes, 0)
}
