///|
/// Encodes records in input order into one journal byte stream.
pub fn encode_records(records : Array[JournalRecord]) -> Bytes {
  let total = records.fold(init=0, fn(size, record) {
    size + record.encoded_size()
  })
  let buffer = Buffer(size_hint=total)
  for record in records {
    buffer.write_bytes(encode_record(record))
  }
  buffer.to_bytes()
}

///|
/// Scans records without accepting bytes after the first invalid boundary.
pub fn scan_journal(
  data : BytesView,
  strict_sequence? : Bool = true,
  max_payload? : Int = 16 * 1024 * 1024,
  max_records? : Int = 1000000,
) -> ScanResult {
  if max_records < 0 {
    return {
      records: [],
      valid_bytes: 0,
      total_bytes: data.length(),
      stop: RecordLimit,
      fault_offset: 0,
      message: "max records must not be negative",
    }
  }
  let records : Array[JournalRecord] = []
  let mut offset = 0
  let mut previous_sequence = 0U
  while offset < data.length() {
    if records.length() >= max_records {
      return {
        records,
        valid_bytes: offset,
        total_bytes: data.length(),
        stop: RecordLimit,
        fault_offset: offset,
        message: "record limit reached",
      }
    }
    let decoded = decode_record(data, offset~, max_payload~)
    match decoded.status {
      NeedMoreData =>
        return {
          records,
          valid_bytes: offset,
          total_bytes: data.length(),
          stop: TruncatedTail,
          fault_offset: offset,
          message: decoded.message,
        }
      Corrupt =>
        return {
          records,
          valid_bytes: offset,
          total_bytes: data.length(),
          stop: Corruption,
          fault_offset: offset,
          message: decoded.message,
        }
      Unsupported =>
        return {
          records,
          valid_bytes: offset,
          total_bytes: data.length(),
          stop: UnsupportedVersion,
          fault_offset: offset,
          message: decoded.message,
        }
      Decoded => {
        guard decoded.record is Some(record) else {
          return {
            records,
            valid_bytes: offset,
            total_bytes: data.length(),
            stop: Corruption,
            fault_offset: offset,
            message: "decoder returned no record",
          }
        }
        if record.sequence == 0U {
          return {
            records,
            valid_bytes: offset,
            total_bytes: data.length(),
            stop: SequenceViolation,
            fault_offset: offset,
            message: "record sequence must be positive",
          }
        }
        if previous_sequence > 0U {
          if record.sequence <= previous_sequence {
            return {
              records,
              valid_bytes: offset,
              total_bytes: data.length(),
              stop: SequenceViolation,
              fault_offset: offset,
              message: "record sequence did not increase",
            }
          }
          if strict_sequence && record.sequence != previous_sequence + 1U {
            return {
              records,
              valid_bytes: offset,
              total_bytes: data.length(),
              stop: SequenceViolation,
              fault_offset: offset,
              message: "record sequence has a gap",
            }
          }
        }
        records.push(record)
        previous_sequence = record.sequence
        offset = decoded.next_offset
      }
    }
  }
  {
    records,
    valid_bytes: offset,
    total_bytes: data.length(),
    stop: CleanEnd,
    fault_offset: offset,
    message: "journal ended at a valid record boundary",
  }
}

///|
/// Returns the trusted prefix suitable for crash-tail truncation.
pub fn ScanResult::valid_prefix(self : ScanResult, data : BytesView) -> Bytes {
  let end = if self.valid_bytes < data.length() {
    self.valid_bytes
  } else {
    data.length()
  }
  data[0:end].to_owned()
}
