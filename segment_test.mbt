///|
fn segment_records(
  count : Int,
  payload_size? : Int = 0,
) -> Array[JournalRecord] {
  Array::makei(count, fn(index) {
    JournalRecord::new(
      Put,
      (index + 1).reinterpret_as_uint(),
      1U,
      payload=Bytes::make(payload_size, 0),
    )
  })
}

///|
test "segment planner rotates on record count" {
  let plan = plan_segments(segment_records(5), 4096, 2)
  assert_true(plan.valid)
  assert_eq(plan.segments.length(), 3)
  assert_eq(plan.segments[0].record_count, 2)
  assert_eq(plan.segments[2].record_count, 1)
  assert_eq(plan.segments[2].first_sequence, 5U)
  assert_true(validate_segment_chain(plan.segments))
}

///|
test "segment planner rotates on bytes" {
  let records = segment_records(3, payload_size=10)
  let plan = plan_segments(records, 68, 100)
  assert_eq(plan.segments.length(), 2)
  assert_eq(plan.segments[0].byte_size, 68)
  assert_eq(plan.segments[1].byte_size, 34)
  assert_eq(plan.total_bytes, 102)
}

///|
test "oversized record occupies one segment" {
  let plan = plan_segments(segment_records(2, payload_size=100), 32, 10)
  assert_true(plan.valid)
  assert_eq(plan.segments.length(), 2)
  assert_eq(plan.segments[0].record_count, 1)
}

///|
test "segment planner rejects invalid limits and sequence gaps" {
  assert_false(plan_segments([], 23, 1).valid)
  assert_false(plan_segments([], 24, 0).valid)
  assert_false(
    plan_segments(
      [JournalRecord::new(Begin, 1U, 1U), JournalRecord::new(Commit, 3U, 1U)],
      1024,
      10,
    ).valid,
  )
}

///|
test "segment chain validation catches discontinuity" {
  assert_false(
    validate_segment_chain([
      {
        id: 1U,
        first_sequence: 1U,
        last_sequence: 2U,
        record_count: 2,
        byte_size: 48,
      },
      {
        id: 3U,
        first_sequence: 4U,
        last_sequence: 4U,
        record_count: 1,
        byte_size: 24,
      },
    ]),
  )
}

///|
test "checkpoint locates first segment requiring replay" {
  let segments = plan_segments(segment_records(6), 4096, 2).segments
  assert_eq(recovery_segment_index(segments, 0U), 0)
  assert_eq(recovery_segment_index(segments, 2U), 1)
  assert_eq(recovery_segment_index(segments, 5U), 2)
  assert_eq(recovery_segment_index(segments, 6U), 3)
}
