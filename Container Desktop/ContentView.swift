//
//  ContentView.swift
//  Container Desktop
//
//  Created by Andrew Waters on 16/06/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var containerService: ContainerService
    @State private var selectedTab: TabSelection = .containers
    @State private var selectedContainer: String?
    @State private var selectedImage: String?
    @State private var selectedMount: String?

    @State private var searchText: String = ""
    @State private var filterSelection: ContainerFilter = .all
    @State private var refreshTimer: Timer?

    enum ContainerFilter: String, CaseIterable {
        case all = "All"
        case running = "Running"
        case stopped = "Stopped"
    }

    enum TabSelection: String, CaseIterable {
        case containers = "containers"
        case images = "images"
        case mounts = "mounts"

        var icon: String {
            switch self {
            case .containers:
                return "cube.box"
            case .images:
                return "square.3.layers.3d"
            case .mounts:
                return "externaldrive"
            }
        }

        var title: String {
            switch self {
            case .containers:
                return "Containers"
            case .images:
                return "Images"
            case .mounts:
                return "Mounts"
            }
        }
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
            // Default tab is already set to containers
        }
        .onChange(of: containerService.containers) { _, newContainers in
            // Auto-select first container when containers load
            if selectedContainer == nil && !newContainers.isEmpty {
                selectedContainer = newContainers[0].configuration.id
            }
            if selectedMount == nil && !containerService.allMounts.isEmpty {
                selectedMount = containerService.allMounts[0].id
            }
        }

        .onReceive(
            NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToContainer"))
        ) { notification in
            if let containerId = notification.object as? String {
                // Switch to containers view and select the specific container
                selectedTab = .containers
                selectedContainer = containerId
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToImage"))
        ) { notification in
            if let imageReference = notification.object as? String {
                // Switch to images view and select the specific image
                selectedTab = .images
                selectedImage = imageReference
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToMount"))
        ) { notification in
            if let mountId = notification.object as? String {
                // Switch to mounts view and select the specific mount
                selectedTab = .mounts
                selectedMount = mountId
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
            await containerService.loadImages()
            await containerService.loadBuilders()
        }
    }

    private var mainInterfaceView: some View {
        NavigationSplitView {
            primaryColumnView
                .navigationSplitViewColumnWidth(
                    min: 400, ideal: 500, max: 600)
        } detail: {
            detailView
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                systemStatusView
                    .padding(.trailing, 8)
            }
        }
        .task {
            await containerService.checkSystemStatus()
            await containerService.loadContainers()
            await containerService.loadImages()
            await containerService.loadBuilders()

            // Set up periodic refresh timer
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                Task { @MainActor in
                    await containerService.checkSystemStatus()
                    await containerService.loadContainers()
                    await containerService.loadImages()
                    await containerService.loadBuilders()
                }
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    private var primaryColumnView: some View {
        VStack(spacing: 0) {
            Divider()
            tabNavigationView
            Divider()
            selectedContentView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tabNavigationView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                ForEach(TabSelection.allCases, id: \.self) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 0.5)
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func tabButton(for tab: TabSelection) -> some View {
        Button(action: {
            selectedTab = tab
        }) {
            HStack(spacing: 6) {
                SwiftUI.Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .medium))
                Text(tab.title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(selectedTab == tab ? .blue : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }



    private var selectedContentView: some View {
        Group {
            switch selectedTab {
            case .containers:
                containersList
            case .images:
                imagesList
            case .mounts:
                mountsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var systemStatusView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(containerService.systemStatus.color)
                .frame(width: 10, height: 10)
                .help("Container System: \(containerService.systemStatus.text)")

            Circle()
                .fill(containerService.builderStatus.color)
                .frame(width: 10, height: 10)
                .help("Builder: \(containerService.builderStatus.text)")
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }










    private var containersList: some View {
        VStack(spacing: 0) {

            // Container list
            List(selection: $selectedContainer) {
                ForEach(filteredContainers, id: \.configuration.id) { container in
                    ContainerRow(
                        container: container,
                        isLoading: containerService.loadingContainers.contains(
                            container.configuration.id),
                        stopContainer: { id in
                            Task { @MainActor in
                                await containerService.stopContainer(id)
                            }
                        },
                        startContainer: { id in
                            Task { @MainActor in
                                await containerService.startContainer(id)
                            }
                        },
                        removeContainer: { id in
                            Task { @MainActor in
                                await containerService.removeContainer(id)
                            }
                        }
                    )
                }
            }
            .listStyle(PlainListStyle())
            .animation(.easeInOut(duration: 0.3), value: containerService.containers)

            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 0.5)
                .transaction { transaction in
                    transaction.animation = nil
                }

            VStack(spacing: 12) {

                Picker("", selection: $filterSelection) {
                    ForEach(ContainerFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())

                HStack {
                    SwiftUI.Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Filter containers...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.black))
                .cornerRadius(6)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
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
                container.configuration.id.localizedCaseInsensitiveContains(searchText)
                    || container.status.localizedCaseInsensitiveContains(searchText)
            }
        }

        return filtered
    }

    private var imagesList: some View {
        VStack(spacing: 0) {
            // // Title bar
            // HStack {
            //     Text("Available Images")
            //         .font(.title2)
            //         .fontWeight(.semibold)
            //     Spacer()
            // }
            // .padding()
            // .background(Color(.windowBackgroundColor))

            // Divider()

            // Images list
            List(selection: $selectedImage) {
                ForEach(filteredImages, id: \.reference) { image in
                    ContainerImageRow(image: image)
                }
            }
            .listStyle(PlainListStyle())
            .animation(.easeInOut(duration: 0.3), value: containerService.images)



            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 0.5)
                .transaction { transaction in
                    transaction.animation = nil
                }

            // Filter controls at bottom
            VStack(spacing: 12) {
                // Search field
                HStack {
                    SwiftUI.Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Filter images...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.black))
                .cornerRadius(6)
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
        }
    }

    private var filteredImages: [ContainerImage] {
        var filtered = containerService.images

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { image in
                image.reference.localizedCaseInsensitiveContains(searchText)
            }
        }

        return filtered
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .containers:
            containerDetailView
        case .images:
            imageDetailView
        case .mounts:
            mountDetailView
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

    @ViewBuilder
    private var imageDetailView: some View {
        ForEach(containerService.images, id: \.reference) { image in
            if selectedImage == image.reference {
                ContainerImageDetailView(image: image)
                    .environmentObject(containerService)
            }
        }
    }

    private var mountsList: some View {
        VStack(spacing: 0) {
            // Mounts list
            List(selection: $selectedMount) {
                ForEach(filteredMounts, id: \.id) { mount in
                    MountRow(mount: mount)
                        .tag(mount.id)
                }
            }
            .listStyle(PlainListStyle())
            .animation(.easeInOut(duration: 0.3), value: containerService.allMounts)

            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 0.5)
                .transaction { transaction in
                    transaction.animation = nil
                }

            // Filter controls at bottom
            VStack(spacing: 12) {
                // Search field
                HStack {
                    SwiftUI.Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Filter mounts...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.black))
                .cornerRadius(6)
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
        }
    }

    private var filteredMounts: [ContainerMount] {
        var filtered = containerService.allMounts

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { mount in
                mount.mount.source.localizedCaseInsensitiveContains(searchText)
                    || mount.mount.destination.localizedCaseInsensitiveContains(searchText)
                    || mount.mountType.localizedCaseInsensitiveContains(searchText)
            }
        }

        return filtered
    }

    @ViewBuilder
    private var mountDetailView: some View {
        ForEach(containerService.allMounts, id: \.id) { mount in
            if selectedMount == mount.id {
                MountDetailView(mount: mount)
                    .environmentObject(containerService)
            }
        }
    }


}

#Preview {
    ContentView()
        .environmentObject(ContainerService())
}
