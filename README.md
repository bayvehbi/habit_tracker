## Features

- Create and manage custom habits
  - **Boolean habits**: done / not done
  - **Count habits**: numeric progress (e.g. push-ups, water)
- Add timestamped log entries for each habit
- Per-habit streak calculation
- Habit statistics page:
  - current streak
  - best streak
  - total completed days
  - total logged value
  - monthly completion calendar
- Lockscreen widget support (per selected habit)

## Tech Stack

- **Swift**
- **SwiftUI**
- **WidgetKit**
- **AppIntents**
- Shared data via **App Group** (`UserDefaults` suite)

## Project Structure

- `habit_track/` – Main iOS app code
- `HabitLockscreenWidgetExtension/` – Widget extension target
- `habit_trackTests/` – Unit tests
- `habit_trackUITests/` – UI tests

## Data Model (High Level)

- `Habit`
  - id, name, symbol, kind
- `HabitLog`
  - id, habitID, value, timestamp

Daily progress and streaks are derived from logs.

## Business Rules

- Boolean habits are treated as **daily done/not-done** (not cumulative count).
- Count habits accumulate numeric logs.
- Logs can be edited/deleted only within a limited time window (currently configured in storage logic).

## Getting Started

### Requirements

- Xcode 15+
- iOS 17+ (for full widget + AppIntents support)

### Run

1. Clone the repository
2. Open `habit_track.xcodeproj`
3. Select `habit_track` scheme
4. Build and run on simulator/device

## Widget

The lockscreen widget displays:
- habit icon
- streak
- done/not-done state indicator
- state-based compact layout for small widget area

## Roadmap Ideas

- Trend charts (7-day / 30-day)
- Export / backup logs
- Notifications and reminders
- More advanced widget layouts
