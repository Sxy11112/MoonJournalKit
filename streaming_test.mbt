///|
test "stream decoder emits records across arbitrary chunk boundaries" {
  let records = [
    @moonjournalkit.JournalRecord::new(Begin, 1U, 9U),
    @moonjournalkit.JournalRecord::new(Put, 2U, 9U, payload=b"a=b"),
    @moonjournalkit.JournalRecord::new(Commit, 3U, 9U),
  ]
  let encoded = @moonjournalkit.encode_records(records)
  let decoder = @moonjournalkit.StreamJournalDecoder::new()
  let first = decoder.feed(encoded[0:17])
  assert_eq(first.records.length(), 0)
  assert_eq(first.buffered_bytes, 17)
  let second = decoder.feed(encoded[17:records[0].encoded_size() + 3])
  assert_eq(second.records.length(), 1)
  let third = decoder.feed(
    encoded[records[0].encoded_size() + 3:encoded.length()],
  )
  assert_eq(third.records.length(), 2)
  assert_eq(third.buffered_bytes, 0)
  assert_true(third.stop is None)
}

///|
test "stream decoder bounds incomplete tails and preserves sequence checks" {
  let limited = @moonjournalkit.StreamJournalDecoder::new(max_buffered=4)
  let overflow = limited.feed(b"MWAL12345")
  assert_true(overflow.stop is Some(RecordLimit))
  let decoder = @moonjournalkit.StreamJournalDecoder::new()
  let first = @moonjournalkit.encode_record(
    @moonjournalkit.JournalRecord::new(Begin, 1U, 1U),
  )
  ignore(decoder.feed(first))
  let gap = decoder.feed(
    @moonjournalkit.encode_record(
      @moonjournalkit.JournalRecord::new(Commit, 3U, 1U),
    ),
  )
  assert_true(gap.stop is Some(SequenceViolation))
}
