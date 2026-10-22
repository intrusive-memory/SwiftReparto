// main.swift
// reparto
//
// The thin executable entry point (Sortie 17 task 7). This file constructs
// the one real OutputSink the program ever uses, hands the parsed command
// that sink, and does nothing else — no argument handling, no business
// logic, no direct writes to any stream. Every byte of actual output is
// produced by RepartoCLICore's commands through the sink they are given
// here.

import ArgumentParser
import RepartoCLICore

let sink = ConsoleOutputSink()

do {
  var command = try RepartoCommand.parseAsRoot()

  switch command {
  case var validate as ValidateCommand:
    validate.sink = sink
    command = validate
  case var importCommand as ImportCommand:
    importCommand.sink = sink
    command = importCommand
  case var canonicalize as CanonicalizeCommand:
    canonicalize.sink = sink
    command = canonicalize
  default:
    break
  }

  try command.run()
} catch {
  RepartoCommand.exit(withError: error)
}
