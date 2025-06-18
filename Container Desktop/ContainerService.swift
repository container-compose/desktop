import Foundation
import SwiftExec
import SwiftUI

class ContainerService: ObservableObject {
    @Published var containers: [Container] = []
    @Published var images: [ContainerImage] = []
    @Published var builders: [Builder] = []
    @Published var isLoading: Bool = false
    @Published var isImagesLoading: Bool = false
    @Published var isBuildersLoading: Bool = false
    @Published var errorMessage: String?
    @Published var systemStatus: SystemStatus = .unknown
    @Published var isSystemLoading = false
    @Published var loadingContainers: Set<String> = []
    @Published var isBuilderLoading = false
    @Published var builderStatus: BuilderStatus = .stopped

    // Computed property to get all unique mounts from containers
    var allMounts: [ContainerMount] {
        var mountDict: [String: ContainerMount] = [:]

        for container in containers {
            for mount in container.configuration.mounts {
                let mountId = "\(mount.source)->\(mount.destination)"

                if var existingMount = mountDict[mountId] {
                    // Add this container to the existing mount
                    var updatedContainerIds = existingMount.containerIds
                    if !updatedContainerIds.contains(container.configuration.id) {
                        updatedContainerIds.append(container.configuration.id)
                    }
                    mountDict[mountId] = ContainerMount(mount: mount, containerIds: updatedContainerIds)
                } else {
                    // Create new mount entry
                    mountDict[mountId] = ContainerMount(mount: mount, containerIds: [container.configuration.id])
                }
            }
        }

        return Array(mountDict.values).sorted { $0.mount.source < $1.mount.source }
    }

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

    enum BuilderStatus {
        case stopped
        case running

        var color: Color {
            switch self {
            case .stopped:
                return .gray
            case .running:
                return .green
            }
        }

        var text: String {
            switch self {
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

    func loadImages() async {
        await MainActor.run {
            isImagesLoading = true
            errorMessage = nil
        }

        var result: ExecResult
        do {
            result = try exec(
                program: "/usr/local/bin/container",
                arguments: ["images", "list", "--format", "json"])
        } catch {
            let error = error as! ExecError
            result = error.execResult
        }

        do {
            let data = result.stdout?.data(using: .utf8)
            let newImages = try JSONDecoder().decode(
                [ContainerImage].self, from: data!)

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.images = newImages
                }
                self.isImagesLoading = false
            }

            for image in newImages {
                print("Image: \(image.reference)")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isImagesLoading = false
            }
            print(error)
        }
    }

    func loadBuilders() async {
        await MainActor.run {
            isBuildersLoading = true
            errorMessage = nil
        }

        var result: ExecResult
        do {
            result = try exec(
                program: "/usr/local/bin/container",
                arguments: ["builder", "status", "--json"])
        } catch {
            let error = error as! ExecError
            result = error.execResult
        }

        do {
            let data = result.stdout?.data(using: .utf8)

            // Try to decode as single builder first
            if let data = data {
                do {
                    let newBuilder = try JSONDecoder().decode(Builder.self, from: data)
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.builders = [newBuilder]
                            // Use the builder's actual status
                            self.builderStatus = newBuilder.status.lowercased() == "running" ? .running : .stopped
                        }
                        self.isBuildersLoading = false
                    }
                    print("Builder: \(newBuilder.configuration.id), Status: \(newBuilder.status)")
                    return
                } catch {
                    // If single builder decode fails, try array
                    do {
                        let newBuilders = try JSONDecoder().decode([Builder].self, from: data)
                        await MainActor.run {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                self.builders = newBuilders
                                // Use the first builder's status, or stopped if no builders
                                if let firstBuilder = newBuilders.first {
                                    self.builderStatus = firstBuilder.status.lowercased() == "running" ? .running : .stopped
                                } else {
                                    self.builderStatus = .stopped
                                }
                            }
                            self.isBuildersLoading = false
                        }
                        for builder in newBuilders {
                            print("Builder: \(builder.configuration.id), Status: \(builder.status)")
                        }
                        return
                    } catch {
                        print("Failed to decode builders as array: \(error)")
                    }
                }
            }

