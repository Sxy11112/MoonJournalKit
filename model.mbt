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

///|
/// A committed state change reconstructed from the journal.
pub(all) enum MutationKind {
  PutValue
  DeleteKey
} derive(Debug, Eq)

///|
/// One key mutation associated with its transaction and source sequence.
pub(all) struct Mutation {
  transaction : UInt
  sequence : UInt
  kind : MutationKind
  key : Bytes
  value : Bytes
} derive(Debug, Eq)

///|
/// Bounded result of decoding a put or delete payload.
pub(all) struct MutationDecode {
  valid : Bool
  mutation : Mutation?
  message : String
} derive(Debug, Eq)

///|
/// A semantic journal problem that does not compromise byte-level framing.
pub(all) struct RecoveryIssue {
  code : String
  sequence : UInt
  transaction : UInt
  message : String
} derive(Debug, Eq)

///|
/// Deterministic replay plan produced from a trusted record prefix.
pub(all) struct RecoveryPlan {
  actions : Array[Mutation]
  committed_transactions : Int
  aborted_transactions : Int
  incomplete_transactions : Array[UInt]
  checkpoint_sequence : UInt
  issues : Array[RecoveryIssue]
  recoverable : Bool
} derive(Debug, Eq)
