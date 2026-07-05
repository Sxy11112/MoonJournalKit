///|
fn action_has_commit(records : Array[JournalRecord], action : Mutation) -> Bool {
  let mut active = false
  let mut contains_action = false
  for record in records {
    if record.transaction != action.transaction {
      continue
    }
    match record.kind {
      Begin => {
        active = true
        contains_action = false
      }
      Put | Delete =>
        if active && record.sequence == action.sequence {
          contains_action = true
        }
      Commit =>
        if active {
          if contains_action {
            return true
          }
          active = false
        }
      Abort => {
        active = false
        contains_action = false
      }
      Checkpoint => ()
    }
  }
  false
}

///|
/// Exhaustively cuts the encoded journal after every byte and validates that
/// scanning returns an exact record prefix and recovery never invents a commit.
pub fn sweep_crash_cuts(records : Array[JournalRecord]) -> CrashSweepReport {
  let stream = encode_records(records)
  let mut cuts_checked = 0
  let mut exact_prefixes = 0
  let mut unsafe_replays = 0
  for cut = 0; cut <= stream.length(); cut = cut + 1 {
    let scan = scan_journal(stream[0:cut])
    let trusted = encode_records(scan.records)
    if trusted.length() == scan.valid_bytes &&
      trusted == stream[0:scan.valid_bytes].to_owned() {
      exact_prefixes += 1
    }
    let plan = build_recovery_plan(scan.records)
    for action in plan.actions {
      if !action_has_commit(scan.records, action) {
        unsafe_replays += 1
      }
    }
    cuts_checked += 1
  }
  {
    cuts_checked,
    exact_prefixes,
    unsafe_replays,
    passed: cuts_checked == exact_prefixes && unsafe_replays == 0,
  }
}

///|
fn flip_one_bit(data : BytesView, byte_index : Int, bit : Int) -> Bytes {
  let output = Buffer(size_hint=data.length())
  for index, byte in data {
    if index == byte_index {
      output.write_byte(byte ^ (1 << bit).to_byte())
    } else {
      output.write_byte(byte)
    }
  }
  output.to_bytes()
}

///|
/// Flips each bit independently and verifies that framing, checksums, or
/// sequence validation reject every modified stream.
pub fn sweep_single_bit_corruption(
  records : Array[JournalRecord],
) -> CorruptionSweepReport {
  let stream = encode_records(records)
  let mut bits_checked = 0
  let mut corruptions_detected = 0
  for byte_index = 0; byte_index < stream.length(); byte_index = byte_index + 1 {
    for bit = 0; bit < 8; bit = bit + 1 {
      let modified = flip_one_bit(stream, byte_index, bit)
      if scan_journal(modified).stop != CleanEnd {
        corruptions_detected += 1
      }
      bits_checked += 1
    }
  }
  let undetected = bits_checked - corruptions_detected
  { bits_checked, corruptions_detected, undetected, passed: undetected == 0 }
}
