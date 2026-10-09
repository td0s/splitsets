# splitsets

Splits long audio sets (`.mp3`, `.m4a`, `.aac`) in the current directory into
10-minute MP3 chunks and tags each chunk with a track number and album name.

## Usage

```sh
nix develop            # or install curl, ffmpeg and id3lib (for id3tag) yourself
./splitsets.sh                              # split the audio files already here
./splitsets.sh "https://a/x.m4a, https://b/y.mp3"   # download these first, then split
```

Downloaded files are named after the last part of the URL, with
percent-encoding decoded (`My%20Set.m4a` becomes `My Set.m4a`).

## Output

Each input `name.ext` becomes `split/name/name_001.mp3`, `name_002.mp3`, ...
MP3 input is copied without re-encoding; AAC/M4A input is converted to MP3.

- **Track**: chunk number, starting at 1
- **Title**: chunk filename without `.mp3`
- **Album**: `YYYY-MM-DD - name` when a date is found in the filename,
  just `YYYY-MM-DD` when the name is only a date, otherwise `name`

Recognised dates: `YYYYMMDD`, `YYYY-MM-DD`, `DD-MM-YYYY`, `D M YYYY`,
`15 March 2024`, `15 mar 2024`, `DDMMYYYY`, `DDMMYY`, `DD-MM-YY`
(separators can be `-`, `_` or spaces).

If `split/name` already exists the file is skipped; delete that folder to split it again.
