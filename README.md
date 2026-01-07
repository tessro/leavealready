# Leave

A minimal iOS app that shows upcoming train departures for your commute. Automatically detects whether you're at home or work and shows departures in the right direction.

Uses 511.org Bay Area transit data (BART, Caltrain, Muni, etc.)

## Features

- Location-based: shows departures from the nearest configured station
- Auto-direction: figures out if you're going to work or home
- Real-time data with live indicators
- Big, readable departure times
- Pull to refresh + auto-refresh every 30 seconds

## Setup

### 1. Get a 511.org API Key

1. Go to [511.org/open-data](https://511.org/open-data/token)
2. Sign up for a free account
3. Request an API token for Transit data
4. Copy your API key

### 2. Find Your Stop Codes

You'll need stop codes for your origin and destination stations.

**BART stations:** [BART Stop Codes](https://api.bart.gov/docs/overview/abbrev.aspx)
- Example: `MONT` (Montgomery), `DALY` (Daly City), `EMBR` (Embarcadero)

**Caltrain stations:** Check [511.org GTFS data](https://511.org/open-data/transit)
- Example: `70011` (San Francisco), `70261` (Mountain View)

**Station coordinates:** Use Google Maps to get lat/lon for each station.

### 3. Configure in App

1. Open Leave app
2. Tap "Get Started" or gear icon
3. Enter your 511.org API key
4. Add a route with:
   - Route name (e.g., "Commute")
   - Transit agency (BART, Caltrain, etc.)
   - Line ID (optional - filters to specific line)
   - Origin station: stop code, name, lat, lon
   - Destination station: stop code, name, lat, lon

## Building for TestFlight

### Prerequisites

- macOS with Xcode Command Line Tools
- Apple Developer account
- App Store Connect access

### Step 1: Configure Signing

Edit `Leave.xcodeproj/project.pbxproj` and update:
- `DEVELOPMENT_TEAM` = Your Team ID (find in Apple Developer portal)
- `PRODUCT_BUNDLE_IDENTIFIER` = Your unique bundle ID (e.g., `com.yourname.Leave`)

Or set via command line:
```bash
xcodebuild -project Leave.xcodeproj \
  -scheme Leave \
  -configuration Release \
  DEVELOPMENT_TEAM="YOUR_TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="com.yourname.Leave"
```

### Step 2: Create App in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. My Apps → + → New App
3. Fill in:
   - Platform: iOS
   - Name: Leave (or your preferred name)
   - Bundle ID: Match what you set above
   - SKU: Any unique string (e.g., `leave-001`)

### Step 3: Build Archive

```bash
# Clean build folder
xcodebuild clean -project Leave.xcodeproj -scheme Leave

# Build archive
xcodebuild archive \
  -project Leave.xcodeproj \
  -scheme Leave \
  -configuration Release \
  -archivePath build/Leave.xcarchive \
  -destination "generic/platform=iOS" \
  DEVELOPMENT_TEAM="YOUR_TEAM_ID" \
  CODE_SIGN_STYLE=Automatic
```

### Step 4: Export IPA

Create `ExportOptions.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadSymbols</key>
    <true/>
    <key>destination</key>
    <string>upload</string>
</dict>
</plist>
```

Export the archive:
```bash
xcodebuild -exportArchive \
  -archivePath build/Leave.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
```

### Step 5: Upload to TestFlight

Using `altool` (older method):
```bash
xcrun altool --upload-app \
  -f build/export/Leave.ipa \
  -t ios \
  -u "your@apple.id" \
  -p "@keychain:AC_PASSWORD"
```

Using `notarytool` / Transporter (recommended):
```bash
xcrun notarytool submit build/export/Leave.ipa \
  --apple-id "your@apple.id" \
  --team-id "YOUR_TEAM_ID" \
  --password "@keychain:AC_PASSWORD"
```

Or use the Transporter app from the Mac App Store.

### Step 6: Enable TestFlight

1. Go to App Store Connect → Your App → TestFlight
2. Wait for build processing (usually 5-15 minutes)
3. Add yourself as internal tester
4. Install via TestFlight app on your iPhone

## Quick Build Script

Save as `build.sh`:
```bash
#!/bin/bash
set -e

TEAM_ID="YOUR_TEAM_ID"
BUNDLE_ID="com.yourname.Leave"

echo "Building Leave..."
xcodebuild clean archive \
  -project Leave.xcodeproj \
  -scheme Leave \
  -configuration Release \
  -archivePath build/Leave.xcarchive \
  -destination "generic/platform=iOS" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  CODE_SIGN_STYLE=Automatic

echo "Exporting IPA..."
xcodebuild -exportArchive \
  -archivePath build/Leave.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist

echo "Done! IPA at build/export/Leave.ipa"
echo "Upload with: xcrun altool --upload-app -f build/export/Leave.ipa -t ios -u YOUR_APPLE_ID -p @keychain:AC_PASSWORD"
```

## App Store Password Setup

Store your app-specific password in Keychain for automated uploads:
```bash
xcrun notarytool store-credentials "AC_PASSWORD" \
  --apple-id "your@apple.id" \
  --team-id "YOUR_TEAM_ID"
```

## Example Route Configuration

**BART: Daly City ↔ Montgomery**
- Route Name: `BART Commute`
- Agency: `BART`
- Line ID: (leave empty for all lines)
- Origin: `DALY`, `Daly City`, `37.7063`, `-122.4692`
- Destination: `MONT`, `Montgomery`, `37.7894`, `-122.4013`

**Caltrain: SF ↔ Mountain View**
- Route Name: `Caltrain Commute`
- Agency: `Caltrain`
- Line ID: (leave empty)
- Origin: `70011`, `San Francisco`, `37.7765`, `-122.3943`
- Destination: `70261`, `Mountain View`, `37.3944`, `-122.0768`

## Troubleshooting

**"API key not set"** - Go to Settings and enter your 511.org API key

**"No upcoming departures"** - Check that your stop code is correct and trains are running

**Location not updating** - Make sure location permissions are enabled in iOS Settings

**Build fails with signing error** - Verify your Team ID and bundle identifier match App Store Connect

## License

MIT
