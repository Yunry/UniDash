# UniDash — Personal Native Apple Client

Multiplatform native Apple client for university students (**iOS 17+** & **macOS 14+**), built with pure native SwiftUI, SwiftData, PDFKit, EventKit, and WebKit.

Designed specifically for **Free Personal Apple ID sideloading**, avoiding any paid Apple Developer program entitlements (purely local SwiftData storage, no CloudKit containers, no push notifications).

---

## 📁 Architecture & File Structure

```
UniDash/
├── App/
│   └── UniDashApp.swift            // ModelContainer injection (Course & ScheduleItem) & multiplatform scene
├── Models/
│   ├── Course.swift                // SwiftData @Model for courses, German GPA math, Pass/Fail & ECTS
│   ├── ScheduleItem.swift          // SwiftData @Model for persistent in-app timetable classes
│   ├── TimetableEntry.swift        // Transient struct for parsed timetable items & DayOfWeek
│   ├── MensaMeal.swift             // OpenMensa API v2 Decodable models, iMensa categories & star ratings
│   ├── LibraryInfo.swift           // Real campus libraries, live occupancy gauges, opening hours & equipment
│   ├── AcademicTimeline.swift      // Semester deadlines, countdowns, re-registration alerts & EventKit sync
│   ├── CampusLink.swift            // Quick-launch student portals (Moodle, LSF, LRZ Webmail, OPAC)
│   └── CampusRoomGuide.swift       // Room code decoder (e.g. B 201 -> 2. OG) & building campus guide
├── Services/
│   ├── PDFScheduleParser.swift     // PDFKit extraction with lookahead regex heuristics
│   ├── CalendarSyncService.swift   // EventKit "Uni Schedule" creation, weekly sync & deadline alarms
│   └── MensaService.swift          // Async/await URLSession client with offline disk caching & ratings
├── Views/
│   ├── Navigation/
│   │   ├── AdaptiveRootView.swift  // TabView for iOS, NavigationSplitView with Cmd+1..4 for macOS
│   │   └── AppDestination.swift    // Navigation routing & icons
│   ├── Timetable/
│   │   ├── TimetableCalendarView.swift // Interactive In-App Calendar (Day Agenda & Week Grid)
│   │   ├── TimetableImportView.swift   // File picker (.pdf), live preview, & parse trigger
│   │   ├── ParseReviewSheet.swift      // Verification editor for parsed classes & recurrence config
│   │   ├── CalendarPushView.swift      // EventKit target calendar selection & sync action
│   │   └── PDFKitRepresentedView.swift // Cross-platform PDFView representable
│   ├── Grades/
│   │   ├── GradesDashboardView.swift   // KPI metrics (German GPA, Degree progress gauge, Pass/Fail ECTS breakdown)
│   │   └── AddCourseModal.swift        // Course entry/edit with Pass/Fail (unbenotete Scheine) toggle
│   ├── Mensa/
│   │   └── MensaMenuView.swift         // iMensa-style city/canteen switcher, week tabs, categories & 5-star ratings
│   └── Rooms/
│       ├── RoomBookingView.swift       // Unified Campus & Lernräume Hub with multi-tab switcher
│       ├── LibraryCard.swift           // Live capacity indicator, opening hours, equipment tags & Anny booking
│       ├── AcademicTimelineView.swift  // Deadlines countdown cards, critical alert banner & Calendar export
│       ├── CampusQuickLinksView.swift  // Quick-launcher for Moodle, LSF, LRZ Mail, OPAC, Eduroam, ZHS, U-Kino
│       ├── CampusRoomDecoderView.swift // Interactive room code decoder & Apple Maps navigation
│       └── EmbeddedWebView.swift       // In-app WKWebView booking sheet
├── Tests/
│   └── UniDashTests/
│       └── UniDashTests.swift          // Automated unit tests for GPA, PDF heuristics, Mensa & Room decoder
├── Resources/
│   ├── Info.plist                     // Calendar privacy descriptions & app metadata
│   └── UniDash_macOS.entitlements     // Sandboxed network, calendar & file access for macOS
└── project.yml                        // XcodeGen declarative specification
```

---

## 🎯 Major Features

### 📅 1. Interactive In-App Calendar & Timetable
- **Dual View Modes**:
  - **Tagesansicht (Day Agenda)**: Chronological timeline cards with start/end time, duration, room (`📍 Audimax`), instructor, and color tags.
  - **Wochenplan (Week Grid)**: Monday-to-Friday overview at a glance.
- **Local Persistence**: Classes are stored in local SwiftData (`ScheduleItem`), loaded instantly upon app launch.
- **Integrated PDF Import**: Import PDF timetable exports from HISinOne, CampusOnline, TUMonline, or QISPOS at any time.
- **Apple Calendar Export**: One-tap sync from your in-app schedule directly into Apple Calendar using `EKRecurrenceRule`.

