# Shake to Undo Feature

The Dialog app now includes a comprehensive shake-to-undo system that allows users to easily undo recent actions by shaking their device.

## How It Works

1. **Shake Detection**: The app detects when the user shakes their device using the device's motion sensors
2. **Undo Confirmation**: When a shake is detected, a toast notification appears at the top of the screen
3. **Action Description**: The toast shows what action will be undone (e.g., "Added text", "Deleted session")
4. **Undo Button**: Users can tap the "Undo" button to confirm the action
5. **Auto-Dismiss**: The toast automatically disappears after 4 seconds if no action is taken

## Supported Undo Actions

### In Dialog Scene:
- **Add Text**: Undo adding new dialog text
- **Delete Text**: Undo deleting dialog text
- **Edit Text**: Undo text modifications
- **Toggle Flag**: Undo flagging/unflagging dialog
- **Rename Character**: Undo character name changes

### In Main Menu:
- **Delete Session**: Undo session deletion
- **Rename Session**: Undo session name changes

## Technical Implementation

### Core Components:

1. **AppUndoManager** (`Models/UndoManager.swift`)
   - Singleton class managing the undo stack
   - Supports up to 50 undo actions
   - Thread-safe implementation

2. **ShakeDetector** (`Views/ShakeDetector.swift`)
   - Custom ViewModifier for shake gesture detection
   - Works throughout the app with `.onShake()` modifier

3. **UndoConfirmationView** (`Views/UndoConfirmationView.swift`)
   - Toast-style UI for undo confirmation
   - Includes haptic feedback
   - Auto-dismiss functionality

### Architecture:
- Uses MVVM pattern with SwiftUI
- Integrates with existing ViewModels
- Follows iOS design guidelines
- Simple and lightweight implementation

## User Experience

- **Intuitive**: Shake gesture is a standard iOS pattern
- **Forgiving**: Users can easily recover from mistakes
- **Non-Intrusive**: Toast appears briefly and doesn't block interaction
- **Contextual**: Clear description of what will be undone
- **Accessible**: Works with VoiceOver and other accessibility features

## Performance

- **Memory Efficient**: Limited undo stack prevents memory bloat
- **Fast**: Undo operations are near-instantaneous
- **Background Safe**: Properly handles app lifecycle events

## Usage Tips

1. Shake your device any time after performing an action
2. The most recent action will be shown for undo
3. You have 4 seconds to decide whether to undo
4. Multiple shakes won't stack - only the most recent action can be undone
5. Undo stack is cleared when switching between major app sections

This feature enhances the user experience by providing a safety net for user actions, making the app more forgiving and user-friendly. 