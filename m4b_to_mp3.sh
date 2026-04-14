#!/bin/bash

set -euo pipefail

read -e -p "Enter path to .m4b file: " INPUT_PATH
INPUT_PATH="${INPUT_PATH/#\~/$HOME}"

if [[ ! -f "$INPUT_PATH" ]]; then
    echo "File not found."
    exit 1
fi

# Get playback speed
read -p "Enter playback speed (1.0 - 2.0): " ATEMPO

# Validate tempo
if ! awk -v t="$ATEMPO" 'BEGIN { exit !(t >= 1.0 && t <= 2.0) }'; then
    echo "Invalid tempo. Must be between 1.0 and 2.0."
    exit 1
fi

# Parallelism (tuned for 4–8 core machines)
MAX_JOBS=6

BASENAME="$(basename "$INPUT_PATH" .m4b)"
OUTPUT_DIR="./converted/${BASENAME} Chapters"
mkdir -p "$OUTPUT_DIR"

CHAPTER_FILE="$OUTPUT_DIR/chapters.txt"

# Extract artist
ARTIST=$(ffprobe -v error -show_entries format_tags=artist \
    -of default=noprint_wrappers=1:nokey=1 "$INPUT_PATH")

# Extract chapter data
ffprobe -v error -show_entries "chapter=start_time,end_time:chapter_tags=title" \
    -of csv=p=0 "$INPUT_PATH" | awk -F, '{
        start = $1
        end = $2
        title = ""
        for (i = 3; i <= NF; i++) {
            title = title (i > 3 ? "," : "") $i
        }
        printf "%s,%s,%s\n", start, end, title
    }' > "$CHAPTER_FILE"

echo "Chapter file written to: $CHAPTER_FILE"

COUNT=1
JOB_COUNT=0

exec 3< "$CHAPTER_FILE"
while IFS=',' read -r START END TITLE <&3; do
    [[ -z "$START" || -z "$END" ]] && continue

    START="${START//$'\r'/}"
    END="${END//$'\r'/}"
    TITLE="${TITLE//$'\r'/}"

    [[ -z "$TITLE" ]] && TITLE="Chapter $COUNT"

    SAFE_TITLE="${TITLE//[\/:\\*?\"<>|]/}"

    # Adjust timestamps for tempo
    ADJ_START=$(awk -v s="$START" -v t="$ATEMPO" 'BEGIN { printf "%.6f", s / t }')
    ADJ_END=$(awk -v e="$END" -v t="$ATEMPO" 'BEGIN { printf "%.6f", e / t }')

    OUTFILE="$OUTPUT_DIR/$(printf "%03d" $COUNT) - ${SAFE_TITLE}.mp3"

    echo "Queueing: $TITLE"

    (
        ffmpeg -v error \
            -i "$INPUT_PATH" \
            -ss "$ADJ_START" \
            -to "$ADJ_END" \
            -c:a libmp3lame \
            -q:a 6 \
            -vn \
            -af "atempo=$ATEMPO" \
            -avoid_negative_ts make_zero \
            -metadata album="$BASENAME" \
            -metadata title="$TITLE" \
            -metadata track="$COUNT" \
            -metadata artist="$ARTIST" \
            -metadata album_artist="$ARTIST" \
            "$OUTFILE"

        echo "Finished: $(basename "$OUTFILE")"
    ) &

    ((JOB_COUNT++))
    ((COUNT++))

    # Throttle concurrency
    while (( $(jobs -rp | wc -l) >= MAX_JOBS )); do
        sleep 0.2
    done

done

exec 3<&-

# Wait for all remaining jobs
wait

echo "Done. $((COUNT-1)) chapters saved to: $OUTPUT_DIR"
