---
type: cast
schemaVersion: 1
cast:
- character: NARRATOR
  provider: elevenlabs
  voices:
    voxalta:
    - voices/NARRATOR.vox
    elevenlabs:
    - characters/NARRATOR.dossier/voice/NARRATOR.vox
  voiceSettings:
    elevenlabs:
      model: eleven_v4
      stability: 0.5
      similarity_boost: 0.75
- character: SIDEKICK
  voices:
    elevenlabs:
    - 21m00Tcm4TlvDq8ikWAM
---
# Cast

## Narration

### NARRATOR

ElevenLabs voice reference in both EL-3.1 forms: a `.vox` path on the narrator and a
bare voice id on the sidekick, with the nested `voiceSettings.elevenlabs` map on the narrator.
