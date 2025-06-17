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
            containers.removeAll()
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
            let containers = try JSONDecoder().decode(
                Containers.self, from: data!)

            await MainActor.run {
                self.containers = containers
                self.isLoading = false
            }

            for container in containers {
                print(container)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            print(error)
        }
    }

    func stopContainer(_ id: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        var result: ExecResult
        do {
            result = try exec(
                program: "/usr/local/bin/container",
                arguments: ["stop", id])

            await MainActor.run {
                self.isLoading = false
            }

            print("Container \(id) stopped successfully")
            // Reload containers to refresh the status
            await loadContainers()

        } catch {
            let error = error as! ExecError
            result = error.execResult

            await MainActor.run {
                self.errorMessage = "Failed to stop container: \(error.localizedDescription)"
                self.isLoading = false
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
        // Implementation for starting a container
    }
}

struct ContentView: View {

    @StateObject private var containerService = ContainerService()
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
            SwiftUI.Image(systemName: "power")
                .font(SwiftUI.Font.system(size: 60))
                .foregroundColor(SwiftUI.Color.gray)

            Text("Container System is Stopped")
                .font(.title2)
                .fontWeight(.medium)

            Text("Start the container system to view and manage containers")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            systemStatusCard
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .task {
            await containerService.checkSystemStatus()
            await containerService.loadContainers()
        }
    }

    private var systemStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(containerService.systemStatus.color)
                    .frame(width: 8, height: 8)
                Text("System: \(containerService.systemStatus.text)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                Button("Start System") {
                    Task { @MainActor in
                        await containerService.startSystem()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(containerService.isSystemLoading)

                Button("Check Status") {
                    Task { @MainActor in
                        await containerService.checkSystemStatus()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(containerService.isSystemLoading)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var mainInterfaceView: some View {
        NavigationSplitView {
            sidebarView
        } content: {
            contentView
        } detail: {
            detailView
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    Task { @MainActor in
                        await containerService.loadContainers()
                    }
                }) {
                    Label("Refresh Containers", systemImage: "arrow.clockwise")
                }
                .disabled(containerService.isLoading)

                Button(action: {
                    // Future system start functionality
                }) {
                    Label("Start system", systemImage: "play")
                }
            }
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
                Button("Start") {
                    Task { @MainActor in
                        await containerService.startSystem()
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .disabled(
                    containerService.isSystemLoading
                        || containerService.systemStatus == .running)

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
                .disabled(containerService.isSystemLoading)

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
                    NavigationLink(value: container.configuration.id) {
                        VStack(alignment: .leading) {
                            Text(container.configuration.hostname ?? "Unknown")
                                .badge(container.status)
                            Text(
                                container.networks[0].address.replacingOccurrences(
                                    of: "/24", with: "")
                            )
                            .font(.subheadline).monospaced()
                        }
                    }
                    .contextMenu {
                        Button {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(
                                container.networks[0].address.replacingOccurrences(
                                    of: "/24", with: ""), forType: .string)
                        } label: {
                            Label("Copy IP address", systemImage: "network")
                        }

                        Button {
                            Task { @MainActor in
                                await containerService.stopContainer(
                                    container.configuration.id)
                            }
                        } label: {
                            Label("Stop Container", systemImage: "stop.fill")
                        }
                        .disabled(
                            containerService.isLoading || container.status != "running")
                    }
                }
            }
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

                        HStack {
                            Button {
                                Task { @MainActor in
                                    await containerService.stopContainer(
                                        container.configuration.id)
                                }
                            } label: {
                                Label("Stop Container", systemImage: "stop.fill")
                            }
                            .disabled(
                                containerService.isLoading || container.status != "running")

                            Spacer()
                        }
                        .padding()

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

#Preview {
    ContentView()
}

struct Container: Codable {
    let status: String
    let configuration: ContainerConfiguration
    let networks: [Network]

    enum CodingKeys: String, CodingKey {
        case status = "status"
        case networks = "networks"
        case configuration = "configuration"
    }
}

struct ContainerConfiguration: Codable {
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

struct Mount: Codable {
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

struct MountType: Codable {
    let tmpfs: Tmpfs?
    let virtiofs: Virtiofs?

    enum CodingKeys: String, CodingKey {
        case tmpfs = "tmpfs"
        case virtiofs = "virtiofs"
    }
}

struct Tmpfs: Codable {
    // TODO: implement
}

struct Virtiofs: Codable {
    // TODO: implement
}

struct initProcess: Codable {
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

struct User: Codable {
    let id: UserID?
    let raw: UserRaw?

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case raw = "raw"
    }
}

struct UserRaw: Codable {
    let userString: String

    enum CodingKeys: String, CodingKey {
        case userString = "userString"
    }
}

struct UserID: Codable {
    let gid: Int
    let uid: Int

    enum CodingKeys: String, CodingKey {
        case gid = "gid"
        case uid = "uid"
    }
}

struct Network: Codable {
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

struct Image: Codable {
    let descriptor: ImageDescriptor
    let reference: String

    enum CodingKeys: String, CodingKey {
        case descriptor = "descriptor"
        case reference = "reference"
    }
}

struct ImageDescriptor: Codable {
    let mediaType: String
    let digest: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case mediaType = "mediaType"
        case digest = "digest"
        case size = "size"
    }
}

struct DNS: Codable {
    let nameservers: [String]
    let searchDomains: [String]
    let options: [String]

    enum CodingKeys: String, CodingKey {
        case nameservers = "nameservers"
        case searchDomains = "searchDomains"
        case options = "options"
    }
}

struct Resources: Codable {
    let cpus: Int
    let memoryInBytes: Int

    enum CodingKeys: String, CodingKey {
        case cpus = "cpus"
        case memoryInBytes = "memoryInBytes"
    }
}

struct Platform: Codable {
    let os: String
    let architecture: String

    enum CodingKeys: String, CodingKey {
        case os = "os"
        case architecture = "architecture"
    }
}

typealias Containers = [Container]
