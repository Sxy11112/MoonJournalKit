///|
priv struct TransactionBuffer {
  id : UInt
  mutations : Array[Mutation]
}

///|
fn mutation_result(
  valid : Bool,
  message : String,
  mutation? : Mutation,
) -> MutationDecode {
  { valid, mutation, message }
}

///|
/// Encodes a put payload as key length, key bytes, then value bytes.
pub fn encode_put_payload(key : BytesView, value : BytesView) -> Bytes {
  let output = Buffer(size_hint=4 + key.length() + value.length())
  output.write_uint_le(key.length().reinterpret_as_uint())
  output.write_bytes(key)
  output.write_bytes(value)
  output.to_bytes()
}

///|
/// Encodes a delete payload as key length followed by key bytes.
pub fn encode_delete_payload(key : BytesView) -> Bytes {
  let output = Buffer(size_hint=4 + key.length())
  output.write_uint_le(key.length().reinterpret_as_uint())
  output.write_bytes(key)
  output.to_bytes()
}

///|
/// Decodes a put or delete record without allocating before bounds checks pass.
pub fn decode_mutation(
  record : JournalRecord,
  max_key? : Int = 1024 * 1024,
) -> MutationDecode {
  if record.kind != Put && record.kind != Delete {
    return mutation_result(false, "record is not a mutation")
  }
  if max_key < 0 {
    return mutation_result(false, "max key must not be negative")
  }
  if record.payload.length() < 4 {
    return mutation_result(false, "mutation payload has no key length")
  }
  let key_length_u = record.payload.unsafe_read_uint32_le(0)
  if key_length_u > max_key.reinterpret_as_uint() {
    return mutation_result(false, "mutation key exceeds configured limit")
  }
  let key_length = key_length_u.reinterpret_as_int()
  if key_length > record.payload.length() - 4 {
    return mutation_result(false, "mutation key is truncated")
  }
  if record.kind == Delete && key_length != record.payload.length() - 4 {
    return mutation_result(false, "delete payload contains trailing bytes")
  }
  let key = record.payload[4:4 + key_length].to_owned()
  let value = if record.kind == Put {
    record.payload[4 + key_length:].to_owned()
  } else {
    b""
  }
  let kind = if record.kind == Put { PutValue } else { DeleteKey }
  mutation_result(true, "mutation decoded", mutation={
    transaction: record.transaction,
    sequence: record.sequence,
    kind,
    key,
    value,
  })
}

///|
/// Encodes the highest sequence known to be durable in a checkpoint payload.
pub fn encode_checkpoint_payload(sequence : UInt) -> Bytes {
  let output = Buffer(size_hint=4)
  output.write_uint_le(sequence)
  output.to_bytes()
}

///|
fn decode_checkpoint(record : JournalRecord) -> UInt? {
  if record.kind != Checkpoint || record.payload.length() != 4 {
    return None
  }
  Some(record.payload.unsafe_read_uint32_le(0))
}

///|
fn transaction_index(active : Array[TransactionBuffer], id : UInt) -> Int {
  for index, transaction in active {
    if transaction.id == id {
      return index
    }
  }
  -1
}

///|
fn add_issue(
  issues : Array[RecoveryIssue],
  code : String,
  record : JournalRecord,
  message : String,
) -> Unit {
  issues.push({
    code,
    sequence: record.sequence,
    transaction: record.transaction,
    message,
  })
}

///|
/// Builds a replay plan. Only mutations from explicitly committed transactions
/// are returned; aborted and crash-incomplete transactions never leak through.
pub fn build_recovery_plan(
  records : Array[JournalRecord],
  max_key? : Int = 1024 * 1024,
) -> RecoveryPlan {
  let issues : Array[RecoveryIssue] = []
  let mut checkpoint_sequence = 0U
  for record in records {
    if record.kind == Checkpoint {
      match decode_checkpoint(record) {
        Some(sequence) =>
          if record.transaction != 0U {
            add_issue(
              issues, "checkpoint_transaction", record, "checkpoint must not belong to a transaction",
            )
          } else if sequence >= checkpoint_sequence &&
            sequence < record.sequence {
            checkpoint_sequence = sequence
          } else {
            add_issue(
              issues, "checkpoint_range", record, "checkpoint durable sequence is invalid",
            )
          }
        None =>
          add_issue(
            issues, "checkpoint_payload", record, "checkpoint payload must contain one uint32 sequence",
          )
      }
    }
  }
  let active : Array[TransactionBuffer] = []
  let actions : Array[Mutation] = []
  let mut committed_transactions = 0
  let mut aborted_transactions = 0
  for record in records {
    if record.sequence <= checkpoint_sequence || record.kind == Checkpoint {
      continue
    }
    if record.transaction == 0U {
      add_issue(
        issues, "missing_transaction", record, "transactional record has transaction id zero",
      )
      continue
    }
    let index = transaction_index(active, record.transaction)
    match record.kind {
      Begin =>
        if index >= 0 {
          add_issue(
            issues, "duplicate_begin", record, "transaction is already active",
          )
        } else {
          active.push({ id: record.transaction, mutations: [] })
        }
      Put | Delete =>
        if index < 0 {
          add_issue(
            issues, "orphan_mutation", record, "mutation has no active transaction",
          )
        } else {
          let decoded = decode_mutation(record, max_key~)
          match decoded.mutation {
            Some(mutation) => active[index].mutations.push(mutation)
            None =>
              add_issue(issues, "mutation_payload", record, decoded.message)
          }
        }
      Commit =>
        if index < 0 {
          add_issue(
            issues, "orphan_commit", record, "commit has no active transaction",
          )
        } else if !record.payload.is_empty() {
          add_issue(
            issues, "terminal_payload", record, "commit payload must be empty",
          )
        } else {
          for mutation in active[index].mutations {
            actions.push(mutation)
          }
          ignore(active.remove(index))
          committed_transactions += 1
        }
      Abort =>
        if index < 0 {
          add_issue(
            issues, "orphan_abort", record, "abort has no active transaction",
          )
        } else if !record.payload.is_empty() {
          add_issue(
            issues, "terminal_payload", record, "abort payload must be empty",
          )
        } else {
          ignore(active.remove(index))
          aborted_transactions += 1
        }
      Checkpoint => ()
    }
  }
  let incomplete_transactions = active.map(fn(transaction) { transaction.id })
  {
    actions,
    committed_transactions,
    aborted_transactions,
    incomplete_transactions,
    checkpoint_sequence,
    issues,
    recoverable: issues.is_empty(),
  }
}
