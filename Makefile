.PHONY: app run install icon clean

# Build build/Keywipe.app.
app:
	Scripts/build-app.sh

# Build, then launch the app.
run: app
	open build/Keywipe.app

# Build, then replace the copy in /Applications. A running Keywipe is quit first.
install: app
	@pkill -x Keywipe || true
	rm -rf /Applications/Keywipe.app
	ditto build/Keywipe.app /Applications/Keywipe.app
	@echo "Installed /Applications/Keywipe.app"

# Redraw Resources/AppIcon.icns from Scripts/make-icon.swift.
icon:
	rm -rf build/AppIcon.iconset
	swift Scripts/make-icon.swift build/AppIcon.iconset
	iconutil --convert icns --output Resources/AppIcon.icns build/AppIcon.iconset

# Leaves .signing/ alone: removing it would change the signature and drop the permission.
clean:
	rm -rf .build build
