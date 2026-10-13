# 🎓 UniDash — The Native Apple Campus Cockpit

> **Dein Campus. Dein Semester. Eine blitzschnelle, native App für alles.**  
> Everything university students need — Timetable, Mensa, Live Library Occupancy, Room Finder & GPA Tracker — unified in a pure native **SwiftUI & SwiftData** experience for **iOS 17+** and **macOS 14+**.

[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%2B%20%7C%20macOS%2014%2B-blue?logo=apple&style=flat-square)](#)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift&style=flat-square)](#)
[![UI Framework](https://img.shields.io/badge/UI-SwiftUI%20%2B%20SwiftData-purple?style=flat-square)](#)
[![Zero Cost](https://img.shields.io/badge/Sideloading-Free%20Apple%20ID%20Ready-success?style=flat-square)](#)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

---

## ⚡ The Pitch: Why UniDash?

Every semester, students struggle with the exact same digital fragmentation:

* 📍 **Lost in campus hallways**: Cryptic room codes like `S 002`, `B 201`, `N 120`, or `Raum 023` leave students guessing which building, tract, or floor they need to run to between lectures.
* 📚 **Overcrowded libraries**: Running across campus during exam phase only to find every single seat occupied.
* 🍽️ **Slow Mensa websites**: Standing in the cafeteria line with zero cellar reception while the browser page fails to load.
* 📄 **Timetable tedium**: Manually transcribing 15 lecture dates and recurring tutorial hours from a downloaded university PDF into your calendar.
* 📊 **Grade spreadsheet chaos**: Manually calculating your weighted German GPA while trying to factor in ungraded modules (*unbenotete Scheine* / Pass-Fail) and degree milestones.
* ⚠️ **Deadlines missed**: Forgetting the critical **Rückmeldefrist** (re-registration & semester fee) or exam registration window.

### 💡 The Solution: UniDash
**UniDash replaces 7 clunky browser tabs with a single, high-performance native Apple client.**

Built from the ground up for **iOS 17+** and **macOS 14+**, UniDash stores everything locally on your device with **SwiftData**, caches campus feeds for offline access, and requires **no paid Apple Developer account** to sideload.

---

## ✨ Core Features at a Glance

### 🗺️ 1. Intelligent Campus Room Decoder & Live Map Pinning
* **Instant Room Code Decoder**: Decodes any room string (e.g. `S 002`, `S002`, `B 201`, `N 120`, `Audimax`, `Große Aula`, `B 052`, `W 101`, `Raum 023`, `Raum 144`) into building name, full street address, floor level, building tract, and public transit tips.
* **Exact Spot Map Pinning**: Tapping **„Auf Raumkarte öffnen“** automatically switches to the building plan, drops a Leaflet marker directly onto the room's coordinates, and zooms into the room.
* **Direct Navigation**: One-tap buttons for **In-App Raumkarte**, **Apple Maps** turn-by-turn walking directions, and **LMU Raumfinder Web**.
* **Quick Search Chips**: Pre-configured chips for instant access to major lecture halls and campus hubs.

### 📚 2. Live Library Occupancy & Study Spaces (LMU Platzfinder)
* **Official Live Capacity Feed**: Real-time occupancy percentage gauge connected to the official `platzfinder.ub.uni-muenchen.de` live JSON feed.
* **Smart Open/Closed Detection**: Dynamic status badges calculated against verified opening hours and weekend schedules for all university libraries (Philologicum, UB Hauptgebäude, Historicum, Juridicum, WiWi, MINT Theresienstr., etc.).
* **Equipment & Facility Tags**: 🖨️ Drucker/Scanner, 🤫 Stille Zone, 👥 Gruppenräume, 🔌 Steckdosen, 💻 CIP-Pool.
* **Seamless Desk Reservation**: In-app WebKit booking sheet for Anny study space reservations.

### 🍽️ 3. iMensa-Style Cafeteria Explorer
* **Nationwide University Directory**: Browse canteens across Munich, Berlin, Aachen, Karlsruhe, Hamburg, Frankfurt, Stuttgart, and more.
* **Offline-Ready Weekly Cache**: Menus automatically persist to disk with TTL cache management — view the week's dishes even in deep campus basements without cellular service.
* **Dietary Badges & Filtering**: Clear markers for Vegan 🌱, Vegetarisch 🧀, Geflügel 🍗, Rind 🥩, Schwein 🐷, Fisch 🐟.
* **Interactive 5-Star Community Ratings**: Rate meals from 1 to 5 stars with persistent ratings saved per dish.

### 📅 4. Smart Timetable & PDF Import
* **Dual View Modes**: Switch between **Tagesansicht** (chronological agenda cards with room, duration, and instructor) and **Wochenplan** (clean Monday–Friday grid).
* **Automatic PDF Schedule Parsing**: Drop in your university schedule PDF (HISinOne, CampusOnline, TUMonline, LMU Fachschaft) — parsed with spatial lookahead heuristics.
* **Apple Calendar Export**: One-tap export of your recurring semester classes into Apple Calendar using native `EventKit` recurrence rules.

### 🎓 5. Grade & ECTS Tracker (With Pass/Fail Scheine)
* **Weighted German GPA Math**: Automatically calculates `Sum(grade * ECTS) / Sum(ECTS for graded modules)` according to official examination regulations.
* **Pass/Fail Modules Supported**: Non-graded achievements (*unbenotete Scheine*, Praktika, Sprachkurse) count toward your degree total without skewing your GPA.
* **Degree Progress Ring**: Circular visual milestone tracker towards 180 ECTS (Bachelor), 120 ECTS (Master), or 240 ECTS (Staatsexamen).

### ⏳ 6. Semester Timeline & Deadline Radar
* **Countdown Dashboard**: Visual days-remaining cards for Rückmeldefrist, Vorlesungszeit, Prüfungsanmeldung, Klausurenphase, and Semesterferien.
* **Critical Alerts**: Warning banners when registration or payment deadlines are imminent.
* **Calendar Sync**: One-tap export of academic deadlines to Apple Calendar with 3-day and 1-day reminder alarms.

---

## 🏗️ Architecture & Philosophy

```
UniDash/
├── App/
│   └── UniDashApp.swift            // Multiplatform SwiftData container injection & scene routing
├── Models/
│   ├── Course.swift                // SwiftData @Model for courses, German GPA math & ECTS milestones
│   ├── ScheduleItem.swift          // SwiftData @Model for persistent in-app timetable classes
│   ├── TimetableEntry.swift        // Transient struct for parsed timetable items & DayOfWeek
│   ├── MensaMeal.swift             // OpenMensa API v2 Decodable models, dietary tags & star ratings
│   ├── LibraryInfo.swift           // Verified campus libraries, live Platzfinder feed & opening hours
│   ├── AcademicTimeline.swift      // Semester deadlines, countdowns, re-registration alerts
│   ├── CampusLink.swift            // Quick-launch student portals (Moodle, LSF, LRZ Mail, OPAC)
│   └── CampusRoomGuide.swift       // Intelligent room code decoder & exact LMU Raumfinder coordinate mapping
├── Services/
│   ├── PDFScheduleParser.swift     // Spatial text extraction with regex lookahead heuristics
│   ├── CalendarSyncService.swift   // EventKit "Uni Schedule" creation, recurring rules & deadline alarms
│   ├── LibraryOccupancyService.swift // Official LMU-Platzfinder live JSON parser with fallback simulation
│   └── MensaService.swift          // Async/await URLSession client with disk caching & offline persistence
├── Views/
│   ├── Navigation/
│   │   ├── AdaptiveRootView.swift  // TabView for iOS, NavigationSplitView with Cmd+1..4 for macOS
│   │   └── AppDestination.swift    // Navigation routing & icons
│   ├── Timetable/
│   │   ├── TimetableCalendarView.swift // Interactive In-App Calendar (Day Agenda & Week Grid)
│   │   ├── TimetableImportView.swift   // PDF file picker, live preview & parse trigger
│   │   ├── ParseReviewSheet.swift      // Verification editor for parsed classes & recurrence config
│   │   └── CalendarPushView.swift      // EventKit target calendar selection & sync action
│   ├── Grades/
│   │   ├── GradesDashboardView.swift   // KPI metrics (German GPA, Degree progress gauge, ECTS breakdown)
│   │   └── AddCourseModal.swift        // Course entry/edit with Pass/Fail toggle
│   ├── Mensa/
│   │   └── MensaMenuView.swift         // Canteen switcher, week tabs, categories & 5-star ratings
│   └── Rooms/
│       ├── RoomBookingView.swift       // Unified Campus & Study Spaces Hub
│       ├── LibraryCard.swift           // Live capacity indicator, opening hours & Anny booking
│       ├── AcademicTimelineView.swift  // Deadlines countdown cards & Calendar export
│       ├── CampusQuickLinksView.swift  // Quick-launcher for Moodle, LSF, LRZ Mail, OPAC, Eduroam, ZHS
│       ├── CampusRoomDecoderView.swift // Interactive room decoder, quick chips & building switcher
│       └── EmbeddedWebView.swift       // WebKit bridge with automatic Leaflet room pin locator
├── Tests/
│   └── UniDashTests/
│       └── UniDashTests.swift          // Automated unit tests (GPA, PDF parser, Mensa, Room Decoder)
├── Resources/
│   ├── Info.plist                     // Calendar privacy descriptions & app metadata
│   └── UniDash_macOS.entitlements     // Sandboxed network, calendar & file access for macOS
└── project.yml                        // XcodeGen declarative specification
```

### 🔒 Privacy & Free Sideloading by Design
UniDash requires **zero paid developer program subscriptions**:
- **No CloudKit Containers**: Avoids Apple Developer account entitlement dependencies.
- **100% Local SwiftData**: Your grades, timetable, and favorites never leave your physical device.
- **Sandboxed Apple APIs**: Uses standard `EventKit`, `PDFKit`, and `WebKit` system frameworks.
- **Free Personal Apple ID Sideloading**: Build and deploy straight to your personal iPhone or Mac using free 7-day personal provisioning profiles.

---

## 🚀 Getting Started

### Prerequisites
- macOS 14.0+ (Sonoma or Sequoia)
- Xcode 15.0+ or Xcode 16+
- iOS 17.0+ (for iPhone deployment)

### 🖥️ Running on macOS
1. Open [`UniDash.xcodeproj`](UniDash.xcodeproj) in Xcode.
2. Select the **`UniDash_macOS`** scheme.
3. Press **`Cmd + R`** to build and run natively on your Mac.
4. *Or launch the pre-installed application:*
   ```bash
   open /Applications/UniDash.app
   ```

### 📱 Running on iPhone (iOS 17+)
1. Connect your iPhone via USB or Wi-Fi.
2. Open [`UniDash.xcodeproj`](UniDash.xcodeproj) in Xcode.
3. Select your personal development team in **Signing & Capabilities** (works with any free Apple ID).
4. Select the **`UniDash_iOS`** scheme and choose your connected iPhone.
5. Press **`Cmd + R`** (or click **▶**) to build, install, and run.

### 🧪 Running Automated Tests
```bash
xcodebuild test -scheme UniDash_macOS -destination 'platform=macOS'
```
*All 12 test suites (weighted GPA math, spatial PDF schedule parser, Mensa JSON decoding, and room coordinate decoder) execute in < 2 seconds.*

---

## 📄 License
This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
