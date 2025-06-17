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
                Text("Containers is \(containerService.systemStatus.text)")
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
                Menu("Containers (\(containerService.containers.count))") {
                    ForEach(containerService.containers, id: \.configuration.id) { container in
                        Menu {
                            // Container status
                            HStack {
                                Circle()
                                    .fill(container.status.lowercased() == "running" ? .green : .gray)
                                    .frame(width: 8, height: 8)
                                Text("Status: \(container.status)")
                            }
                            .foregroundColor(.secondary)

                            Divider()

                            // Copy IP address
                            if !container.networks.isEmpty {
                                Button("Copy IP Address") {
                                    let pasteboard = NSPasteboard.general
                                    pasteboard.clearContents()
                                    let ipAddress = container.networks[0].address.replacingOccurrences(of: "/24", with: "")
                                    pasteboard.setString(ipAddress, forType: .string)
                                }
                            }

                            // Start/Stop container
                            if containerService.loadingContainers.contains(container.configuration.id) {
                                Text("Loading...")
                                    .foregroundColor(.gray)
                            } else if container.status.lowercased() == "running" {
                                Button("Stop Container") {
                                    Task { @MainActor in
                                        await containerService.stopContainer(container.configuration.id)
                                    }
                                }
                            } else {
                                Button("Start Container") {
                                    Task { @MainActor in
                                        await containerService.startContainer(container.configuration.id)
                                    }
                                }
                            }
                        } label: {
                            Label {
                                Text(container.configuration.id)
                            } icon: {
                                Circle()
                                    .fill(container.status.lowercased() == "running" ? .green : .gray)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
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
