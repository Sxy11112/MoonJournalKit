///|
/// Semantic record kinds supported by the transactional journal.
pub(all) enum RecordKind {
  Begin
  Put
  Delete
  Commit
  Abort
  Checkpoint
} derive(Debug, Eq)

///|
/// One decoded journal record.
pub(all) struct JournalRecord {
  kind : RecordKind
  sequence : UInt
  transaction : UInt
  payload : Bytes
} derive(Debug, Eq)

///|
/// Outcome category for bounded, non-throwing record decoding.
pub(all) enum DecodeStatus {
  Decoded
  NeedMoreData
  Corrupt
  Unsupported
} derive(Debug, Eq)

///|
/// Result of decoding one record at a byte offset.
pub(all) struct DecodeResult {
  status : DecodeStatus
  record : JournalRecord?
  next_offset : Int
  message : String
} derive(Debug, Eq)

///|
/// Why a journal scan stopped.
pub(all) enum ScanStop {
  CleanEnd
  TruncatedTail
  Corruption
  UnsupportedVersion
  SequenceViolation
  RecordLimit
} derive(Debug, Eq)

///|
/// Result of scanning a byte stream up to its last trusted boundary.
pub(all) struct ScanResult {
  records : Array[JournalRecord]
  valid_bytes : Int
  total_bytes : Int
  stop : ScanStop
  fault_offset : Int
  message : String
} derive(Debug, Eq)
