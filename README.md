# Datashard

Offline reader for everything written in Cyberpunk 2077 — shards, net pages, codex, emails,
files, quests, tarot, phone threads and every spoken line, with the game's codex art, tarot
cards and contact avatars — in the game's pause-menu skin. Programmatic UIKit, built and deployed
with [xtool](https://github.com/xtool-org/xtool), no Xcode project.

![Screenshots](screenshots.jpg)

Journal · Codex · Phone · Search, over a bundled SQLite export of
[cp2077-db](https://github.com/guitaripod/cp2077-db). The dataset is CD PROJEKT RED's text, so
it is generated from your own install and never committed:

```bash
cpdb build "/path/to/Cyberpunk 2077" cp2077.sqlite --images
cpdb cp2077.sqlite export Sources/Datashard/Resources/cp2077-reader.sqlite
xtool dev
```

On a Mac, `brew install xtool`, run `xtool setup` once, plug the phone in and run
`scripts/install-mac.sh` instead of `xtool dev`. It builds, signs, installs and launches, and
works around xtool not yet reading Xcode 26.4's SwiftPM layout. Building the dataset needs
Linux; the export it writes is plain SQLite, so copy one in and the Mac needs nothing else.

GPL-3.0. Rajdhani © Indian Type Foundry, OFL 1.1.
