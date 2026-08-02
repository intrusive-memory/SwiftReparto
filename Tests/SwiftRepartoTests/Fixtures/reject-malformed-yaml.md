---
type: cast
cast: [a, b
---
# Reject: malformed YAML

The front matter's `cast:` value opens a flow sequence with `[` and never
closes it before the closing `---` delimiter, so the block between the
delimiters is not valid YAML.

Expected: `CastParseError.invalidYAML(_:)` — asserted by case only, since the
underlying parser's message text is not pinned.
