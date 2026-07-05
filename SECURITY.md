# Security Policy

Please report denial-of-service risks, bounds-check failures, checksum bypasses,
or cases where uncommitted data can replay through a private repository security
advisory. Do not include sensitive production journals in a public issue.

CRC32C detects accidental corruption; it is not authentication. Applications
that process hostile logs should add a MAC or signature outside MWAL v1 and set
strict `max_payload`, `max_key`, and `max_records` limits.

The maintained release line is `0.1.x`.
