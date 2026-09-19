# Datashard

Offline reader for everything written in Cyberpunk 2077 — shards, codex, emails, files, quests,
tarot, phone threads and every spoken line — in the game's pause-menu skin. Programmatic UIKit,
built and deployed from Linux with [xtool](https://github.com/xtool-org/xtool).

![Screenshots](screenshots.jpg)

Journal · Codex · Phone · Search, over a bundled SQLite export of
[cp2077-db](https://github.com/guitaripod/cp2077-db). The dataset is CD PROJEKT RED's text, so
it is generated from your own install and never committed:

```bash
cpdb build "/path/to/Cyberpunk 2077" cp2077.sqlite
cpdb cp2077.sqlite export Sources/Datashard/Resources/cp2077-reader.sqlite
xtool dev
```

GPL-3.0. Rajdhani © Indian Type Foundry, OFL 1.1.
