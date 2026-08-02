// SwiftReparto.swift
// SwiftReparto
//
// The cast schema for `CAST.md`: its model, its parser, its serializer, and
// its losslessness guarantees.
//
// This library owns `CAST.md` and nothing else. It never touches audio,
// images, models, or the filesystem beyond the single file it is handed, and
// it declares no dependency on any first-party org package (RQ-INV-1) so that
// every consumer relationship stays acyclic by construction.
//
// Only SwiftReparto serializes `CAST.md` (RQ-INV-2). Consumers read a
// `CastDocument`, mutate the value, and hand it back.
//
// This file is intentionally API-free. The model, the coding layer, the
// parser, and the importer all arrive in later work units.
