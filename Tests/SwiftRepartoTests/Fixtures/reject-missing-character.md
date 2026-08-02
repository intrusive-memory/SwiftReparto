---
type: cast
cast:
  - actor: Nobody In Particular
---
# Reject: missing character

`type: cast` and `cast:` are both present, and the roster has one member —
but that member has no `character` field, which RQ-12 requires.

Expected: `CastParseError.missingCharacter(index: 0)`.
