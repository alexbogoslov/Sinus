# Sinus — Project Brief & Build Guide

> This file is the single source of truth for the Sinus project.
> Claude Code should read this at the start of every session before making any changes.

---

## What is Sinus?

Sinus is a macOS menu bar application that transforms the MacBook notch into a dynamic,
system-integrated companion — inspired by the iPhone Dynamic Island but designed natively
for macOS. The name comes from the Latin word for "bay, inlet, curve" — referencing both
the curved recess of the notch and the sheltered, intimate space it creates.

**Core design principle: Companion, not a feature.**
Sinus should feel like it was built by Apple and shipped with macOS. Every animation,
every material, every interaction should feel inevitable — not bolted on.

**Developer:** Alex Bogoslov (launchwithalex@gmail.com)
**GitHub:** alexbogoslov
**Platform:** macOS 14+ (Sonoma), Apple Silicon (M-series), SwiftUI
**Licence:** Proprietary — Source Visible (see LICENSE file)

---

## What Sinus is NOT

- Not a fork of BoringNotch (GPL-3.0 — incompatible with our goals)
- Not a clone of Alcove (closed source, paid)
- We observe these apps for inspiration only — zero code is taken from them
- Not a settings-heavy utility app — defaults should be beautiful out of the box

---

## Licensing & Legal

Sinus uses a custom proprietary licence:
- Source code is visible on GitHub for transparency and community trust
- Personal use (building and running locally) is free
- Commercial use, redistribution, or use as a competing product requires written
  permission from the copyright holder
- This licence can be updated by Alex at any time — individual components may be
  open-sourced separately in the future if desired
- The licence file lives at the root of the repo as LICENSE

Two MIT-licensed dependencies are used as building blocks:
- NotchDrop (Lakr233) — file tray and AirDrop notch integration
- NotchNotification (Lakr233) — notification display inside the notch
- Both must be credited in the About screen, README, and the LICENSE file
- MIT is permissive — these dependencies do NOT force Sinus to be open source

**Rule: No GPL-licensed code may ever be introduced to this project.**

---

## Animation Design Principles

This is the heart of Sinus. Everything else builds on top of this.

### The Target Feel
The notch shape must feel like it has mass and inertia — like the Dynamic Island on
iPhone. When it expands, it should stretch slightly before snapping to its target size.
When it collapses, it should feel like it's being pulled back, not just disappearing.

### Spring Physics Targets
- Expand: spring(response: 0.42, dampingFraction: 0.72) — fast but with weight
- Collapse: spring(response: 0.35, dampingFraction: 0.82) — snappier return
- Content fade-in: delayed 0.08s after expand begins, easeOut(duration: 0.2)
- Content fade-out: begins immediately on collapse, easeIn(duration: 0.12)

### Progressive Blur
On expand, the area immediately around the notch should progressively blur using
NSVisualEffectView with .behindWindow material. This is NOT a hard edge.
The blur radius increases as the notch opens.

### The Notch Window
- Sits at window level above the menu bar
- Perfectly aligned to the physical notch — no gaps, no overlap with menu bar items
- The notch itself is always pure black — it IS the notch
- Expanded content appears below the notch line on a dark material background
- Corner radius on expanded state: 16pt (matching Apple's own HUD radius)

### Collapsed State — Always Alive
The notch should never look dead when idle. Depending on context:
- Music playing: album art (small, left-aligned) + animated waveform bars (right)
- No music: subtle breathing animation or clean empty state
- Never show a blank black rectangle with nothing happening

---

## Feature Priority — Build Order

Build in this exact sequence. Do not skip ahead.

### Phase 1 — Foundation (Build this first, get it perfect)
1. Notch window engine — create the NSWindow that sits over the notch, handles
   sizing, positioning, and stays correctly anchored on all display configurations
2. Expand/collapse animation — the spring physics system described above
3. Basic collapsed state — clean idle appearance, nothing interactive yet
4. Mouse tracking — detect hover over notch region to trigger expand

### Phase 2 — Core Live Activities
5. Music player — Now Playing integration via MediaRemote framework
   - Collapsed: album art thumbnail + waveform bars reacting to audio
   - Expanded: album art (with flip animation showing back), track name, artist,
     progress bar, playback controls (prev/play/pause/next)
   - Waveform: animated bars, colour options (monochrome / accent / gradient)
6. OSD Replacement — intercept macOS volume and brightness HUD events
   - Replace with notch-native pill: icon + label + slider bar inside the notch
   - Volume: speaker icon, level bar, mute state shows "muted" label
   - Brightness: sun icon, level bar with glow style option
   - Animation: notch briefly expands to show the OSD, collapses after 1.5s
7. Calendar — read from EventKit
   - Collapsed: event count badge or next event time
   - Expanded: today's date (day name + number), next event with time,
     "No events today / Your day is clear" when empty
   - Quick Peek: auto-expands when an event is starting

### Phase 3 — Notification & System Integration
8. Focus / Do Not Disturb — detect Focus state changes
   - Show a separate pill that slides out to the side of the notch (not inside it)
   - Pill shows moon icon + mode name + On/Off state
   - Allowed notification list (battery, connectivity, display, sound)
9. Battery notifications — charge level warnings inside the notch
   - Low battery threshold (configurable), charging connected/disconnected
   - Duration slider (how long the notification shows)
10. Connectivity (AirPods) — device connection/disconnection events
    - Show 3D model or symbol (user choice) of the connected device
    - Battery level for each earbud + case when available

### Phase 4 — File Tray & AirDrop
11. File Tray — using NotchDrop as the foundation
    - Drag files onto the notch to store temporarily
    - Right-click context menu (open, share, delete)
    - Multi-select (Shift = consecutive, Cmd = non-consecutive)
    - AirDrop access directly from the tray
    - Files auto-expire (configurable duration)

### Phase 5 — Lock Screen & Polish
12. Lock Screen integration — show widgets on the lock screen notch area
    - Music pill with material variants: Glass / Clear / Frosted
    - Battery, connectivity, Focus widgets
    - Weather (requires location permission)
13. Swipe gestures — trackpad gestures on the notch area
    - Swipe to cycle between activities
    - Swipe to dismiss
    - Swipe to skip media track
14. Settings UI — built last, once we know what needs to be configured
    - Sidebar with coloured category icons (Apple Settings style)
    - No dark grey background — use system materials throughout

---

## Settings Architecture (Plan Ahead)

Even though we build the Settings UI last, design the settings system early.
Use AppStorage with UserDefaults for all persistent settings.
Group settings by category matching the sidebar:

- General — launch at login, display target, idle activity, behaviour toggles
- Notifications/Battery — threshold, duration, sounds
- Notifications/Connectivity — AirPods display style (3D / symbol)
- Notifications/Focus — allowed list
- Notifications/Display — brightness bar style, speed
- Notifications/Sound — volume bar style, show device toggle
- LiveActivities/NowPlaying — waveform style, artwork flip, idle duration, extra buttons
- LiveActivities/Calendar — time before event, quick peek, calendar filter
- LiveActivities/FileTray — auto-expire duration, sharing options
- LockScreen — material style, widget toggles, idle duration

---

## Key Technical Decisions

### Window Management
- Use NSPanel (not NSWindow) — panels can appear above the menu bar
- Set collectionBehavior to .canJoinAllSpaces and .stationary
- Window level: NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) - 1)
- Detect notch position using NSScreen.main?.safeAreaInsets

