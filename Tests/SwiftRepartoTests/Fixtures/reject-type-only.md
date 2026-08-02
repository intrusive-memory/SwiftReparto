---
type: cast
---
# Reject: type-only

`type: cast` is declared, but `cast:` is entirely absent — not present with a
null value, just missing from the front matter altogether.

Expected: `CastParseError.missingCastKey`.
