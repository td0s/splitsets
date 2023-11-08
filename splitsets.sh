#!/bin/bash
echo "input path to file"
pwd
ls --literal
read -r originalmp3file
echo "splitting: $originalmp3file"
mp3filename=${originalmp3file::-4}
mkdir split
ffmpeg -i ./"$originalmp3file" -f segment -segment_time 600 -c copy "split/$mp3filename"%03d.mp3
cd split
pwd
ls
for track in *.mp3 ; do
    track_num=${track:-7:-4}
    echo "Track ${track}"
    echo "Track num $track_num"
    id3tag --song="${title}" --track=$track_num --album="${originalmp3file}" "${track}"
done

echo "file split"
