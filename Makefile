.PHONY: app run icon clean

# Build build/Keywipe.app.
app:
	Scripts/build-app.sh

# Build, then launch the app.
run: app
	open build/Keywipe.app

# Redraw Resources/AppIcon.icns from Scripts/make-icon.swift.
icon:
	rm -rf build/AppIcon.iconset
	swift Scripts/make-icon.swift build/AppIcon.iconset
	iconutil --convert icns --output Resources/AppIcon.icns build/AppIcon.iconset

clean:
	rm -rf .build build
