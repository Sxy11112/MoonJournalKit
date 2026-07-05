///|
test "scan report uses stable json field names" {
  let scan = scan_journal(encode_records([JournalRecord::new(Begin, 1U, 1U)]))
  assert_eq(
    scan.to_json(),
    "{\"records\":1,\"valid_bytes\":24,\"total_bytes\":24,\"stop\":\"clean_end\",\"fault_offset\":24,\"message\":\"journal ended at a valid record boundary\"}",
  )
}

///|
test "recovery report includes incomplete transactions and escaped issues" {
  let plan = build_recovery_plan([
    JournalRecord::new(Begin, 1U, 9U),
    JournalRecord::new(Commit, 2U, 8U),
  ])
  assert_eq(
    plan.to_json(),
    "{\"recoverable\":false,\"checkpoint_sequence\":0,\"actions\":0,\"committed_transactions\":0,\"aborted_transactions\":0,\"incomplete_transactions\":[9],\"issues\":[{\"code\":\"orphan_commit\",\"sequence\":2,\"transaction\":8,\"message\":\"commit has no active transaction\"}]}",
  )
}

///|
test "verification reports have deterministic json" {
  let crash : CrashSweepReport = {
    cuts_checked: 10,
    exact_prefixes: 10,
    unsafe_replays: 0,
    passed: true,
  }
  assert_eq(
    crash.to_json(),
    "{\"cuts_checked\":10,\"exact_prefixes\":10,\"unsafe_replays\":0,\"passed\":true}",
  )
  let corruption : CorruptionSweepReport = {
    bits_checked: 80,
    corruptions_detected: 80,
    undetected: 0,
    passed: true,
  }
  assert_eq(
    corruption.to_json(),
    "{\"bits_checked\":80,\"corruptions_detected\":80,\"undetected\":0,\"passed\":true}",
  )
}
