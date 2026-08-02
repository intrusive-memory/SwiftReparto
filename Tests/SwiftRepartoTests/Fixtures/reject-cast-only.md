---
cast:
  - character: NARRATOR
---
# Reject: cast-only

`cast:` is declared, with a real member, but `type:` is entirely absent from
the front matter.

Expected: `CastParseError.missingTypeCast`.
