//
//  ContentView.swift
//  Container Desktop
//
//  Created by Andrew Waters on 16/06/2025.
//

import SwiftExec
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var containerService: ContainerService
    @State private var selection: String?
    @State private var selectedContainer: String?
    @State private var searchText: String = ""
    @State private var filterSelection: ContainerFilter = .all

    enum ContainerFilter: String, CaseIterable {
        case all = "All"
        case running = "Running"
        case stopped = "Stopped"
    }

    var body: some View {
        Group {
            if containerService.systemStatus == .stopped {
                emptyStateView
            } else {
                mainInterfaceView
            }
        }
        .onAppear {
            // Set default selections when app launches
            if selection == nil {
                selection = "containers"
            }
        }
        .onChange(of: containerService.containers) { _, newContainers in
            // Auto-select first container when containers load
            if selectedContainer == nil && !newContainers.isEmpty {
                selectedContainer = newContainers[0].configuration.id
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            PowerButton(
                isLoading: containerService.isSystemLoading,
                action: {
                    Task { @MainActor in
                        await containerService.startSystem()
                    }
                }
            )

            Text("Container is not currently runnning")
                .font(.title2)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .task {
            await containerService.checkSystemStatus()
            await containerService.loadContainers()
        }
    }

    private var mainInterfaceView: some View {
        NavigationSplitView {
            sidebarView
        } content: {
            contentView
        } detail: {
            detailView
        }
        .task {
            await containerService.checkSystemStatus()
            await containerService.loadContainers()
        }
    }

    private var sidebarView: some View {
        VStack {
            navigationList
            Divider()
            systemStatusSection
        }
    }

    private var navigationList: some View {
        List(selection: $selection) {
            NavigationLink(value: "containers") {
                Text("Containers")
                    .badge(containerService.containers.count)
            }
            NavigationLink(value: "images") {
                Text("Images")
            }
            NavigationLink(value: "volumes") {
                Text("Volumes")
            }
            NavigationLink(value: "builds") {
                Text("Builds")
            }
            NavigationLink(value: "registry") {
                Text("Registry")
            }
        }
    }

    private var systemStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(containerService.systemStatus.color)
                    .frame(width: 8, height: 8)
                Text("Containers \(containerService.systemStatus.text)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var contentView: some View {
        switch selection {
        case "containers":
            containersList
        case "images":
            Text("images list")
        case "volumes":
            Text("volumes list")
        case "builds":
            Text("builds list")
        case "registry":
            Text("registry list")
        case .none:
            Text("select")
        case .some(_):
            Text("select")
        }
    }

    private var containersList: some View {
        VStack(spacing: 0) {
            // Title bar
            VStack(spacing: 12) {
                    // Filter picker
                    Picker("", selection: $filterSelection) {
                        ForEach(ContainerFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            // Search field
            HStack {
                SwiftUI.Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Filter by name...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(.black))

            Divider()

            // Container list
            List(selection: $selectedContainer) {
                ForEach(filteredContainers, id: \.configuration.id) { container in
                    ContainerRow(
                        container: container,
                        isLoading: containerService.loadingContainers.contains(container.configuration.id),
                        stopContainer: { id in
                            Task { @MainActor in
                                await containerService.stopContainer(id)
                            }
                        },
                        startContainer: { id in
                            Task { @MainActor in
                                await containerService.startContainer(id)
                            }
                        }
                    )
                }
            }
            .listStyle(PlainListStyle())
            .animation(.easeInOut(duration: 0.15), value: filteredContainers.count)

        }
    }

    private var filteredContainers: [Container] {
        var filtered = containerService.containers

        // Apply status filter
        switch filterSelection {
        case .all:
            break
        case .running:
            filtered = filtered.filter { $0.status.lowercased() == "running" }
        case .stopped:
            filtered = filtered.filter { $0.status.lowercased() != "running" }
        }

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { container in
                container.configuration.id.localizedCaseInsensitiveContains(searchText) ||
                container.status.localizedCaseInsensitiveContains(searchText)
            }
        }

        return filtered
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case "containers":
            containerDetailView
        case "images":
            Text("image")
        case "volumes":
            Text("volume")
        case "builds":
            Text("build")
        case "registry":
            Text("registry")
        case "system":
            Text("system")
        case .none:
            Text("select")
        case .some(_):
            Text("select")
        }
    }

    @ViewBuilder
    private var containerDetailView: some View {
        ForEach(containerService.containers, id: \.configuration.id) { container in
            if selectedContainer == container.configuration.id {
                ContainerDetailView(container: container)
                    .environmentObject(containerService)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ContainerService())
}