            // If we get here, decoding failed
            await MainActor.run {
                self.builders = []
                self.builderStatus = .stopped
                self.isBuildersLoading = false
            }
            print("No builder data or failed to decode")
        } catch {
            await MainActor.run {
                // If no builder exists, set empty array
                self.builders = []
                self.builderStatus = .stopped
                self.isBuildersLoading = false
            }
            print("No builder found or error loading builder: \(error)")
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
                    self.errorMessage =
                        "Failed to stop container: \(result.stderr ?? "Unknown error")"
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
                    return true  // Container not found, assume it stopped
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
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
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
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
        }

        // Timeout reached, remove loading state
        await MainActor.run {
            print("Timeout reached for container \(id), removing loading state")
            loadingContainers.remove(id)
        }
    }

    func startBuilder() async {
        await MainActor.run {
            isBuilderLoading = true
            errorMessage = nil
        }

        var result: ExecResult
        do {
            result = try exec(
                program: "/usr/local/bin/container",
                arguments: ["builder", "start"])

            await MainActor.run {
                if !result.failed {
                    print("Builder start command sent successfully")
                    self.isBuilderLoading = false
                    // Refresh builder status
                    Task {
                        await loadBuilders()
                    }
                } else {
                    self.errorMessage =
                        "Failed to start builder: \(result.stderr ?? "Unknown error")"
                    self.isBuilderLoading = false
                }
            }

        } catch {
            let error = error as! ExecError
            result = error.execResult

            await MainActor.run {
                self.isBuilderLoading = false
                self.errorMessage = "Failed to start builder: \(error.localizedDescription)"
            }
            print("Error starting builder: \(error)")
        }
    }

    func stopBuilder() async {
        await MainActor.run {
            isBuilderLoading = true
            errorMessage = nil
        }

        var result: ExecResult
        do {
            result = try exec(
                program: "/usr/local/bin/container",
                arguments: ["builder", "stop"])

            await MainActor.run {
                if !result.failed {
                    print("Builder stop command sent successfully")
                    self.isBuilderLoading = false
                    // Refresh builder status
                    Task {
                        await loadBuilders()
                    }
                } else {
                    self.errorMessage =
                        "Failed to stop builder: \(result.stderr ?? "Unknown error")"
                    self.isBuilderLoading = false
                }
            }

        } catch {
            let error = error as! ExecError
            result = error.execResult

            await MainActor.run {
                self.isBuilderLoading = false
                self.errorMessage = "Failed to stop builder: \(error.localizedDescription)"
            }
            print("Error stopping builder: \(error)")
        }
    }

    func deleteBuilder() async {
        await MainActor.run {
            isBuilderLoading = true
            errorMessage = nil
        }

        var result: ExecResult
        do {
            result = try exec(
                program: "/usr/local/bin/container",
                arguments: ["builder", "delete"])

            await MainActor.run {
                if !result.failed {
                    print("Builder delete command sent successfully")
                    self.isBuilderLoading = false
                    // Clear builders array since it was deleted
                    self.builders = []
                } else {
                    self.errorMessage =
                        "Failed to delete builder: \(result.stderr ?? "Unknown error")"
                    self.isBuilderLoading = false
                }
            }

        } catch {
            let error = error as! ExecError
            result = error.execResult

            await MainActor.run {
                self.isBuilderLoading = false
                self.errorMessage = "Failed to delete builder: \(error.localizedDescription)"
            }
            print("Error deleting builder: \(error)")
        }
    }

    func removeContainer(_ id: String) async {
        await MainActor.run {
            loadingContainers.insert(id)
            errorMessage = nil
        }

        var result: ExecResult
        do {
            result = try exec(
                program: "/usr/local/bin/container",
                arguments: ["rm", id])

            await MainActor.run {
                if !result.failed {
                    print("Container \(id) remove command sent successfully")
                    // Remove from local array immediately
                    self.containers.removeAll { $0.configuration.id == id }
                    loadingContainers.remove(id)
                } else {
                    self.errorMessage =
                        "Failed to remove container: \(result.stderr ?? "Unknown error")"
                    loadingContainers.remove(id)
                }
            }

        } catch {
            let error = error as! ExecError
            result = error.execResult

            await MainActor.run {
                loadingContainers.remove(id)
                self.errorMessage = "Failed to remove container: \(error.localizedDescription)"
            }
            print("Error removing container: \(error)")
        }
    }

    func fetchContainerLogs(containerId: String) async throws -> String {
        var result: ExecResult
        do {
            result = try exec(
                program: "/usr/local/bin/container",
                arguments: ["logs", containerId])
        } catch {
            let error = error as! ExecError
            result = error.execResult
        }

        if let stdout = result.stdout {
            return stdout
        } else if let stderr = result.stderr {
            throw NSError(domain: "ContainerService", code: 1, userInfo: [NSLocalizedDescriptionKey: stderr])
        } else {
            return ""
        }
    }
}

// MARK: - Type aliases for JSON decoding
typealias Containers = [Container]
typealias Images = [ContainerImage]
typealias Builders = [Builder]
