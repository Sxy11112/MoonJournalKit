///|
fn verification_fixture() -> Array[JournalRecord] {
  [
    JournalRecord::new(Begin, 1U, 100U),
    JournalRecord::new(
      Put,
      2U,
      100U,
      payload=encode_put_payload(b"alpha", b"one"),
    ),
    JournalRecord::new(Commit, 3U, 100U),
    JournalRecord::new(Begin, 4U, 101U),
    JournalRecord::new(
      Put,
      5U,
      101U,
      payload=encode_put_payload(b"beta", b"two"),
    ),
    JournalRecord::new(Abort, 6U, 101U),
    JournalRecord::new(Begin, 7U, 102U),
    JournalRecord::new(
      Delete,
      8U,
      102U,
      payload=encode_delete_payload(b"alpha"),
    ),
    JournalRecord::new(Commit, 9U, 102U),
  ]
}

///|
test "every crash cut preserves only an exact trusted prefix" {
  let report = sweep_crash_cuts(verification_fixture())
  assert_true(report.passed)
  assert_true(report.cuts_checked > 200)
  assert_eq(report.cuts_checked, report.exact_prefixes)
  assert_eq(report.unsafe_replays, 0)
}

///|
test "every single bit corruption is detected" {
  let report = sweep_single_bit_corruption(verification_fixture())
  assert_true(report.passed)
  assert_true(report.bits_checked > 1600)
  assert_eq(report.bits_checked, report.corruptions_detected)
  assert_eq(report.undetected, 0)
}

///|
test "crash after mutation but before commit never replays it" {
  let records = [
    JournalRecord::new(Begin, 1U, 1U),
    JournalRecord::new(
      Put,
      2U,
      1U,
      payload=encode_put_payload(b"key", b"value"),
    ),
    JournalRecord::new(Commit, 3U, 1U),
  ]
  let stream = encode_records(records)
  let before_commit = records[0].encoded_size() + records[1].encoded_size()
  let scan = scan_journal(stream[0:before_commit])
  let plan = build_recovery_plan(scan.records)
  assert_eq(plan.actions.length(), 0)
  assert_eq(plan.incomplete_transactions.length(), 1)
}
