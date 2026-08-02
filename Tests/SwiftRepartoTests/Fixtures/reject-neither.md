---
title: Untitled Notes
author: Tom Stovall
date: 2026-08-01
---
# Reject: neither key

Plausible, real front-matter keys — `title`, `author`, `date` — but neither
`type:` nor `cast:`. This is the arbitrary-prose case RQ-1's dual check exists
to reject: a document with well-formed YAML front matter that simply is not
about a cast at all.

Expected: `CastParseError.missingTypeCast` (the `type:` check runs before the
`cast:` check).
