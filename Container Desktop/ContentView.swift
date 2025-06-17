//
//  ContentView.swift
//  Container Desktop
//
//  Created by Andrew Waters on 16/06/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var containerService: ContainerService
    @State private var selection: String?
    @State private var selectedContainer: String?
    @State private var selectedImage: String?

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
            await containerService.loadImages()
            await containerService.loadBuilders()
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
            await containerService.loadImages()
            await containerService.loadBuilders()
        }
    }

    private var sidebarView: some View {
        VStack {
            navigationList
            Spacer()
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
                    .badge(containerService.images.count)
            }
            NavigationLink(value: "volumes") {
                Text("Volumes")
            }
            NavigationLink(value: "builders") {
                Text("Builder")
            }
            NavigationLink(value: "registry") {
                Text("Registry")
            }
        }
    }

    private var systemStatusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(containerService.systemStatus.color)
                    .frame(width: 12, height: 12)
                Text("Container \(containerService.systemStatus.text)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .padding()
    }

    @ViewBuilder
    private var contentView: some View {
        switch selection {
        case "containers":
            containersList
        case "images":
            imagesList
        case "volumes":
            Text("volumes list")
        case "builders":
            Text("Select Builder in detail view")
                .foregroundColor(.secondary)
        case "registry":
            Text("registry list")
        case "system":
            Text("system list")
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
                // Filter picker at top
                Picker("", selection: $filterSelection) {
                    ForEach(ContainerFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            Divider()

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
                        }
                    )
                }
            }
            .listStyle(PlainListStyle())
            .animation(.easeInOut(duration: 0.15), value: filteredContainers.count)

            Divider()

            // Search field at bottom
            VStack(spacing: 12) {
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
            // Title bar
            HStack {
                Text("Available Images")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            Divider()

            // Images list
            List(selection: $selectedImage) {
                ForEach(filteredImages, id: \.reference) { image in
                    ContainerImageRow(image: image)
                }
            }
            .listStyle(PlainListStyle())
            .animation(.easeInOut(duration: 0.15), value: filteredImages.count)

            Divider()

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
        switch selection {
        case "containers":
            containerDetailView
        case "images":
            imageDetailView
        case "volumes":
            Text("volume")
        case "builders":
            builderDetailView
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

    @ViewBuilder
    private var imageDetailView: some View {
        ForEach(containerService.images, id: \.reference) { image in
            if selectedImage == image.reference {
                ContainerImageDetailView(image: image)
            }
        }
    }

    @ViewBuilder
    private var builderDetailView: some View {
        if containerService.builders.isEmpty {
            // No builder exists - show start interface
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "hammer.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No Builder Running")
                        .font(.title2)
                        .fontWeight(.medium)

                    Text("Start the container builder to build images locally")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button(action: {
                    Task { @MainActor in
                        await containerService.startBuilder()
                    }
                }) {
                    HStack {
                        if containerService.isBuilderLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 16, height: 16)
                        } else {
                            SwiftUI.Image(systemName: "play.fill")
                        }
                        Text("Start Builder")
                    }
                    .frame(minWidth: 120)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(containerService.isBuilderLoading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else if let builder = containerService.builders.first {
            BuilderDetailView(builder: builder)
                .environmentObject(containerService)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ContainerService())
}
