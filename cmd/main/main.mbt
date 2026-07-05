///|
fn main {
  let records = [
    @journal.JournalRecord::new(Begin, 1U, 101U),
    @journal.JournalRecord::new(
      Put,
      2U,
      101U,
      payload=@journal.encode_put_payload(b"account/alice", b"100"),
    ),
    @journal.JournalRecord::new(Commit, 3U, 101U),
    @journal.JournalRecord::new(Begin, 4U, 102U),
    @journal.JournalRecord::new(
      Delete,
      5U,
      102U,
      payload=@journal.encode_delete_payload(b"account/old"),
    ),
    @journal.JournalRecord::new(Abort, 6U, 102U),
  ]
  let stream = @journal.encode_records(records)
  let scan = @journal.scan_journal(stream)
  let recovery = @journal.build_recovery_plan(scan.records)
  println("MoonJournalKit deterministic recovery demo")
  println("scan=" + scan.to_json())
  println("recovery=" + recovery.to_json())
  println("crash_sweep=" + @journal.sweep_crash_cuts(records).to_json())
  println(
    "corruption_sweep=" +
    @journal.sweep_single_bit_corruption(records).to_json(),
  )
}
