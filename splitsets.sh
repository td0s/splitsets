#!/bin/bash

# Loop over all audio files in the directory
for originalfile in *.mp3 *.m4a *.aac; do
  # Skip if no files match the pattern
  [ -e "$originalfile" ] || continue

  echo "Processing: $originalfile"

  # Extract base name without extension
  basefilename=$(basename "$originalfile")
  filename_noext="${basefilename%.*}"

  # Create a dedicated output folder
  outdir="split/${filename_noext}"
  mkdir -p "$outdir"

  # If input is mp3, we can copy without re-encoding
  if [[ "$originalfile" == *.mp3 ]]; then
    codec="-c copy"
  else
    # Convert to mp3 if aac/m4a
    codec="-c:a libmp3lame -q:a 2"
  fi

  # Split into 10-minute chunks
  ffmpeg -i "$originalfile" -f segment -segment_time 600 $codec \
    "${outdir}/${filename_noext}_%03d.mp3"

  # Process ID3 tags for each track
  (
    cd "$outdir" || exit
    for track in *.mp3; do
      track_num=${track: -7:3}
      echo "Tagging track: $track (Track $track_num)"
      id3tag --song="${track}" --track="$track_num" --album="${basefilename}" "${track}"
    done
  )
done

echo "All files processed and split."

