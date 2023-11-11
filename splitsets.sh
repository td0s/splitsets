#!/bin/bash
for originalmp3file in *.mp3; do
  echo "splitting: $originalmp3file"
  mp3filename=${originalmp3file::-4}
  mkdir mp3filename
  ffmpeg -i ./"$originalmp3file" -f segment -segment_time 600 -c copy "split/$mp3filename"%03d.mp3
  # shellcheck disable=SC2164
  (
    cd mp3filename || exit
    pwd
    ls
    for track in *.mp3 ; do
        track_num=${track:${#track}-7:3}
        echo "Track ${track}"
        echo "Track num $track_num"
        id3tag --song="${track}" --track="$track_num" --album="${originalmp3file}" "${track}"
    done
  )
done

echo "files split"
