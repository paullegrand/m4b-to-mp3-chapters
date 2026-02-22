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

# Extract artist from source file
ARTIST=$(ffprobe -v error -show_entries format_tags=artist \
    -of default=noprint_wrappers=1:nokey=1 "$INPUT_PATH")

# Extract START, END, and TITLE from ffprobe
ffprobe -v error -show_entries "chapter=start_time,end_time:chapter_tags=title" \
    -of csv=p=0 "$INPUT_PATH" | awk -F, '{
        start = $1
        end = $2
        # Rejoin remaining fields as title (in case title contains commas)
        title = ""
        for (i = 3; i <= NF; i++) {
            title = title (i > 3 ? "," : "") $i
        }
        printf "%s,%s,%s\n", start, end, title
    }' > "$CHAPTER_FILE"

echo "Chapter file written to: $CHAPTER_FILE"

if [[ ! -f "$CHAPTER_FILE" ]]; then
    echo "Chapter file not found: $CHAPTER_FILE"
    exit 1
fi

COUNT=1

exec 3< "$CHAPTER_FILE"
while IFS=',' read -r START END TITLE <&3; do
    [[ -z "$START" || -z "$END" ]] && continue

    START="${START//$'\r'/}"
    END="${END//$'\r'/}"
    TITLE="${TITLE//$'\r'/}"

    # Fall back to "Chapter N" if title is empty
    [[ -z "$TITLE" ]] && TITLE="Chapter $COUNT"

    # Sanitize title for use in filename
    SAFE_TITLE="${TITLE//[\/:\\*?\"<>|]/}"

    OUTFILE="$OUTPUT_DIR/$(printf "%03d" $COUNT) - ${SAFE_TITLE}.mp3"
    echo "Creating: $TITLE (Start: $START, End: $END)..."

    ffmpeg -v error \
        -i "$INPUT_PATH" \
        -ss "$START" \
        -to "$END" \
        -c:a libmp3lame \
        -q:a 6 \
        -vn \
        -metadata album="$BASENAME" \
        -metadata title="$TITLE" \
        -metadata track="$COUNT" \
        -metadata artist="$ARTIST" \
        -metadata album_artist="$ARTIST" \
        "$OUTFILE"

    ((COUNT++))
done

exec 3<&-
echo "Done. $((COUNT-1)) chapters saved to: $OUTPUT_DIR"