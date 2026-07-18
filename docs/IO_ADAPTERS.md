# I/O adapter contract

MoonJournalKit deliberately has no filesystem, socket, browser, or async-runtime
dependency. Applications provide bytes to `StreamJournalDecoder` and persist
bytes returned by `encode_record` or `encode_records`.

## Required ordering

1. Encode a record and append its complete bytes through the platform adapter.
2. Apply the adapter's required durability barrier before exposing `Commit` as
   durable to callers.
3. On startup, feed chunks in order to one decoder instance.
4. Trust only emitted records. A non-empty decoder tail is not a valid record.
5. If recovery chooses truncation, truncate at the last trusted byte boundary
   reported by a complete scan or adapter-maintained offset.

## Limits

Set `max_payload` and `max_buffered` for the deployment. A stream decoder
returns `RecordLimit` when an incomplete tail exceeds its configured bound.
CRC32C detects accidental corruption, not adversarial tampering. The library
does not supply consensus, replication, encryption, locking, or fsync itself.
