#!/bin/bash

read -e -p "Enter path to .m4b file: " INPUT_PATH
INPUT_PATH="${INPUT_PATH/#\~/$HOME}"

if [[ ! -f "$INPUT_PATH" ]]; then
    echo "File not found."
    exit 1
fi

BASENAME="$(basename "$INPUT_PATH" .m4b)"
OUTPUT_DIR="./converted/${BASENAME} Chapters"
mkdir -p "$OUTPUT_DIR"

CHAPTER_FILE="$OUTPUT_DIR/chapters.txt"

# Extract START and END from ffprobe, convert to seconds with 3 decimals
ffprobe -v error -show_entries chapter=start_time,end_time \
    -of csv=p=0 "$INPUT_PATH" | awk -F, '{printf "%.3f,%.3f\n", $1, $2}' > "$CHAPTER_FILE"

echo "Simple chapters file written to: $CHAPTER_FILE"

if [[ ! -f "$CHAPTER_FILE" ]]; then
    echo "Chapter file not found: $CHAPTER_FILE"
    exit 1
fi

COUNT=1

# Use while read safely
# Use a while + IFS read directly on file descriptor 3
exec 3< "$CHAPTER_FILE"
while IFS=',' read -r START END <&3; do
    # Skip empty lines
    [[ -z "$START" || -z "$END" ]] && continue

    # Remove any stray whitespace or carriage returns
    START="${START//$'\r'/}"
    END="${END//$'\r'/}"

    OUTFILE="$OUTPUT_DIR/chapter_$(printf "%03d" $COUNT).mp3"
    echo "Creating Chapter $COUNT (Start: $START, End: $END)..."

    ffmpeg -v error \
        -i "$INPUT_PATH" \
        -ss "$START" \
        -to "$END" \
        -c:a libmp3lame \
        -q:a 2 \
        -vn \
        "$OUTFILE"

    ((COUNT++))
done

exec 3<&-
echo "Done. Files saved to: $OUTPUT_DIR"
