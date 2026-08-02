---
type: cast
schemaVersion: 2
cast:
  - character: NARRATOR
    actor: Tom Stovall
---
# Reject: future schema version

Otherwise well-formed — `type: cast` and a real `cast:` array with one valid
member — but `schemaVersion: 2` declares a schema newer than this build
supports (D-12). The version gate must fire before this build attempts to
interpret any key whose meaning a future schema may have redefined, on a
document that would otherwise parse cleanly.

Expected: `CastParseError.unsupportedSchemaVersion(found: 2, supported: 1)`.
