#!/bin/bash
echo "input path to file"
pwd
ls --literal
read -r originalmp3file
echo "splitting: $originalmp3file"
mp3filename=${originalmp3file::-4}
ffmpeg -i ./"$originalmp3file" -f segment -segment_time 600 -c copy "$mp3filename"%03d.mp3
echo "#EXTM3U" > "$mp3filename".m3u
ls --format=single-column --literal | grep "^.*[000-999]\.mp3$" > "$mp3filename".m3u
echo "file split"
