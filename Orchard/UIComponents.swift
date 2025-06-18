import AppKit
import SwiftUI

// MARK: - Container Components

struct ContainerImageRow: View {
    let image: ContainerImage
    @EnvironmentObject var containerService: ContainerService

    private var imageName: String {
        // Extract the image name from the reference (e.g., "docker.io/library/alpine:3" -> "alpine")
        let components = image.reference.split(separator: "/")
        if let lastComponent = components.last {
            return String(lastComponent.split(separator: ":").first ?? lastComponent)
        }
        return image.reference
    }

    private var imageTag: String {
        // Extract the tag from the reference (e.g., "docker.io/library/alpine:3" -> "3")
        if let tagComponent = image.reference.split(separator: ":").last,
            tagComponent != image.reference.split(separator: "/").last
        {
            return String(tagComponent)
        }
        return "latest"
    }

    private var isUsedByRunningContainer: Bool {
        containerService.containers.contains { container in
            container.configuration.image.reference == image.reference &&
            container.status.lowercased() == "running"
        }
    }

    var body: some View {
        NavigationLink(value: image.reference) {
            HStack {
                SwiftUI.Image(systemName: "square.stack.3d.up")
                    .foregroundColor(isUsedByRunningContainer ? .green : .gray)
                    .frame(width: 16, height: 16)

                VStack(alignment: .leading) {
                    Text(imageName)
                        .font(.headline)
                        .foregroundColor(isUsedByRunningContainer ? .primary : .secondary)
                    HStack {
                        Text(imageTag)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(
                            ByteCountFormatter().string(fromByteCount: Int64(image.descriptor.size))
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(8)
        .contextMenu {
            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(image.reference, forType: .string)
            } label: {
                Label("Copy Reference", systemImage: "doc.on.doc")
            }

            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(image.descriptor.digest, forType: .string)
            } label: {
                Label("Copy Digest", systemImage: "number")
            }
        }
    }
}

struct MountRow: View {
    let mount: ContainerMount
    @EnvironmentObject var containerService: ContainerService

    private var displaySource: String {
        // Show just the last component of the path for cleaner display
        URL(fileURLWithPath: mount.mount.source).lastPathComponent
    }

    private var displayDestination: String {
        // Show just the last component of the path for cleaner display
        URL(fileURLWithPath: mount.mount.destination).lastPathComponent
    }

    private var isUsedByRunningContainer: Bool {
        containerService.containers.contains { container in
            mount.containerIds.contains(container.configuration.id) &&
            container.status.lowercased() == "running"
        }
    }

    var body: some View {
        NavigationLink(value: mount.id) {
            HStack {
                SwiftUI.Image(systemName: mount.mount.type.virtiofs != nil ? "externaldrive" : "folder")
                    .foregroundColor(isUsedByRunningContainer ? .blue : .gray)
                    .frame(width: 16, height: 16)
                    .padding(.trailing, 8)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(displaySource)
                            .font(.headline)
                            .foregroundColor(isUsedByRunningContainer ? .primary : .secondary)
                        SwiftUI.Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(displayDestination)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(8)
        .contextMenu {
            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(mount.mount.source, forType: .string)
            } label: {
                Label("Copy Source Path", systemImage: "doc.on.doc")
            }

            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(mount.mount.destination, forType: .string)
            } label: {
                Label("Copy Destination Path", systemImage: "doc.on.doc")
            }
        }
    }
}

struct ContainerRow: View {
    let container: Container
    let isLoading: Bool
    let stopContainer: (String) -> Void
    let startContainer: (String) -> Void
    let removeContainer: (String) -> Void

    private var networkAddress: String {
        guard !container.networks.isEmpty else {
            if container.status == "running" {
                return "No network"
            } else {
                return "Not running"
            }
        }
        return container.networks[0].address.replacingOccurrences(of: "/24", with: "")
    }

    var body: some View {
        NavigationLink(value: container.configuration.id) {
            HStack {
                SwiftUI.Image(systemName: "cube.box")
                    .foregroundColor(container.status.lowercased() == "running" ? .green : .gray)
                    .frame(width: 16, height: 16)

                VStack(alignment: .leading) {
                    Text(container.configuration.id)
                    Text(networkAddress)
                        .font(.subheadline)
                        .monospaced()
                }
            }
        }
        .padding(8)
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

            if isLoading {
                Text("Loading...")
                    .foregroundColor(.gray)
            } else if container.status.lowercased() == "running" {
                Button("Stop Container") {
                    stopContainer(container.configuration.id)
                }
            } else {
                Button("Start Container") {
                    startContainer(container.configuration.id)
                }

                Button("Remove Container") {
                    removeContainer(container.configuration.id)
                }
            }
        }
    }
}

// MARK: - Control Buttons

struct PowerButton: View {
    let isLoading: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            SwiftUI.Image(systemName: "power")
                .font(.system(size: 60))
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

    private var buttonColor: Color {
        if isLoading {
            return .white
        } else if isHovered {
            return .blue
        } else {
            return .gray
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

        var color: Color {
            switch self {
            case .start: return .gray
            case .stop: return .gray
            case .loading: return .white
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
                break  // No action when loading
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
            print(
                "Container \(container.configuration.id) state changed to: \(newState), status: \(container.status), isLoading: \(isLoading)"
            )
            isRotating = (newState == .loading)
        }
        .frame(width: 30, height: 30)
    }
}

struct ContainerRemoveButton: View {
    let container: Container
    let isLoading: Bool
    let onRemove: () -> Void

    var body: some View {
        Button {
            onRemove()
        } label: {
            SwiftUI.Image(systemName: "trash.fill")
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
        .buttonStyle(.plain)
        .disabled(isLoading || container.status.lowercased() == "running")
        .help("Remove Container")
        .modifier(
            CursorModifier(
                cursor: (isLoading || container.status.lowercased() == "running")
                    ? .arrow : .pointingHand))
    }
}

// MARK: - Utility Components

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .monospaced()
                .textSelection(.enabled)
            Spacer()
        }
    }
}

struct CopyableInfoRow: View {
    let label: String
    let value: String
    let copyValue: String?

    init(label: String, value: String, copyValue: String? = nil) {
        self.label = label
        self.value = value
        self.copyValue = copyValue
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .monospaced()
                .textSelection(.enabled)
            Spacer()
            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(copyValue ?? value, forType: .string)
            } label: {
                SwiftUI.Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy to clipboard")
        }
    }
}

struct NavigableInfoRow: View {
    let label: String
    let value: String
    let onNavigate: () -> Void

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .monospaced()
                .textSelection(.enabled)
            Spacer()
            Button {
                onNavigate()
            } label: {
                SwiftUI.Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("View image details")
        }
    }
}

// MARK: - View Modifiers

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
