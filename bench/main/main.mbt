///|
fn workload(transactions : Int) -> Array[@journal.JournalRecord] {
  let records : Array[@journal.JournalRecord] = []
  let mut sequence = 1U
  for transaction = 1
      transaction <= transactions
      transaction = transaction + 1 {
    let id = transaction.reinterpret_as_uint()
    records.push(@journal.JournalRecord::new(Begin, sequence, id))
    sequence += 1U
    records.push(
      @journal.JournalRecord::new(
        Put,
        sequence,
        id,
        payload=@journal.encode_put_payload(b"bench-key", b"bench-value"),
      ),
    )
    sequence += 1U
    records.push(@journal.JournalRecord::new(Commit, sequence, id))
    sequence += 1U
  }
  records
}

///|
fn main {
  let records = workload(10000)
  let stream = @journal.encode_records(records)
  let scan = @journal.scan_journal(stream)
  let recovery = @journal.build_recovery_plan(scan.records)
  let segments = @journal.plan_segments(records, 1024 * 1024, 10000)
  let crash_sample = @journal.sweep_crash_cuts(workload(100))
  println("records=\{records.length()}")
  println("encoded_bytes=\{stream.length()}")
  println("scan=" + scan.to_json())
  println("recovery=" + recovery.to_json())
  println("segments=\{segments.segments.length()}")
  println("crash_sample=" + crash_sample.to_json())
}
