///|
/// A bounded incremental decoder for append-only journal byte streams.
///
/// Feed arbitrary chunks from an I/O adapter. Complete records are emitted once,
/// while a partial final record remains buffered for the next chunk. The core
/// never opens files or browser storage itself.
pub(all) struct StreamJournalDecoder {
  strict_sequence : Bool
  max_payload : Int
  max_buffered : Int
  mut pending : Bytes
  mut previous_sequence : UInt
} derive(Debug, Eq)

///|
/// Result of one incremental decode operation.
pub(all) struct StreamFeedResult {
  records : Array[JournalRecord]
  buffered_bytes : Int
  stop : ScanStop?
  message : String
} derive(Debug, Eq)

///|
pub fn StreamJournalDecoder::new(
  strict_sequence? : Bool = true,
  max_payload? : Int = 16 * 1024 * 1024,
  max_buffered? : Int = 16 * 1024 * 1024,
) -> StreamJournalDecoder {
  {
    strict_sequence,
    max_payload: if max_payload < 0 {
      0
    } else {
      max_payload
    },
    max_buffered: if max_buffered < 0 {
      0
    } else {
      max_buffered
    },
    pending: b"",
    previous_sequence: 0U,
  }
}

///|
fn append_chunk(left : Bytes, right : BytesView) -> Bytes {
  let output = Buffer(size_hint=left.length() + right.length())
  output.write_bytes(left)
  output.write_bytes(right)
  output.to_bytes()
}

///|
pub fn StreamJournalDecoder::buffered_bytes(self : StreamJournalDecoder) -> Int {
  self.pending.length()
}

///|
pub fn StreamJournalDecoder::reset(self : StreamJournalDecoder) -> Unit {
  self.pending = b""
  self.previous_sequence = 0U
}

///|
/// Decodes complete records without retaining previously emitted records.
pub fn StreamJournalDecoder::feed(
  self : StreamJournalDecoder,
  chunk : BytesView,
) -> StreamFeedResult {
  let input = append_chunk(self.pending, chunk)
  let records : Array[JournalRecord] = []
  let mut offset = 0
  while offset < input.length() {
    let decoded = decode_record(input, offset~, max_payload=self.max_payload)
    match decoded.status {
      NeedMoreData => {
        self.pending = input[offset:input.length()].to_owned()
        if self.pending.length() > self.max_buffered {
          return {
            records,
            buffered_bytes: self.pending.length(),
            stop: Some(RecordLimit),
            message: "partial record exceeds configured stream buffer",
          }
        }
        return {
          records,
          buffered_bytes: self.pending.length(),
          stop: None,
          message: "waiting for a complete record",
        }
      }
      Corrupt =>
        return {
          records,
          buffered_bytes: input.length() - offset,
          stop: Some(Corruption),
          message: decoded.message,
        }
      Unsupported =>
        return {
          records,
          buffered_bytes: input.length() - offset,
          stop: Some(UnsupportedVersion),
          message: decoded.message,
        }
      Decoded => {
        guard decoded.record is Some(record) else {
          return {
            records,
            buffered_bytes: input.length() - offset,
            stop: Some(Corruption),
            message: "decoder returned no record",
          }
        }
        if record.sequence == 0U ||
          (
            self.previous_sequence > 0U &&
            (
              record.sequence <= self.previous_sequence ||
              (
                self.strict_sequence &&
                record.sequence != self.previous_sequence + 1U
              )
            )
          ) {
          return {
            records,
            buffered_bytes: input.length() - offset,
            stop: Some(SequenceViolation),
            message: "stream record sequence is invalid",
          }
        }
        records.push(record)
        self.previous_sequence = record.sequence
        offset = decoded.next_offset
      }
    }
  }
  self.pending = b""
  {
    records,
    buffered_bytes: 0,
    stop: None,
    message: "chunk ended at a record boundary",
  }
}
