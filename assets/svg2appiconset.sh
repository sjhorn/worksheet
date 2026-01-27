#!/bin/sh -x

set -e

# iOS + macOS App Icon sizes (size,filename,idiom,scale)
SIZES="
40,20@2x,iphone,2x
60,20@3x,iphone,3x
58,29@2x,iphone,2x
87,29@3x,iphone,3x
80,40@2x,iphone,2x
120,40@3x,iphone,3x
120,60@2x,iphone,2x
180,60@3x,iphone,3x
40,20@2x,ipad,2x
58,29@2x,ipad,2x
80,40@2x,ipad,2x
152,76@2x,ipad,2x
167,83.5@2x,ipad,2x
1024,1024,ios-marketing,1x
16,mac16,mac,1x
32,mac16@2x,mac,2x
32,mac32,mac,1x
64,mac32@2x,mac,2x
128,mac128,mac,1x
256,mac128@2x,mac,2x
256,mac256,mac,1x
512,mac256@2x,mac,2x
512,mac512,mac,1x
1024,mac512@2x,mac,2x
"

for SVG in "$@"; do
    BASE=$(basename "$SVG" | sed 's/\.[^\.]*$//')
    APPICONSET="AppIcon.appiconset"
    mkdir -p "$APPICONSET"
    
    # Start Contents.json
    echo '{
  "images" : [' > "$APPICONSET/Contents.json"
    
    FIRST=true
    for PARAMS in $SIZES; do
        SIZE=$(echo $PARAMS | cut -d, -f1)
        LABEL=$(echo $PARAMS | cut -d, -f2)
        IDIOM=$(echo $PARAMS | cut -d, -f3)
        SCALE=$(echo $PARAMS | cut -d, -f4)
        FILENAME="icon_$LABEL.png"
        
        # Convert SVG to PNG
        svg2png -w $SIZE -h $SIZE "$SVG" "$APPICONSET/$FILENAME" || true
        
        # Add comma before all entries except the first
        if [ "$FIRST" = true ]; then
            FIRST=false
        else
            echo ',' >> "$APPICONSET/Contents.json"
        fi
        
        # Extract point size from label (remove mac prefix and @2x suffix)
        POINT_SIZE=$(echo $LABEL | sed 's/^mac//' | sed 's/@.*//')
        
        # Add entry to Contents.json
        printf '    {
      "filename" : "%s",
      "idiom" : "%s",
      "scale" : "%s",
      "size" : "%sx%s"
    }' "$FILENAME" "$IDIOM" "$SCALE" "$POINT_SIZE" "$POINT_SIZE" >> "$APPICONSET/Contents.json"
    done
    
    # Close Contents.json
    echo '
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}' >> "$APPICONSET/Contents.json"
rm -rf ../macos/Runner/Assets.xcassets/AppIcon.appiconset
rm -rf ../ios/Runner/Assets.xcassets/AppIcon.appiconset
cp -a "$APPICONSET" ../macos/Runner/Assets.xcassets/AppIcon.appiconset
cp -a "$APPICONSET" ../ios/Runner/Assets.xcassets/AppIcon.appiconset
rm -rf AppIcon.appiconset
done