### MediaRemote Framework
For Now Playing data, use the private MediaRemote.framework:
- MRMediaRemoteGetNowPlayingInfo for track metadata
- MRMediaRemoteGetNowPlayingApplicationIsPlaying for play state
- MRNowPlayingNotification for change notifications
- Must be loaded dynamically (private framework — not importable directly)

### OSD Interception
To replace the macOS volume/brightness HUD:
- Monitor CGEventTap for key events (volume up/down/mute, brightness keys)
- Or observe com.apple.BezelServices.BZBezelNotification via CFNotificationCenter
- Suppress the default HUD using com.apple.BezelServices private API (research required)

### EventKit for Calendar
- Request .event access via EKEventStore
- Query today's events sorted by start time
- Subscribe to EKEventStoreChangedNotification for live updates

### Haptic Feedback
- Use NSHapticFeedbackManager with .alignment pattern on expand
- Use .levelChange pattern when OSD values change
- Haptics should be tied to animation keyframes, not just triggered independently

---

## Visual Design Tokens

- Notch background: always pure black
- Expanded panel background: NSVisualEffectView material .hudWindow
- Corner radius: 16pt
- Typography: SF Pro (system font) throughout, never custom fonts
  - Primary labels: .body weight .medium
  - Secondary labels: .caption weight .regular, opacity 0.6
- Accent colour: .accentColor (follows system)
  - Exception: calendar event dot uses the calendar's own colour
- Icon style: SF Symbols only, weight matching surrounding text

---

## Reference Apps (Inspiration Only — No Code)

- Alcove: animation quality, progressive blur, OSD replacement, settings UI structure,
  Lock Screen materials, Do Not Disturb pill, compact waveform
- BoringNotch: feature breadth, file tray concept, AirDrop integration
- NotchDrop (MIT): file tray — we USE this code directly
- NotchNotification (MIT): notification display — we USE this code directly
- iPhone Dynamic Island: the gold standard for spring physics and inertia feel

---

## What Makes Sinus Different

1. Heavier spring physics — more inertia than Alcove, more fluid than BoringNotch
2. Collapsed state is alive — the notch always has something subtle happening
3. No design debt — built clean from day one, not patched over someone else's code
4. Source visible, commercially protected — open enough to build community,
   protected enough to monetise
5. Companion framing — every feature asks: does this make the Mac feel more alive?

---

## Session Protocol for Claude Code

At the start of every Claude Code session:
1. Read this file completely before touching any code
2. Check which Phase we are currently in
3. Ask Alex what the session goal is before starting
4. After any significant change, ask Alex to build and run in Xcode and report back
5. Never refactor working code without explicit discussion first
6. Keep commits small and descriptive

---

## Project Status

- [x] Vision defined
- [x] Name locked: Sinus
- [x] GitHub username locked: alexbogoslov
- [x] Licensing decided: Proprietary source-visible with custom LICENSE
- [x] Feature list prioritised
- [x] Animation targets defined
- [x] Reference material collected (Alcove screenshots + GIF)
- [x] Xcode project created
- [ ] LICENSE and CLAUDE.md added to project folder
- [ ] GitHub repo created and connected
- [ ] Phase 1 begun
