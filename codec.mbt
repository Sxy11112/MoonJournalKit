///|
/// Fixed wire-format version.
pub const JOURNAL_VERSION : Byte = 1

///|
/// Fixed header size in bytes.
pub const JOURNAL_HEADER_SIZE : Int = 24

///|
fn kind_code(kind : RecordKind) -> Byte {
  match kind {
    Begin => 1
    Put => 2
    Delete => 3
    Commit => 4
    Abort => 5
    Checkpoint => 6
  }
}

///|
fn kind_from_code(code : Byte) -> RecordKind? {
  match code {
    1 => Some(Begin)
    2 => Some(Put)
    3 => Some(Delete)
    4 => Some(Commit)
    5 => Some(Abort)
    6 => Some(Checkpoint)
    _ => None
  }
}

///|
/// Stable lower-case name used by reports and diagnostics.
pub fn record_kind_name(kind : RecordKind) -> String {
  match kind {
    Begin => "begin"
    Put => "put"
    Delete => "delete"
    Commit => "commit"
    Abort => "abort"
    Checkpoint => "checkpoint"
  }
}

///|
/// Creates one journal record.
pub fn JournalRecord::new(
  kind : RecordKind,
  sequence : UInt,
  transaction : UInt,
  payload? : Bytes = b"",
) -> JournalRecord {
  { kind, sequence, transaction, payload }
}

///|
/// Encoded byte size for this record.
pub fn JournalRecord::encoded_size(self : JournalRecord) -> Int {
  JOURNAL_HEADER_SIZE + self.payload.length()
}

///|
fn write_checksum_fields(buffer : Buffer, record : JournalRecord) -> Unit {
  buffer.write_byte(JOURNAL_VERSION)
  buffer.write_byte(kind_code(record.kind))
  buffer.write_byte(JOURNAL_HEADER_SIZE.to_byte())
  buffer.write_byte(0)
  buffer.write_uint_le(record.sequence)
  buffer.write_uint_le(record.transaction)
  buffer.write_uint_le(record.payload.length().reinterpret_as_uint())
}

///|
/// Encodes one checksummed record in the portable MWAL format.
pub fn encode_record(record : JournalRecord) -> Bytes {
  let checksum_input = Buffer()
  write_checksum_fields(checksum_input, record)
  checksum_input.write_bytes(record.payload)
  let checksum = crc32c(checksum_input.to_bytes())
  let output = Buffer(size_hint=record.encoded_size())
  output.write_bytes(b"MWAL")
  write_checksum_fields(output, record)
  output.write_uint_le(checksum)
  output.write_bytes(record.payload)
  output.to_bytes()
}

///|
fn result(
  status : DecodeStatus,
  next_offset : Int,
  message : String,
  record? : JournalRecord,
) -> DecodeResult {
  { status, record, next_offset, message }
}

///|
/// Decodes one record without reading beyond available bytes.
pub fn decode_record(
  data : BytesView,
  offset? : Int = 0,
  max_payload? : Int = 16 * 1024 * 1024,
) -> DecodeResult {
  if offset < 0 || offset > data.length() {
    return result(Corrupt, offset, "offset outside input")
  }
  if max_payload < 0 {
    return result(Corrupt, offset, "max payload must not be negative")
  }
  let remaining = data.length() - offset
  if remaining < JOURNAL_HEADER_SIZE {
    return result(NeedMoreData, offset, "incomplete journal header")
  }
  if !data[offset:offset + 4].equal_to_bytes(b"MWAL") {
    return result(Corrupt, offset, "journal magic mismatch")
  }
  if data[offset + 4] != JOURNAL_VERSION {
    return result(Unsupported, offset, "journal version is not supported")
  }
  guard kind_from_code(data[offset + 5]) is Some(kind) else {
    return result(Corrupt, offset, "record kind is invalid")
  }
  if data[offset + 6].to_int() != JOURNAL_HEADER_SIZE || data[offset + 7] != 0 {
    return result(Corrupt, offset, "header layout is invalid")
  }
  let sequence = data.unsafe_read_uint32_le(offset + 8)
  let transaction = data.unsafe_read_uint32_le(offset + 12)
  let payload_length_u = data.unsafe_read_uint32_le(offset + 16)
  if payload_length_u > max_payload.reinterpret_as_uint() {
    return result(Corrupt, offset, "payload exceeds configured limit")
  }
  let payload_length = payload_length_u.reinterpret_as_int()
  if payload_length > remaining - JOURNAL_HEADER_SIZE {
    return result(NeedMoreData, offset, "incomplete journal payload")
  }
  let next_offset = offset + JOURNAL_HEADER_SIZE + payload_length
  let stored_checksum = data.unsafe_read_uint32_le(offset + 20)
  let checksum_input = Buffer(size_hint=16 + payload_length)
  checksum_input.write_bytes(data[offset + 4:offset + 20])
  checksum_input.write_bytes(data[offset + 24:next_offset])
  if crc32c(checksum_input.to_bytes()) != stored_checksum {
    return result(Corrupt, offset, "record checksum mismatch")
  }
  let record = JournalRecord::new(
    kind,
    sequence,
    transaction,
    payload=data[offset + 24:next_offset].to_owned(),
  )
  result(Decoded, next_offset, "record decoded", record~)
}
