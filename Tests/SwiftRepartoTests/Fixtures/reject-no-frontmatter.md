# Not a Cast Document

This file carries no YAML front matter at all — it begins directly with a
markdown heading rather than a `---` delimited block, so nothing about it
claims to be any kind of structured document.

Expected: `CastParseError.noFrontMatter`.
