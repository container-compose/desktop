import SwiftUI
import AppKit

// MARK: - Container Detail Views

struct ContainerDetailView: View {
    let container: Container
    @EnvironmentObject var containerService: ContainerService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title bar
            HStack {
                Text("Container Details")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            Divider()

            // Header with controls
            containerHeader(container: container)

            Divider()

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Overview and Image side by side
                    HStack(alignment: .top, spacing: 20) {
                        containerOverviewSection(container: container)
                        containerImageSection(container: container)
                    }

                    Divider()

                    // Network section full width
                    containerNetworkSection(container: container)

                    Divider()

                    // Resources and Process side by side
                    HStack(alignment: .top, spacing: 20) {
                        containerResourcesSection(container: container)
                        containerProcessSection(container: container)
                    }

                    Divider()

                    // Environment variables section
                    containerEnvironmentSection(container: container)

                    Divider()

                    // Mounts section
                    containerMountsSection(container: container)

                    Spacer(minLength: 20)
                }
                .padding()
            }
        }
    }

    // MARK: - Header Section

    private func containerHeader(container: Container) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(container.configuration.id)
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack(spacing: 8) {
                    Circle()
                        .fill(container.status.lowercased() == "running" ? .green : .gray)
                        .frame(width: 8, height: 8)
                    Text(container.status.capitalized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

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
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Detail Sections

    private func containerOverviewSection(container: Container) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 8) {
                CopyableInfoRow(label: "Container ID", value: container.configuration.id)
                InfoRow(label: "Runtime", value: container.configuration.runtimeHandler)
                InfoRow(label: "Platform", value: "\(container.configuration.platform.os)/\(container.configuration.platform.architecture)")
                if let hostname = container.configuration.hostname {
                    InfoRow(label: "Hostname", value: hostname)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func containerImageSection(container: Container) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Image")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Reference", value: container.configuration.image.reference)
                InfoRow(label: "Media Type", value: container.configuration.image.descriptor.mediaType)
                CopyableInfoRow(
                    label: "Digest",
                    value: String(container.configuration.image.descriptor.digest.replacingOccurrences(of: "sha256:", with: "").prefix(12)),
                    copyValue: container.configuration.image.descriptor.digest
                )
                InfoRow(label: "Size", value: ByteCountFormatter().string(fromByteCount: Int64(container.configuration.image.descriptor.size)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func containerNetworkSection(container: Container) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network")
                .font(.headline)
                .foregroundColor(.primary)

            if !container.networks.isEmpty {
                ForEach(container.networks, id: \.hostname) { network in
                    VStack(alignment: .leading, spacing: 8) {
                        CopyableInfoRow(
                            label: "Address",
                            value: network.address,
                            copyValue: network.address.replacingOccurrences(of: "/24", with: "")
                        )
                        InfoRow(label: "Gateway", value: network.gateway)
                        InfoRow(label: "Network", value: network.network)
                        if network.hostname != container.configuration.hostname {
                            InfoRow(label: "Network Hostname", value: network.hostname)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                }

                // DNS Configuration
                if !container.configuration.dns.nameservers.isEmpty || !container.configuration.dns.searchDomains.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DNS Configuration")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if !container.configuration.dns.nameservers.isEmpty {
                            InfoRow(label: "Nameservers", value: container.configuration.dns.nameservers.joined(separator: ", "))
                        }
                        if !container.configuration.dns.searchDomains.isEmpty {
                            InfoRow(label: "Search Domains", value: container.configuration.dns.searchDomains.joined(separator: ", "))
                        }
                        if !container.configuration.dns.options.isEmpty {
                            InfoRow(label: "Options", value: container.configuration.dns.options.joined(separator: ", "))
                        }
                    }
                }
            } else {
                Text("No network configuration")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }

    private func containerResourcesSection(container: Container) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resources")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "CPUs", value: "\(container.configuration.resources.cpus)")
                InfoRow(label: "Memory", value: ByteCountFormatter().string(fromByteCount: Int64(container.configuration.resources.memoryInBytes)))
                InfoRow(label: "Rosetta", value: container.configuration.rosetta ? "Enabled" : "Disabled")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func containerProcessSection(container: Container) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Process Configuration")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Executable", value: container.configuration.initProcess.executable)
                InfoRow(label: "Working Directory", value: container.configuration.initProcess.workingDirectory)
                InfoRow(label: "Terminal", value: container.configuration.initProcess.terminal ? "Enabled" : "Disabled")

                if !container.configuration.initProcess.arguments.isEmpty {
                    InfoRow(label: "Arguments", value: container.configuration.initProcess.arguments.joined(separator: " "))
                }

                // User information
                if let userString = container.configuration.initProcess.user.raw?.userString {
                    InfoRow(label: "User", value: userString)
                }
                if let userId = container.configuration.initProcess.user.id {
                    InfoRow(label: "UID:GID", value: "\(userId.uid):\(userId.gid)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func containerEnvironmentSection(container: Container) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Environment Variables")
                .font(.headline)
                .foregroundColor(.primary)

            if !container.configuration.initProcess.environment.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(container.configuration.initProcess.environment, id: \.self) { envVar in
                            let components = envVar.split(separator: "=", maxSplits: 1)
                            if components.count == 2 {
                                HStack(alignment: .top) {
                                    Text(String(components[0]))
                                        .font(.system(.subheadline, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .frame(minWidth: 100, alignment: .leading)

                                    Text("=")
                                        .font(.system(.subheadline, design: .monospaced))
                                        .foregroundColor(.secondary)

                                    Text(String(components[1]))
                                        .font(.system(.subheadline, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 2)
                            } else {
                                Text(envVar)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            } else {
                Text("No environment variables")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }

    private func containerMountsSection(container: Container) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mounts")
                .font(.headline)
                .foregroundColor(.primary)

            if !container.configuration.mounts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(container.configuration.mounts.enumerated()), id: \.offset) { index, mount in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Mount \(index + 1)")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            InfoRow(label: "Source", value: mount.source)
                            InfoRow(label: "Destination", value: mount.destination)

                            if mount.type.virtiofs != nil {
                                InfoRow(label: "Type", value: "VirtioFS")
                            } else if mount.type.tmpfs != nil {
                                InfoRow(label: "Type", value: "tmpfs")
                            } else {
                                InfoRow(label: "Type", value: "Unknown")
                            }

                            if !mount.options.isEmpty {
                                InfoRow(label: "Options", value: mount.options.joined(separator: ", "))
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }
                }
            } else {
                Text("No mounts")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
}