### 🍽️ 2. iMensa-Style Cafeteria Experience
- **City & Canteen Directory**: Comprehensive browser for German university cities (Aachen, Berlin, München, Karlsruhe, Leipzig, Dresden, Hamburg, Frankfurt, Stuttgart, etc.) and search by canteen name.
- **Favorites Strip (⭐)**: Save multiple cafeterias as favorites and switch between them instantly in the top horizontal bar.
- **Weekly Monday–Friday Strip**: Day tabs with date and "Heute" badge.
- **Normalized Food Categories**: Dishes grouped into *Tagesgerichte & Klassiker*, *Pastatheke & Wok*, *Vegetarisch & Vegan*, and *Dessert & Snacks*.
- **Interactive 5-Star Ratings**: View community average ratings and submit your own 1-to-5 star reviews directly in the app.
- **Dietary Badges & Allergen Details**: Vegan 🌱, Vegi 🧀, Geflügel 🍗, Schwein 🐷, Rind 🥩, Fisch 🐟.
- **Offline Week Caching**: Menus are automatically cached to disk so you can view the week's dishes inside campus basements with no reception.

### 🎓 3. Grades & ECTS Tracker (With Pass/Fail Support)
- Local SwiftData persistence (`cloudKitDatabase: .none`).
- Weighted German GPA calculation (`Sum(grade * ects) / Sum(ects for graded modules)`).
- **Pass/Fail & Unbenotete Scheine**: Support for non-graded modules (Praktika, Kolloquien, Sprachkurse) that count toward degree ECTS without distorting weighted GPA.
- Circular degree progress gauge towards your credit goal (180 ECTS Bachelor, 120 ECTS Master, 240 ECTS Staatsexamen/Diplom).
- Semester-grouped courses with swipe-to-delete.

### 🏛️ 4. Unified Campus Hub & Study Spaces (New!)
- **Bibliotheken & Auslastung**:
  - Live library directory (Philologicum, UB Hauptgebäude, Historicum, WiWi & Statistik, Juridicum, MINT Theresienstr., Martinsried).
  - **Live Occupancy Gauge**: Real-time capacity bar (🟢 Viele Plätze frei, 🟡 Mäßig belegt, 🔴 Fast voll).
  - **Dynamic Opening Hours**: Automatically detects whether a library is currently open or closed based on current time.
  - **Facility Badges**: 🖨️ Drucker/Scanner, 🤫 Stille Zone, 👥 Gruppenräume, 🔌 Steckdosen, 💻 CIP-Pool.
  - **One-Tap Seat Booking**: Direct Anny reservation modal with embedded `WKWebView` or Safari SSO.
- **Semesterfristen & Countdown (Timeline)**:
  - Tracks critical dates: Rückmeldefrist & Semesterbeitrag (with days-remaining alerts), Vorlesungszeit, Prüfungsanmeldung, Klausurenphase, and Semesterferien.
  - Direct EventKit export: Save deadlines to Apple Calendar with 3-day and 1-day reminder alarms.
- **Campus-Portale (Quick-Links)**:
  - Instant access to Moodle, LSF, LRZ Webmail, UB OPAC, Eduroam VPN, ZHS Hochschulsport, U-Kino, and Studierendenwerk.
- **Raum-Finder & Interaktive LMU-Karte**:
  - **In-App Raumfinder (Leaflet/Angular)**: Interaktive Campus-Karte direkt in UniDash mit Schnellzugriff auf Hauptgebäude (`bw0000`), MINT Theresienstr. (`bw1003`), Leopoldstr. (`bw0601`), Oettingenstr. (`bw7070`), WiWi, Juridicum und Martinsried.
  - **Intelligenter Raum-Decoder**: Übersetzt Raumstrings (z. B. `B 201`, `A 014`, `Theresienstr. 39`) in Trakt, Stockwerk und generiert einen 1-Tap-Sprung zur internen LMU-Raumkarte oder Apple Maps.

---

## 🚀 Running the App

### Auf deinem Mac (macOS 14+)
1. **Direkt aus `/Applications` starten:**
   Die App ist direkt unter `/Applications/UniDash.app` installiert und kann per Spotlight, Finder oder Launchpad geöffnet werden.
2. **Aus dem Terminal:**
   ```bash
   open /Applications/UniDash.app
   ```
3. **In Xcode entwickeln:**
   Projekt unter [`UniDash.xcodeproj`](UniDash.xcodeproj) öffnen, Schema `UniDash_macOS` wählen und **`Cmd + R`** drücken.

### Auf deinem iPhone (iOS 17+)
1. Öffne [`UniDash.xcodeproj`](UniDash.xcodeproj) in Xcode.
2. Wähle Target **`UniDash_iOS`** und Destination dein Gerät (oder einen Simulator).
3. Drücke **`Cmd + R`** (oder klicke **▶**).
