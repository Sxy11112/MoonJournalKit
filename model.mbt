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
