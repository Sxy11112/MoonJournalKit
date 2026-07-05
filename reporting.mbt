///|
fn scan_stop_name(stop : ScanStop) -> String {
  match stop {
    CleanEnd => "clean_end"
    TruncatedTail => "truncated_tail"
    Corruption => "corruption"
    UnsupportedVersion => "unsupported_version"
    SequenceViolation => "sequence_violation"
    RecordLimit => "record_limit"
  }
}

///|
fn json_escape(value : String) -> String {
  let output = StringBuilder(size_hint=value.length())
  for index = 0; index < value.length(); index = index + 1 {
    match value.unsafe_get(index) {
      '"' => output.write_string("\\\"")
      '\\' => output.write_string("\\\\")
      '\n' => output.write_string("\\n")
      '\r' => output.write_string("\\r")
      '\t' => output.write_string("\\t")
      unit => output.write_char(unit.to_int().unsafe_to_char())
    }
  }
  output.to_string()
}

///|
/// Stable machine-readable scan summary.
pub fn ScanResult::to_json(self : ScanResult) -> String {
  "{\"records\":\{self.records.length()},\"valid_bytes\":\{self.valid_bytes},\"total_bytes\":\{self.total_bytes},\"stop\":\"\{scan_stop_name(self.stop)}\",\"fault_offset\":\{self.fault_offset},\"message\":\"\{json_escape(self.message)}\"}"
}

///|
fn uint_array_json(values : Array[UInt]) -> String {
  let output = StringBuilder()
  output.write_char('[')
  for index, value in values {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(value.to_string())
  }
  output.write_char(']')
  output.to_string()
}

///|
fn issues_json(issues : Array[RecoveryIssue]) -> String {
  let output = StringBuilder()
  output.write_char('[')
  for index, issue in issues {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(
      "{\"code\":\"\{json_escape(issue.code)}\",\"sequence\":\{issue.sequence},\"transaction\":\{issue.transaction},\"message\":\"\{json_escape(issue.message)}\"}",
    )
  }
  output.write_char(']')
  output.to_string()
}

///|
/// Stable machine-readable recovery summary and diagnostics.
pub fn RecoveryPlan::to_json(self : RecoveryPlan) -> String {
  "{\"recoverable\":\{self.recoverable},\"checkpoint_sequence\":\{self.checkpoint_sequence},\"actions\":\{self.actions.length()},\"committed_transactions\":\{self.committed_transactions},\"aborted_transactions\":\{self.aborted_transactions},\"incomplete_transactions\":\{uint_array_json(self.incomplete_transactions)},\"issues\":\{issues_json(self.issues)}}"
}

///|
/// Stable machine-readable crash-cut verification evidence.
pub fn CrashSweepReport::to_json(self : CrashSweepReport) -> String {
  "{\"cuts_checked\":\{self.cuts_checked},\"exact_prefixes\":\{self.exact_prefixes},\"unsafe_replays\":\{self.unsafe_replays},\"passed\":\{self.passed}}"
}

///|
/// Stable machine-readable corruption verification evidence.
pub fn CorruptionSweepReport::to_json(self : CorruptionSweepReport) -> String {
  "{\"bits_checked\":\{self.bits_checked},\"corruptions_detected\":\{self.corruptions_detected},\"undetected\":\{self.undetected},\"passed\":\{self.passed}}"
}
