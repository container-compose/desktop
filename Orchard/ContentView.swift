//
//  ContentView.swift
//  Orchard
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
    @State private var showOnlyRunning: Bool = false
    @State private var refreshTimer: Timer?

    // Computed property for current resource title
    private var currentResourceTitle: String {
        switch selectedTab {
        case .containers:
            if let selectedContainer = selectedContainer {
                return selectedContainer
            }
            return ""
        case .images:
            if let selectedImage = selectedImage {
                // Extract image name from reference for cleaner display
                let components = selectedImage.split(separator: "/")
                if let lastComponent = components.last {
                    return String(lastComponent.split(separator: ":").first ?? lastComponent)
                }
                return selectedImage
            }
            return ""
        case .mounts:
            if let selectedMount = selectedMount,
               let mount = containerService.allMounts.first(where: { $0.id == selectedMount }) {
                return URL(fileURLWithPath: mount.mount.source).lastPathComponent
            }
            return ""
        }
    }

    // Get current container for title bar controls
    private var currentContainer: Container? {
        guard selectedTab == .containers, let selectedContainer = selectedContainer else { return nil }
        return containerService.containers.first { $0.configuration.id == selectedContainer }
    }

    // Get current image for title bar display
    private var currentImage: ContainerImage? {
        guard selectedTab == .images, let selectedImage = selectedImage else { return nil }
        return containerService.images.first { $0.reference == selectedImage }
    }

    // Get current mount for title bar display
    private var currentMount: ContainerMount? {
        guard selectedTab == .mounts, let selectedMount = selectedMount else { return nil }
        return containerService.allMounts.first { $0.id == selectedMount }
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
                return "cube.transparent"
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
        .navigationTitle(currentResourceTitle)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Resource-specific controls in title bar
                if let container = currentContainer {
                    // Container status
                    HStack(spacing: 4) {
                        Circle()
                            .fill(container.status.lowercased() == "running" ? .green : .gray)
                            .frame(width: 8, height: 8)
                        Text(container.status.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    ContainerControlButton(
                        container: container,
                        isLoading: containerService.loadingContainers.contains(
                            container.configuration.id),
                        onStart: {
                            Task { @MainActor in
                                await containerService.startContainer(container.configuration.id)
                            }
                        },
                        onStop: {
                            Task { @MainActor in
                                await containerService.stopContainer(container.configuration.id)
                            }
                        }
                    )
                    .padding(.horizontal, 16)

                    Spacer()
                    
                    HStack(spacing: 8) {
                        if container.status.lowercased() != "running" {
                            ContainerRemoveButton(
                                container: container,
                                isLoading: containerService.loadingContainers.contains(
                                    container.configuration.id),
                                onRemove: {
                                    Task { @MainActor in
                                        await containerService.removeContainer(container.configuration.id)
                                    }
                                }
                            )
                            .padding(.trailing, 32)
                        }
                    }

                } else if let image = currentImage {

                    // no real actions or conveniences here yet
                    
                } else if let mount = currentMount {

                    Button("Open in Finder") {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(mount.mount.source, forType: .string)
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()
                
                systemStatusView
                    .padding(.leading, 8)
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
                    .tag(container.configuration.id)
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

            VStack(alignment: .leading) {

                Toggle("Only show running containers", isOn: $showOnlyRunning)
                    .toggleStyle(CheckboxToggleStyle())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)

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

        // Apply running filter
        if showOnlyRunning {
            filtered = filtered.filter { $0.status.lowercased() == "running" }
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
            // Images list
            List(selection: $selectedImage) {
                ForEach(filteredImages, id: \.reference) { image in
                    ContainerImageRow(image: image)
                        .tag(image.reference)
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
