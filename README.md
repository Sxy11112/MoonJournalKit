# MoonJournalKit

## Install and stream recovery

```bash
moon add Sxy11112/moonjournalkit
```

```mbt check
import {
  "Sxy11112/moonjournalkit" @journal,
}

///|
test {
  let decoder = @journal.StreamJournalDecoder::new(max_buffered=4096)
  let outcome = decoder.feed(b"")
  // Persist only complete records from outcome.records; retain the decoder for
  // its bounded partial tail.
  assert_true(outcome.stop is None)
}
```

The core accepts byte chunks only. A Native file adapter or browser storage
adapter owns reading, writing, flush ordering, and truncation; MoonJournalKit
owns portable framing, integrity, sequence, and recovery semantics.

