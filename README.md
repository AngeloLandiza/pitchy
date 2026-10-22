# Pitchy

A free, private ear-training app for iPhone. It's a personal take on "Pitch Master", built around what its App Store reviewers asked for:

- **Free:** no paywall, ads or accounts.
- **Assessment you can check:** every question is listed with what was played, what you picked and how long you took.
- **Fair singing grading:** an on-device pitch detector (YIN), a live tuner needle, an adjustable tolerance and a short hold before grading. Any octave counts.
- **Key changes:** scale-degree and singing questions move to a new key every question, every 4 questions or every session.
- **Private:** progress is stored on the phone with SwiftData, and microphone audio never leaves the device.

## What's inside

| Area | Details |
| --- | --- |
| Daily workout | Adaptive questions on note names, intervals, scale degrees (after a I–IV–V–I cadence) and singing. Weak items come up more often |
| Curriculum | Starts with 3 notes, 3 intervals and 3 scale degrees, and unlocks the next one once you've mastered the current set |
| Starting check | 12 notes and 6 intervals with no reference note, used to set your starting level |
| Games | Note Blitz (30 seconds) and Pitch Pilot (steer with your voice) |
| Progress | Streak, XP, and accuracy for every note, interval and scale degree |
| Settings | 5 synthesized instruments, transposition, CDE or Do Re Mi note names, voice range, tolerance and workout length |

## Run it on your iPhone

You need a Mac with Xcode 16 or later and an iPhone on iOS 17 or later. A free Apple ID is enough.

1. Install XcodeGen once: `brew install xcodegen`
2. In this folder, run `xcodegen` to create `Pitchy.xcodeproj`, then open it.
3. Select the **Pitchy** target, open **Signing & Capabilities**, and choose your Personal Team. If Xcode says the bundle ID is taken, change `com.angelolandiza.pitchy` to something unique.
4. Plug in your iPhone. If it asks, turn on **Settings > Privacy & Security > Developer Mode**.
5. Choose your iPhone as the run destination and press **Run** (⌘R).
6. On the phone, trust the developer profile under **Settings > General > VPN & Device Management**.

With a free Apple ID, the app stops opening after 7 days. Plug in your phone and press Run again to refresh it. Your progress is kept.

Run the tests with ⌘U. They cover pitch detection, octave-agnostic singing, streaks, the workout mix and curriculum unlocks.

## Project layout

```
Pitchy/
  App/        App entry, tabs, colours, haptics
  Audio/      Synth (additive, no sample files), YIN pitch detector, mic listener
  Model/      Notes, intervals, scale degrees, settings, SwiftData records
  Training/   Question building, curriculum, workout and assessment sessions
  Views/      Screens and games
PitchyTests/  Unit tests
project.yml   XcodeGen project definition
```
