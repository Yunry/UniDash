//
//  AdaptiveRootView.swift
//  UniDash
//
//  Adaptive navigation root presenting TabView on iOS and NavigationSplitView on macOS.
//

import SwiftUI

struct AdaptiveRootView: View {
    @State private var selectedDestination: AppDestination = .timetable

    var body: some View {
        #if os(iOS)
        iosTabView
        #elseif os(macOS)
        macSplitView
        #else
        iosTabView
        #endif
    }

    // MARK: - iOS Tab Bar Layout
    @ViewBuilder
    private var iosTabView: some View {
        TabView(selection: $selectedDestination) {
            TimetableCalendarView()
                .tabItem {
                    Label(AppDestination.timetable.title, systemImage: AppDestination.timetable.icon)
                }
                .tag(AppDestination.timetable)

            GradesDashboardView()
                .tabItem {
                    Label(AppDestination.grades.title, systemImage: AppDestination.grades.icon)
                }
                .tag(AppDestination.grades)

            MensaMenuView()
                .tabItem {
                    Label(AppDestination.mensa.title, systemImage: AppDestination.mensa.icon)
                }
                .tag(AppDestination.mensa)

            RoomBookingView()
                .tabItem {
                    Label(AppDestination.rooms.title, systemImage: AppDestination.rooms.icon)
                }
                .tag(AppDestination.rooms)
        }
        .tint(.blue)
    }

    // MARK: - macOS Sidebar Navigation Split View
    #if os(macOS)
    @ViewBuilder
    private var macSplitView: some View {
        NavigationSplitView {
            List(AppDestination.allCases, selection: Binding(
                get: { selectedDestination },
                set: { if let val = $0 { selectedDestination = val } }
            )) { destination in
                NavigationLink(value: destination) {
                    Label(destination.title, systemImage: destination.icon)
                }
                .keyboardShortcut(destination.keyboardShortcutKey, modifiers: .command)
            }
            .navigationTitle("UniDash")
            .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
        } detail: {
            destinationView(for: selectedDestination)
        }
    }
    #endif

    @ViewBuilder
    private func destinationView(for destination: AppDestination) -> some View {
        switch destination {
        case .timetable:
            TimetableCalendarView()
        case .grades:
            GradesDashboardView()
        case .mensa:
            MensaMenuView()
        case .rooms:
            RoomBookingView()
        }
    }
}
