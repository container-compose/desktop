//
//  Container_DesktopApp.swift
//  Container Desktop
//
//  Created by Andrew Waters on 16/06/2025.
//

import SwiftUI

@main
struct Container_DesktopApp: App {
    @StateObject private var containerService = ContainerService()
    @StateObject private var menuBarManager = MenuBarManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(containerService)
        }

        MenuBarExtra("Container Desktop", systemImage: "cube.box") {
            MenuBarView()
                .environmentObject(containerService)
        }
    }
}

class MenuBarManager: ObservableObject {
    // Manager for menu bar state if needed
}

struct MenuBarView: View {
    @EnvironmentObject var containerService: ContainerService
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // System Status
            HStack {
                Circle()
                    .fill(containerService.systemStatus.color)
                    .frame(width: 8, height: 8)
                Text("System: \(containerService.systemStatus.text)")
                    .font(.caption)
            }

            Divider()

            // System Controls
            Button("Start System") {
                Task { @MainActor in
                    await containerService.startSystem()
                }
            }
            .disabled(containerService.isSystemLoading || containerService.systemStatus == .running)

            Button("Stop System") {
                Task { @MainActor in
                    await containerService.stopSystem()
                }
            }
            .disabled(containerService.isSystemLoading || containerService.systemStatus == .stopped)

            Button("Restart System") {
                Task { @MainActor in
                    await containerService.restartSystem()
                }
            }
            .disabled(containerService.isSystemLoading || containerService.systemStatus == .stopped)

            Divider()

            // Container Controls
            if !containerService.containers.isEmpty {
                Text("Containers (\(containerService.containers.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(containerService.containers.prefix(5), id: \.configuration.id) { container in
                    HStack {
                        Circle()
                            .fill(container.status == "running" ? .green : .gray)
                            .frame(width: 6, height: 6)
                        Text(container.configuration.hostname ?? "Unknown")
                            .font(.caption)
                        Spacer()
                        if container.status == "running" {
                            Button("Stop") {
                                Task { @MainActor in
                                    await containerService.stopContainer(container.configuration.id)
                                }
                            }
                            .buttonStyle(.borderless)
                            .font(.caption2)
                        }
                    }
                }

                if containerService.containers.count > 5 {
                    Text("+ \(containerService.containers.count - 5) more...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Divider()
            }

            // App Controls
            Button("Show Main Window") {
                if let window = NSApplication.shared.keyWindow {
                    window.makeKeyAndOrderFront(nil)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(8)
        .frame(width: 200)
        .task {
            await containerService.checkSystemStatus()
            await containerService.loadContainers()

            // Set up periodic refresh
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                Task { @MainActor in
                    await containerService.checkSystemStatus()
                    await containerService.loadContainers()
                }
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }
}
