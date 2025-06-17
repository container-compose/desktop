//
//  ContentView.swift
//  Container Desktop
//
//  Created by Andrew Waters on 16/06/2025.
//

import SwiftExec
import SwiftUI

// MARK: - Container Service
class ContainerService: ObservableObject {
    @Published var containers: [Container] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var systemStatus: SystemStatus = .unknown
    @Published var isSystemLoading: Bool = false
    @Published var loadingContainers: Set<String> = []

    enum SystemStatus {
        case unknown
        case stopped
        case running

        var color: Color {
            switch self {
            case .unknown, .stopped:
                return .gray
            case .running:
                return .green
            }
        }

        var text: String {
            switch self {
            case .unknown:
                return "Unknown"
            case .stopped:
                return "Stopped"
            case .running:
                return "Running"
            }
        }
    }

    func loadContainers() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        var result: ExecResult
        do {
            result = try exec(
                program: "/usr/local/bin/container",
                arguments: ["ls", "--format", "json"])
        } catch {
            let error = error as! ExecError
            result = error.execResult
        }

        do {
            let data = result.stdout?.data(using: .utf8)
            let newContainers = try JSONDecoder().decode(
                Containers.self, from: data!)

            await MainActor.run {
                // Only update if containers have actually changed
                if !areContainersEqual(self.containers, newContainers) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.containers = newContainers
                    }
                }
                self.isLoading = false
            }

            for container in newContainers {
                print("Container: \(container.configuration.id), Status: \(container.status)")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            print(error)
        }
    }

    private func areContainersEqual(_ old: [Container], _ new: [Container]) -> Bool {
        return old == new
    }

    func stopContainer(_ id: String) async {
        await MainActor.run {
            loadingContainers.insert(id)
            errorMessage = nil
        }

        var result: ExecResult
        do {
            result = try exec(
                program: "/usr/local/bin/container",
                arguments: ["stop", id])

            await MainActor.run {
                if !result.failed {
                    print("Container \(id) stop command sent successfully")
                    // Keep loading state and refresh containers to check status
                    Task {
                        await refreshUntilContainerStopped(id)
                    }
                } else {
                    self.errorMessage = "Failed to stop container: \(result.stderr ?? "Unknown error")"
                    loadingContainers.remove(id)
                }
            }

        } catch {
            let error = error as! ExecError
            result = error.execResult

            await MainActor.run {
                loadingContainers.remove(id)
                self.errorMessage = "Failed to stop container: \(error.localizedDescription)"
            }
            print("Error stopping container: \(error)")
        }
    }

    func checkSystemStatus() async {
        var result: ExecResult
        do {
            result = try exec(
                program: "/usr/local/bin/container",
                arguments: ["ls"])

            await MainActor.run {
                // Assuming the command returns success when running
                self.systemStatus = .running
            }
        } catch {
            await MainActor.run {
                self.systemStatus = .stopped
            }
        }
    }

    func startSystem() async {
        await MainActor.run {
            isSystemLoading = true
            errorMessage = nil
        }

        var result: ExecResult
        do {
            result = try exec(
                program: "/usr/local/bin/container",
                arguments: ["system", "start"])

            await MainActor.run {
                self.isSystemLoading = false
                self.systemStatus = .running
            }

            print("Container system started successfully")
            await loadContainers()

        } catch {
            let error = error as! ExecError
            result = error.execResult

            await MainActor.run {
                self.errorMessage = "Failed to start system: \(error.localizedDescription)"
                self.isSystemLoading = false
            }
            print("Error starting system: \(error)")
        }
    }

    func stopSystem() async {
        await MainActor.run {
            isSystemLoading = true
            errorMessage = nil
        }

        var result: ExecResult
        do {
            result = try exec(
                program: "/usr/local/bin/container",
                arguments: ["system", "stop"])

            await MainActor.run {
                self.isSystemLoading = false
                self.systemStatus = .stopped
                self.containers.removeAll()
            }

            print("Container system stopped successfully")

        } catch {
            let error = error as! ExecError
            result = error.execResult

            await MainActor.run {
                self.errorMessage = "Failed to stop system: \(error.localizedDescription)"
                self.isSystemLoading = false
            }
            print("Error stopping system: \(error)")
        }
    }

    func restartSystem() async {
        await MainActor.run {
            isSystemLoading = true
            errorMessage = nil
        }

        var result: ExecResult
        do {
            result = try exec(
                program: "/usr/local/bin/container",
                arguments: ["system", "restart"])

            await MainActor.run {
                self.isSystemLoading = false
                self.systemStatus = .running
            }

            print("Container system restarted successfully")
            await loadContainers()

        } catch {
            let error = error as! ExecError
            result = error.execResult

            await MainActor.run {
                self.errorMessage = "Failed to restart system: \(error.localizedDescription)"
                self.isSystemLoading = false
            }
            print("Error restarting system: \(error)")
        }
    }

    // Future commands can be added here
    func startContainer(_ id: String) async {
        await MainActor.run {
            loadingContainers.insert(id)
            errorMessage = nil
        }

        var result: ExecResult
        do {
            result = try exec(
                program: "/usr/local/bin/container",
                arguments: ["start", id])
        } catch {
            let error = error as! ExecError
            result = error.execResult
        }

        await MainActor.run {
            if !result.failed {
                print("Container \(id) start command sent successfully")
                // Keep loading state and refresh containers to check status
                Task {
                    await refreshUntilContainerStarted(id)
                }
            } else {
                self.errorMessage = "Failed to start container: \(result.stderr ?? "Unknown error")"
                loadingContainers.remove(id)
            }
        }
    }

    private func refreshUntilContainerStopped(_ id: String) async {
        var attempts = 0
        let maxAttempts = 10

        while attempts < maxAttempts {
            await loadContainers()

            // Check if container is now stopped
            let shouldStop = await MainActor.run {
                if let container = containers.first(where: { $0.configuration.id == id }) {
                    print("Checking stop status for \(id): \(container.status)")
                    return container.status.lowercased() != "running"
                } else {
                    print("Container \(id) not found, assuming stopped")
                    return true // Container not found, assume it stopped
                }
            }

            if shouldStop {
                await MainActor.run {
                    print("Container \(id) has stopped, removing loading state")
                    loadingContainers.remove(id)
                }
                return
            }

            attempts += 1
            print("Container \(id) still running, attempt \(attempts)/\(maxAttempts)")
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        // Timeout reached, remove loading state
        await MainActor.run {
            print("Timeout reached for container \(id), removing loading state")
            loadingContainers.remove(id)
        }
    }

    private func refreshUntilContainerStarted(_ id: String) async {
        var attempts = 0
        let maxAttempts = 10

        while attempts < maxAttempts {
            await loadContainers()

            // Check if container is now running
            let isRunning = await MainActor.run {
                if let container = containers.first(where: { $0.configuration.id == id }) {
                    print("Checking start status for \(id): \(container.status)")
                    return container.status.lowercased() == "running"
                }
                return false
            }

            if isRunning {
                await MainActor.run {
                    print("Container \(id) has started, removing loading state")
                    loadingContainers.remove(id)
                }
                return
            }

            attempts += 1
            print("Container \(id) not running yet, attempt \(attempts)/\(maxAttempts)")
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        // Timeout reached, remove loading state
        await MainActor.run {
            print("Timeout reached for container \(id), removing loading state")
            loadingContainers.remove(id)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var containerService: ContainerService
    @State private var selection: String?
    @State private var selectedContainer: String?

    var body: some View {
        if containerService.systemStatus == .stopped {
            emptyStateView
        } else {
            mainInterfaceView
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
            NavigationLink(value: "system") {
                Text("System")
            }
        }
    }

    private var systemStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(containerService.systemStatus.color)
                    .frame(width: 8, height: 8)
                Text("System: \(containerService.systemStatus.text)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            HStack(spacing: 4) {
                Button("Stop") {
                    Task { @MainActor in
                        await containerService.stopSystem()
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .disabled(
                    containerService.isSystemLoading
                        || containerService.systemStatus == .stopped)

                Button("Restart") {
                    Task { @MainActor in
                        await containerService.restartSystem()
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .disabled(containerService.isSystemLoading || containerService.systemStatus == .stopped)

                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
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
        case "system":
            Text("system list")
        case .none:
            Text("select")
        case .some(_):
            Text("select")
        }
    }

    private var containersList: some View {
        VStack {
            List(selection: $selectedContainer) {
                ForEach(containerService.containers, id: \.configuration.id) { container in
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
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: containerService.containers.count)
        }
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
                ScrollView {
                    VStack(alignment: .leading) {
                        containerInfoGrid(container: container)

                        Divider()

                        containerProcessInfo(container: container)

                        Divider()

                        containerUserInfo(container: container)

                        Spacer()
                    }
                }
            }
        }
    }

    private func containerInfoGrid(container: Container) -> some View {
        HStack(alignment: .top) {
            
            HStack {
                ContainerControlButton(
                    container: container,
                    isLoading: containerService.loadingContainers.contains(container.configuration.id),
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
                
                Spacer()
            }
            .padding()

            
            VStack(alignment: .leading) {
                Text(container.configuration.id)
                Text(
                    container.configuration.image.descriptor.digest
                        .replacingOccurrences(of: "sha256:", with: "").prefix(12))
                Text(String(container.configuration.image.descriptor.size))
            }

            Spacer()

            VStack(alignment: .leading) {
                Text(container.configuration.image.descriptor.mediaType)
                Text(container.configuration.image.reference)
                Text(
                    container.configuration.platform.os + "/"
                        + container.configuration.platform.architecture)
                Text(container.configuration.runtimeHandler)
            }

            Spacer()

            VStack(alignment: .leading) {
                Text("Hostname: " + (container.configuration.hostname ?? ""))

                Text(
                    "Nameservers: "
                        + container.configuration.dns.nameservers.joined())
                Text(
                    "Search Domains: "
                        + container.configuration.dns.searchDomains.joined())
                Text("Options: " + container.configuration.dns.options.joined())

                Divider()

                ForEach(container.networks, id: \.hostname) { network in
                    Text("Gateway: " + network.gateway)
                    Text("Hostname: " + network.hostname)
                    Text("Network: " + network.network)
                    Text("Address: " + network.address)
                    Divider()
                }
            }

            Spacer()

            VStack(alignment: .leading) {
                Text("Rosetta: " + String(container.configuration.rosetta))
                Text("CPUs: " + String(container.configuration.resources.cpus))
                Text(
                    "Memory: "
                        + String(container.configuration.resources.memoryInBytes))
            }

            Spacer()
        }
        .padding()
    }

    private func containerProcessInfo(container: Container) -> some View {
        VStack(alignment: .leading) {
            Text("Terminal: " + String(container.configuration.initProcess.terminal))
            Text(
                "Environment: "
                    + String(container.configuration.initProcess.environment.joined()))
            Text(
                "Working Directory: "
                    + String(container.configuration.initProcess.workingDirectory))
            Text(
                "Arguments: "
                    + String(container.configuration.initProcess.arguments.joined()))
            Text(
                "Executable: " + String(container.configuration.initProcess.executable))
        }
    }

    private func containerUserInfo(container: Container) -> some View {
        VStack(alignment: .leading) {
            Text(
                "User: "
                    + (container.configuration.initProcess.user.raw?.userString ?? ""))
            Text(
                "GID: " + String(container.configuration.initProcess.user.id?.gid ?? 0))
            Text(
                "UID: " + String(container.configuration.initProcess.user.id?.uid ?? 0))
        }
    }
}

struct ContainerRow: View {
    let container: Container
    let isLoading: Bool
    let stopContainer: (String) -> Void
    let startContainer: (String) -> Void

    private var networkAddress: String {
        guard !container.networks.isEmpty else {
            return "No network"
        }
        return container.networks[0].address.replacingOccurrences(of: "/24", with: "")
    }

    var body: some View {
        NavigationLink(value: container.configuration.id) {
            VStack(alignment: .leading) {
                Text(container.configuration.hostname ?? "Unknown")
                    .badge(container.status)
                Text(networkAddress)
                    .font(.subheadline)
                    .monospaced()
            }
        }
        .contextMenu {
            if !container.networks.isEmpty {
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(networkAddress, forType: .string)
                } label: {
                    Label("Copy IP address", systemImage: "network")
                }
            }

            ContainerControlButton(
                container: container,
                isLoading: isLoading,
                onStart: { startContainer(container.configuration.id) },
                onStop: { stopContainer(container.configuration.id) }
            )
        }
    }
}

struct PowerButton: View {
    let isLoading: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            SwiftUI.Image(systemName: "power")
                .font(SwiftUI.Font.system(size: 60))
                .foregroundColor(buttonColor)
                .scaleEffect(isHovered ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .help("Click to start the container system")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering && !isLoading
            }
        }
        .modifier(CursorModifier(cursor: isLoading ? .arrow : .pointingHand))
    }

    private var buttonColor: SwiftUI.Color {
        if isLoading {
            return SwiftUI.Color.white
        } else if isHovered {
            return SwiftUI.Color.blue
        } else {
            return SwiftUI.Color.gray
        }
    }
}

struct ContainerControlButton: View {
    let container: Container
    let isLoading: Bool
    let onStart: () -> Void
    let onStop: () -> Void

    private var buttonState: ButtonState {
        if isLoading {
            return .loading
        } else if container.status.lowercased() == "running" {
            return .stop
        } else {
            return .start
        }
    }

    @State private var isRotating: Bool = false

    private enum ButtonState {
        case start, stop, loading

        var icon: String {
            switch self {
            case .start: return "play.fill"
            case .stop: return "stop.fill"
            case .loading: return "arrow.2.circlepath"
            }
        }

        var helpText: String {
            switch self {
            case .start: return "Start Container"
            case .stop: return "Stop Container"
            case .loading: return "Loading..."
            }
        }

        var color: SwiftUI.Color {
            switch self {
            case .start: return .blue
            case .stop: return .red
            case .loading: return .gray
            }
        }
    }

    var body: some View {
        Button {
            switch buttonState {
            case .start:
                onStart()
            case .stop:
                onStop()
            case .loading:
                break // No action when loading
            }
        } label: {
            SwiftUI.Image(systemName: buttonState.icon)
                .font(.system(size: 20))
                .foregroundColor(buttonState.color)
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .animation(
                    buttonState == .loading
                        ? .linear(duration: 1.0).repeatForever(autoreverses: false)
                        : .default,
                    value: isRotating
                )
        }
        .buttonStyle(.plain)
        .disabled(buttonState == .loading)
        .help(buttonState.helpText)
        .modifier(CursorModifier(cursor: buttonState == .loading ? .arrow : .pointingHand))
        .onChange(of: buttonState) { _, newState in
            print("Container \(container.configuration.id) state changed to: \(newState), status: \(container.status), isLoading: \(isLoading)")
            isRotating = (newState == .loading)
        }
    }
}



struct CursorModifier: ViewModifier {
    let cursor: NSCursor

    func body(content: Content) -> some View {
        content
            .background(
                Rectangle()
                    .fill(Color.clear)
                    .onHover { hovering in
                        if hovering {
                            cursor.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
            )
    }
}

#Preview {
    ContentView()
        .environmentObject(ContainerService())
}

struct Container: Codable, Equatable {
    let status: String
    let configuration: ContainerConfiguration
    let networks: [Network]

    enum CodingKeys: String, CodingKey {
        case status = "status"
        case configuration = "configuration"
        case networks = "networks"
    }
}

struct ContainerConfiguration: Codable, Equatable {
    let id: String
    let hostname: String?
    let runtimeHandler: String
    let initProcess: initProcess
    let mounts: [Mount]
    let platform: Platform
    let image: Image
    let rosetta: Bool
    let dns: DNS
    let resources: Resources

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case hostname = "hostname"
        case runtimeHandler = "runtimeHandler"
        case initProcess = "initProcess"
        case mounts = "mounts"
        case platform = "platform"
        case image = "image"
        case rosetta = "rosetta"
        case dns = "dns"
        case resources = "resources"
    }
}

struct Mount: Codable, Equatable {
    let type: MountType
    let source: String
    let options: [String]
    let destination: String

    enum CodingKeys: String, CodingKey {
        case type = "type"
        case source = "source"
        case options = "options"
        case destination = "destination"
    }
}

struct MountType: Codable, Equatable {
    let tmpfs: Tmpfs?
    let virtiofs: Virtiofs?

    enum CodingKeys: String, CodingKey {
        case tmpfs = "tmpfs"
        case virtiofs = "virtiofs"
    }
}

struct Tmpfs: Codable, Equatable {
    // TODO: implement
}

struct Virtiofs: Codable, Equatable {
    // TODO: implement
}

struct initProcess: Codable, Equatable {
    let terminal: Bool
    let environment: [String]
    let workingDirectory: String
    let arguments: [String]
    let executable: String
    let user: User

    // TODO: initProcess
    //    "initProcess": {
    //      "rlimits": [],
    //      "supplementalGroups": [],
    //    },

    enum CodingKeys: String, CodingKey {
        case terminal = "terminal"
        case environment = "environment"
        case workingDirectory = "workingDirectory"
        case arguments = "arguments"
        case executable = "executable"
        case user = "user"
    }
}

struct User: Codable, Equatable {
    let id: UserID?
    let raw: UserRaw?

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case raw = "raw"
    }
}

struct UserRaw: Codable, Equatable {
    let userString: String

    enum CodingKeys: String, CodingKey {
        case userString = "userString"
    }
}

struct UserID: Codable, Equatable {
    let gid: Int
    let uid: Int

    enum CodingKeys: String, CodingKey {
        case gid = "gid"
        case uid = "uid"
    }
}

struct Network: Codable, Equatable {
    let gateway: String
    let hostname: String
    let network: String
    let address: String

    enum CodingKeys: String, CodingKey {
        case gateway = "gateway"
        case hostname = "hostname"
        case network = "network"
        case address = "address"
    }
}

struct Image: Codable, Equatable {
    let descriptor: ImageDescriptor
    let reference: String

    enum CodingKeys: String, CodingKey {
        case descriptor = "descriptor"
        case reference = "reference"
    }
}

struct ImageDescriptor: Codable, Equatable {
    let mediaType: String
    let digest: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case mediaType = "mediaType"
        case digest = "digest"
        case size = "size"
    }
}

struct DNS: Codable, Equatable {
    let nameservers: [String]
    let searchDomains: [String]
    let options: [String]

    enum CodingKeys: String, CodingKey {
        case nameservers = "nameservers"
        case searchDomains = "searchDomains"
        case options = "options"
    }
}

struct Resources: Codable, Equatable {
    let cpus: Int
    let memoryInBytes: Int

    enum CodingKeys: String, CodingKey {
        case cpus = "cpus"
        case memoryInBytes = "memoryInBytes"
    }
}

struct Platform: Codable, Equatable {
    let os: String
    let architecture: String

    enum CodingKeys: String, CodingKey {
        case os = "os"
        case architecture = "architecture"
    }
}

typealias Containers = [Container]
