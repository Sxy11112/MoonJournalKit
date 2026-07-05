///|
fn invalid_segment_plan(message : String) -> SegmentPlan {
  { segments: [], total_records: 0, total_bytes: 0, valid: false, message }
}

///|
fn append_segment(
  segments : Array[SegmentMeta],
  id : UInt,
  first_sequence : UInt,
  last_sequence : UInt,
  record_count : Int,
  byte_size : Int,
) -> Unit {
  segments.push({ id, first_sequence, last_sequence, record_count, byte_size })
}

///|
/// Plans segment rotation without splitting a record. A single oversized record
/// receives its own segment so that forward progress remains deterministic.
pub fn plan_segments(
  records : Array[JournalRecord],
  max_bytes : Int,
  max_records : Int,
  first_id? : UInt = 1U,
) -> SegmentPlan {
  if max_bytes < JOURNAL_HEADER_SIZE {
    return invalid_segment_plan("max bytes is smaller than one record header")
  }
  if max_records <= 0 {
    return invalid_segment_plan("max records must be positive")
  }
  let segments : Array[SegmentMeta] = []
  let mut id = first_id
  let mut first_sequence = 0U
  let mut last_sequence = 0U
  let mut segment_records = 0
  let mut segment_bytes = 0
  let mut total_bytes = 0
  for record in records {
    if record.sequence == 0U ||
      (last_sequence > 0U && record.sequence != last_sequence + 1U) {
      return invalid_segment_plan("record sequence is not contiguous")
    }
    let size = record.encoded_size()
    if segment_records > 0 &&
      (segment_records >= max_records || segment_bytes + size > max_bytes) {
      append_segment(
        segments, id, first_sequence, last_sequence, segment_records, segment_bytes,
      )
      id += 1U
      first_sequence = 0U
      segment_records = 0
      segment_bytes = 0
    }
    if segment_records == 0 {
      first_sequence = record.sequence
    }
    last_sequence = record.sequence
    segment_records += 1
    segment_bytes += size
    total_bytes += size
  }
  if segment_records > 0 {
    append_segment(
      segments, id, first_sequence, last_sequence, segment_records, segment_bytes,
    )
  }
  {
    segments,
    total_records: records.length(),
    total_bytes,
    valid: true,
    message: "segment rotation plan is valid",
  }
}

///|
/// Validates IDs, sequence continuity, counts, and non-empty segment metadata.
pub fn validate_segment_chain(segments : Array[SegmentMeta]) -> Bool {
  let mut previous_id = 0U
  let mut previous_sequence = 0U
  for index, segment in segments {
    if segment.record_count <= 0 ||
      segment.byte_size < JOURNAL_HEADER_SIZE ||
      segment.first_sequence == 0U ||
      segment.last_sequence < segment.first_sequence {
      return false
    }
    if index > 0 &&
      (
        segment.id != previous_id + 1U ||
        segment.first_sequence != previous_sequence + 1U
      ) {
      return false
    }
    previous_id = segment.id
    previous_sequence = segment.last_sequence
  }
  true
}

///|
/// Returns the first segment that may contain records newer than a checkpoint.
/// A return value equal to segment count means no segment needs replay.
pub fn recovery_segment_index(
  segments : Array[SegmentMeta],
  checkpoint_sequence : UInt,
) -> Int {
  for index, segment in segments {
    if segment.last_sequence > checkpoint_sequence {
      return index
    }
  }
  segments.length()
}
