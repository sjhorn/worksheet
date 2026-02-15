#!/bin/bash

# Remove the icon cache files
sudo rm -rf /Library/Caches/com.apple.iconservices.store

# For user-level cache
rm -rf ~/Library/Caches/com.apple.iconservices.store

# Restart the Dock (which handles icon rendering)
killall Dock

# Restart Finder
killall Finder