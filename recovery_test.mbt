///|
fn rec(
  kind : RecordKind,
  sequence : UInt,
  transaction : UInt,
  payload? : Bytes = b"",
) -> JournalRecord {
  JournalRecord::new(kind, sequence, transaction, payload~)
}

///|
test "put and delete payloads preserve binary keys and values" {
  let put = rec(
    Put,
    2U,
    7U,
    payload=encode_put_payload(b"\x00key", b"\xffvalue"),
  )
  let decoded = decode_mutation(put)
  assert_true(decoded.valid)
  guard decoded.mutation is Some(mutation) else { fail("missing mutation") }
  assert_true(mutation.kind == PutValue)
  assert_eq(mutation.key, b"\x00key")
  assert_eq(mutation.value, b"\xffvalue")
  let delete = rec(Delete, 3U, 7U, payload=encode_delete_payload(b"\x00key"))
  guard decode_mutation(delete).mutation is Some(removal) else {
    fail("missing delete")
  }
  assert_true(removal.kind == DeleteKey)
  assert_eq(removal.key, b"\x00key")
  assert_eq(removal.value, b"")
}

///|
test "only a committed transaction becomes replay actions" {
  let plan = build_recovery_plan([
    rec(Begin, 1U, 10U),
    rec(Put, 2U, 10U, payload=encode_put_payload(b"name", b"moon")),
    rec(Delete, 3U, 10U, payload=encode_delete_payload(b"old")),
    rec(Commit, 4U, 10U),
  ])
  assert_true(plan.recoverable)
  assert_eq(plan.committed_transactions, 1)
  assert_eq(plan.actions.length(), 2)
  assert_eq(plan.actions[0].key, b"name")
  assert_true(plan.actions[1].kind == DeleteKey)
}

///|
test "aborted and incomplete transactions never replay" {
  let plan = build_recovery_plan([
    rec(Begin, 1U, 10U),
    rec(Put, 2U, 10U, payload=encode_put_payload(b"a", b"1")),
    rec(Abort, 3U, 10U),
    rec(Begin, 4U, 11U),
    rec(Put, 5U, 11U, payload=encode_put_payload(b"b", b"2")),
  ])
  assert_true(plan.recoverable)
  assert_eq(plan.actions.length(), 0)
  assert_eq(plan.aborted_transactions, 1)
  assert_eq(plan.incomplete_transactions.length(), 1)
  assert_eq(plan.incomplete_transactions[0], 11U)
}

///|
test "interleaved transactions retain commit order" {
  let plan = build_recovery_plan([
    rec(Begin, 1U, 20U),
    rec(Begin, 2U, 21U),
    rec(Put, 3U, 20U, payload=encode_put_payload(b"a", b"1")),
    rec(Put, 4U, 21U, payload=encode_put_payload(b"b", b"2")),
    rec(Commit, 5U, 21U),
    rec(Commit, 6U, 20U),
  ])
  assert_eq(plan.actions.length(), 2)
  assert_eq(plan.actions[0].transaction, 21U)
  assert_eq(plan.actions[1].transaction, 20U)
}

///|
test "checkpoint excludes already durable history" {
  let plan = build_recovery_plan([
    rec(Begin, 1U, 30U),
    rec(Put, 2U, 30U, payload=encode_put_payload(b"old", b"value")),
    rec(Commit, 3U, 30U),
    rec(Checkpoint, 4U, 0U, payload=encode_checkpoint_payload(3U)),
    rec(Begin, 5U, 31U),
    rec(Put, 6U, 31U, payload=encode_put_payload(b"new", b"value")),
    rec(Commit, 7U, 31U),
  ])
  assert_eq(plan.checkpoint_sequence, 3U)
  assert_eq(plan.actions.length(), 1)
  assert_eq(plan.actions[0].key, b"new")
}

///|
test "semantic violations are reported without replay" {
  let plan = build_recovery_plan([
    rec(Put, 1U, 40U, payload=encode_put_payload(b"a", b"1")),
    rec(Commit, 2U, 40U),
    rec(Begin, 3U, 41U),
    rec(Begin, 4U, 41U),
    rec(Put, 5U, 41U, payload=b"\x08\x00\x00\x00x"),
  ])
  assert_false(plan.recoverable)
  assert_eq(plan.actions.length(), 0)
  assert_eq(plan.issues.length(), 4)
  assert_eq(plan.issues[0].code, "orphan_mutation")
  assert_eq(plan.issues[2].code, "duplicate_begin")
  assert_eq(plan.issues[3].code, "mutation_payload")
}

///|
test "delete payload rejects trailing bytes" {
  let malformed = rec(Delete, 1U, 1U, payload=b"\x01\x00\x00\x00kx")
  assert_false(decode_mutation(malformed).valid)
}

///|
test "invalid checkpoint does not discard journal history" {
  let plan = build_recovery_plan([
    rec(Begin, 1U, 50U),
    rec(Put, 2U, 50U, payload=encode_put_payload(b"a", b"1")),
    rec(Commit, 3U, 50U),
    rec(Checkpoint, 4U, 0U, payload=encode_checkpoint_payload(4U)),
  ])
  assert_false(plan.recoverable)
  assert_eq(plan.checkpoint_sequence, 0U)
  assert_eq(plan.actions.length(), 1)
  assert_eq(plan.issues[0].code, "checkpoint_range")
}
