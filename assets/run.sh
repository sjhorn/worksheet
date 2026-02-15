#!/bin/bash

rm markdowner.png
./svg2appiconset.sh worksheet.svg
mv AppIcon.appiconset/icon_mac512.png ./worksheet.png
rm -Rf AppIcon.appiconset
./clear_icon_cache.sh
cd ..
flutter clean && flutter pub get
cd assets