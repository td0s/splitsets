#!/bin/bash

# Check if a comma-separated list of URLs was passed as the first argument
if [[ -n "$1" ]]; then
  echo "Downloading files from provided URLs..."

  # Set Internal Field Separator to comma to split the input string into an array
  IFS=',' read -ra URLS <<< "$1"

  for url in "${URLS[@]}"; do
    # Trim any leading/trailing whitespace around the URL
    url=$(echo "$url" | xargs)

    # Skip empty strings
    [[ -z "$url" ]] && continue

    echo "Downloading: $url"
    curl -L -O "$url"
  done

  echo "Downloads complete."
  echo "----------------------------------------"
fi

# Loop over all audio files in the directory
for originalfile in *.mp3 *.m4a *.aac; do
  # Skip if no files match the pattern
  [ -e "$originalfile" ] || continue

  echo "Processing: $originalfile"

  # Extract base name without extension
  basefilename=$(basename "$originalfile")

  # Strip the specific prefix from the start of the filename, if it exists
  basefilename="${basefilename#Kool FM - Kool FM Podcast - }"

  filename_noext="${basefilename%.*}"

  # 1st Date Check: YYYYMMDD, YYYY-MM-DD, or YYYY_MM_DD
  # Strict bounds: Year (1000-2999), Month (01-12), Day (01-31)
  if [[ "$filename_noext" =~ ([12][0-9]{3})[-_]?(0[1-9]|1[0-2])[-_]?(0[1-9]|[12][0-9]|3[01]) ]]; then
    extracted_date="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]}"
    album_name="${extracted_date} - ${basefilename}"

  # 2nd Date Check: DD-MM-YYYY, D-M-YYYY, DD MMM YYYY, etc.
  # Captures: Day (1-31), Month (letters OR 01-12), Year (1000-2999)
  elif [[ "$filename_noext" =~ (0?[1-9]|[12][0-9]|3[01])[[:space:]_-]+([A-Za-z]+|0?[1-9]|1[0-2])[[:space:]_-]+([12][0-9]{3}) ]]; then
    raw_day="${BASH_REMATCH[1]}"
    raw_month="${BASH_REMATCH[2]}"
    year="${BASH_REMATCH[3]}"

    # Pad the day with a leading zero if it's a single digit
    printf -v day "%02d" $((10#$raw_day))

    # Check if the extracted month is purely numeric
    if [[ "$raw_month" =~ ^[0-9]+$ ]]; then
      # Pad the numeric month with a leading zero
      printf -v month "%02d" $((10#$raw_month))
    else
      # Convert the text month name to lowercase for matching
      month_lower=$(echo "$raw_month" | tr '[:upper:]' '[:lower:]')

      # Map the word month to a two-digit numeric month
      case "$month_lower" in
        jan|january)   month="01" ;;
        feb|february)  month="02" ;;
        mar|march)     month="03" ;;
        apr|april)     month="04" ;;
        may)           month="05" ;;
        jun|june)      month="06" ;;
        jul|july)      month="07" ;;
        aug|august)    month="08" ;;
        sep|september) month="09" ;;
        oct|october)   month="10" ;;
        nov|november)  month="11" ;;
        dec|december)  month="12" ;;
        *)             month="" ;; # Fallback if word isn't a real month
      esac
    fi

    # Apply the prefix only if a valid month was found
    if [[ -n "$month" ]]; then
      extracted_date="${year}-${month}-${day}"
      album_name="${extracted_date} - ${basefilename}"
    else
      album_name="${basefilename}"
    fi

  # 3rd Date Check: DDMMYY, DD-MM-YY, or DD_MM_YY
  # Strict bounds: Day (01-31), Month (01-12), Year (00-99)
  elif [[ "$filename_noext" =~ (0[1-9]|[12][0-9]|3[01])[-_]?(0[1-9]|1[0-2])[-_]?([0-9]{2}) ]]; then
    day="${BASH_REMATCH[1]}"
    month="${BASH_REMATCH[2]}"
    short_year="${BASH_REMATCH[3]}"

    # Convert 2-digit year to 4-digit year safely
    if (( 10#$short_year < 50 )); then
      year="20${short_year}"
    else
      year="19${short_year}"
    fi

    extracted_date="${year}-${month}-${day}"
    album_name="${extracted_date} - ${basefilename}"

  else
    # Fallback to just the base filename if no date pattern is found
    album_name="${basefilename}"
  fi

  # Create a dedicated output folder based on the cleaned filename
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
      id3tag --song="${track}" --track="$track_num" --album="${album_name}" "${track}"
    done
  )
done

echo "All files processed and split."