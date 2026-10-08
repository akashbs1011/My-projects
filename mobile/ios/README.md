# iOS build preparation

Everything hand-editable is committed here:

| File | What it carries |
|---|---|
| `Runner/Info.plist` | Bundle config **and the two permission strings voice input requires** |
| `Runner/AppDelegate.swift` | Plugin registration |
| `Runner/Runner-Bridging-Header.h` | Swift/ObjC bridge |
| `Runner/Base.lproj/*.storyboard` | Launch screen and the FlutterViewController host |
| `Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` | Icon manifest |
| `Podfile` | iOS 13 floor, plus the `PERMISSION_MICROPHONE` / `PERMISSION_SPEECH_RECOGNIZER` flags `speech_to_text` needs |
| `Flutter/*.xcconfig` | Debug and Release build configuration |

## One step you must run

`Runner.xcodeproj/project.pbxproj` is **not** committed. It is a machine-generated
Xcode file, hundreds of lines of UUID cross-references, and a hand-written one
is the single most common cause of an iOS project that will not open. Generate
it with the tool that owns it:

```bash
cd mobile
flutter create --platforms=ios .
```

This writes the Xcode project wrapper **around** the files above without
overwriting them — `flutter create` on an existing directory only fills in what
is missing. Verify afterwards that `Info.plist` still contains
`NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription`; if it
does, nothing was clobbered.

Then:

```bash
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```

Open the **`.xcworkspace`**, not the `.xcodeproj` — CocoaPods builds will fail
otherwise.

## Before archiving

1. In Xcode → Runner → Signing & Capabilities, set your Team and a bundle
   identifier you own (the default is `com.clinicalai.app`).
2. Add real icon PNGs at the sizes listed in `Contents.json`.
3. Point the build at a production API over HTTPS:

```bash
flutter build ipa --release \
  --dart-define=ENVIRONMENT=prod \
  --dart-define=API_BASE_URL=https://your-api.example.com/api
```

App Transport Security blocks plain HTTP on iOS. A release build against an
`http://` backend will fail to connect — this is expected, and the fix is to
serve the API over HTTPS rather than to add an ATS exception.

## Note on the simulator

The iOS simulator shares the host's network, so use `127.0.0.1`, not the
`10.0.2.2` address the Android emulator needs:

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

Speech recognition does not work in the simulator. The app detects this and
shows the "type your symptoms instead" message rather than offering a button
that does nothing — test voice input on a physical device.
