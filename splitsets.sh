#!/bin/bash
echo "input path to file"
pwd

read -r originalmp3file
echo "splitting: $originalmp3file"
mp3filename=${originalmp3file::-4}
ffmpeg -i ./"$originalmp3file" -f segment -segment_time 600 -c copy "$mp3filename"%03d.mp3
echo "file split"
