#!/bin/bash

# Define temporary files
TEMP_IMAGE=$(mktemp --suffix=.png)
SHADOWED_IMAGE=$(mktemp --suffix=.png)
MASK_IMAGE=$(mktemp --suffix=.png)
GRADIENT_IMAGE=$(mktemp --suffix=.png)
FINAL_IMAGE=$(mktemp --suffix=.png)

# Grab the clipboard image
wl-paste --type image/png > "$TEMP_IMAGE"

# Extract standout colors (3 dominant colors)
COLORS=$(magick "$TEMP_IMAGE" -colors 3 -unique-colors txt: | grep -oP '#[0-9A-Fa-f]{6}')
COLOR1=$(echo "$COLORS" | head -n 1)
COLOR2=$(echo "$COLORS" | tail -n 1 | head -n 1)
COLOR3=$(echo "$COLORS" | tail -n 1)

# Get original image dimensions
WIDTH=$(magick identify -format "%w" "$TEMP_IMAGE")
HEIGHT=$(magick identify -format "%h" "$TEMP_IMAGE")

# Create a gradient background with the specified colors
MARGIN_PERCENT=10
MARGIN_WIDTH=$((WIDTH * MARGIN_PERCENT / 100))
MARGIN_HEIGHT=$((HEIGHT * MARGIN_PERCENT / 100))
CANVAS_WIDTH=$((WIDTH + 2 * MARGIN_WIDTH))
CANVAS_HEIGHT=$((HEIGHT + 2 * MARGIN_HEIGHT))
magick -size "${CANVAS_WIDTH}x${CANVAS_HEIGHT}" gradient:"$COLOR1-$COLOR2" "$GRADIENT_IMAGE"

# Round the image by adding an alpha channel mask
magick -size "${WIDTH}x${HEIGHT}" xc:none -draw "roundrectangle 0,0,$WIDTH,$HEIGHT,15,15" "$MASK_IMAGE"
magick "$TEMP_IMAGE" -alpha Set "$MASK_IMAGE" -compose DstIn -composite "$TEMP_IMAGE"

# Add shadow to the image with an offset of +15+15
magick "$TEMP_IMAGE" -page +15+15 \( +clone -background black -shadow 60x10+15+15 \) +swap -background none -layers merge +repage "$SHADOWED_IMAGE"

# Overlay the shadowed image onto the gradient
magick "$GRADIENT_IMAGE" "$SHADOWED_IMAGE" -gravity center -composite "$FINAL_IMAGE"

# Copy the final image back to the clipboard
wl-copy < "$FINAL_IMAGE"

# Clean up temporary files
rm "$TEMP_IMAGE" "$MASK_IMAGE" "$SHADOWED_IMAGE" "$GRADIENT_IMAGE" "$FINAL_IMAGE"


