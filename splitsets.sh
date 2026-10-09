#!/bin/bash

# Make sure the tools we rely on are installed
for cmd in curl ffmpeg id3tag; do
  if ! command -v "$cmd" >/dev/null; then
    echo "Error: '$cmd' is not installed." >&2
    exit 1
  fi
done

# Globs with no matches expand to nothing, and regex/case matches ignore case
shopt -s nullglob nocaseglob nocasematch

# Check if a comma-separated list of URLs was passed as the first argument
if [[ -n "$1" ]]; then
  echo "Downloading files from provided URLs..."

  # Set Internal Field Separator to comma to split the input string into an array
  IFS=',' read -ra URLS <<< "$1"

  for url in "${URLS[@]}"; do
    # Trim any leading/trailing whitespace around the URL
    url="${url#"${url%%[![:space:]]*}"}"
    url="${url%"${url##*[![:space:]]}"}"

    # Skip empty strings
    [[ -z "$url" ]] && continue

    # Name the file after the last part of the URL path, without any query
    # string, with percent-encoding decoded and no slashes left in it
    outname="${url%%[?#]*}"
    outname="${outname##*/}"
    printf -v outname '%b' "${outname//%/\\x}"
    outname="${outname//\//_}"

    if [[ -z "$outname" ]]; then
      echo "Skipping (no filename in URL): $url" >&2
      continue
    fi

    echo "Downloading: $url"
    if ! curl -fL -o "$outname" "$url"; then
      echo "Download failed: $url" >&2
      rm -f "$outname"
    fi
  done

  echo "Downloads complete."
  echo "----------------------------------------"
fi

# Loop over all audio files in the directory
for originalfile in *.mp3 *.m4a *.aac; do
  echo "Processing: $originalfile"

  filename_noext="${originalfile%.*}"
  extracted_date=""

  # 1st Date Check: YYYYMMDD, YYYY-MM-DD, or YYYY_MM_DD
  # Strict bounds: Year (1000-2999), Month (01-12), Day (01-31)
  if [[ "$filename_noext" =~ (^|[^0-9])([12][0-9]{3})[-_]?(0[1-9]|1[0-2])[-_]?(0[1-9]|[12][0-9]|3[01])([^0-9]|$) ]]; then
    extracted_date="${BASH_REMATCH[2]}-${BASH_REMATCH[3]}-${BASH_REMATCH[4]}"
    matched="${BASH_REMATCH[0]}"

  # 2nd Date Check: DD-MM-YYYY, D-M-YYYY, DD MMM YYYY, etc.
  # Captures: Day (1-31), Month (month name OR 1-12), Year (1000-2999)
  elif [[ "$filename_noext" =~ (^|[^0-9])(0?[1-9]|[12][0-9]|3[01])[[:space:]_-]+(january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sept|sep|october|oct|november|nov|december|dec|0?[1-9]|1[0-2])[[:space:]_-]+([12][0-9]{3})([^0-9]|$) ]]; then
    raw_day="${BASH_REMATCH[2]}"
    raw_month="${BASH_REMATCH[3]}"
    year="${BASH_REMATCH[4]}"
    matched="${BASH_REMATCH[0]}"

    # Pad the day with a leading zero if it's a single digit
    printf -v day "%02d" $((10#$raw_day))

    # Map a month name to a two-digit numeric month (matched case-insensitively)
    case "${raw_month:0:3}" in
      jan) month="01" ;;
      feb) month="02" ;;
      mar) month="03" ;;
      apr) month="04" ;;
      may) month="05" ;;
      jun) month="06" ;;
      jul) month="07" ;;
      aug) month="08" ;;
      sep) month="09" ;;
      oct) month="10" ;;
      nov) month="11" ;;
      dec) month="12" ;;
      *)   printf -v month "%02d" $((10#$raw_month)) ;;
    esac

    extracted_date="${year}-${month}-${day}"

  # 3rd Date Check: DDMMYYYY, DDMMYY, DD-MM-YY, DD_MM_YY, etc.
  # Strict bounds: Day (01-31), Month (01-12), Year (1000-2999 or 00-99)
  elif [[ "$filename_noext" =~ (^|[^0-9])(0[1-9]|[12][0-9]|3[01])[-_]?(0[1-9]|1[0-2])[-_]?([12][0-9]{3}|[0-9]{2})([^0-9]|$) ]]; then
    day="${BASH_REMATCH[2]}"
    month="${BASH_REMATCH[3]}"
    year="${BASH_REMATCH[4]}"
    matched="${BASH_REMATCH[0]}"

    # Convert 2-digit year to 4-digit year safely
    if (( ${#year} == 2 )); then
      if (( 10#$year < 50 )); then
        year="20${year}"
      else
        year="19${year}"
      fi
    fi

    extracted_date="${year}-${month}-${day}"
  fi

  # Album is "date - name", or just the date if the name is nothing but the date
  if [[ -z "$extracted_date" ]]; then
    album_name="${filename_noext}"
  elif [[ "${filename_noext/"$matched"/}" =~ [[:alnum:]] ]]; then
    album_name="${extracted_date} - ${filename_noext}"
  else
    album_name="${extracted_date}"
  fi

  # Create a dedicated output folder based on the filename. If it already
  # exists, this file was split before (or shares its name with another file)
  outdir="split/${filename_noext}"
  if [[ -e "$outdir" ]]; then
    echo "Skipping: $outdir already exists (delete it to split again)"
    continue
  fi
  mkdir -p "$outdir"

  # If input is mp3, we can copy without re-encoding
  if [[ "$originalfile" == *.mp3 ]]; then
    codec=(-c copy)
  else
    # Convert to mp3 if aac/m4a
    codec=(-c:a libmp3lame -q:a 2)
  fi

  # Split the audio (ignoring any cover art) into 10-minute chunks numbered from 1
  if ! ffmpeg -nostdin -i "$originalfile" -map 0:a -f segment -segment_time 600 \
      -segment_start_number 1 "${codec[@]}" "${outdir}/${filename_noext//%/%%}_%03d.mp3"; then
    echo "ffmpeg failed on: $originalfile" >&2
    rm -rf "$outdir"
    continue
  fi

  # Process ID3 tags for each track
  (
    cd "$outdir" || exit
    for track in *.mp3; do
      track_num=$((10#${track: -7:3}))
      echo "Tagging track: $track (Track $track_num)"
      id3tag --song="${track%.mp3}" --track="$track_num" --album="${album_name}" "${track}"
    done
  )
done

echo "All files processed and split."
