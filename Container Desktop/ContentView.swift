//
//  ContentView.swift
//  Container Desktop
//
//  Created by Andrew Waters on 16/06/2025.
//

import SwiftExec
import SwiftUI

struct ContentView: View {

    @State var allContainers: [Container]
    @State private var selection: String?
    @State private var selectedContainer: String?

    var body: some View {

        NavigationSplitView {
            List(selection: $selection) {
                NavigationLink(value: "containers") {
                    Text("Containers")
                        .badge(allContainers.count)
                        .task {
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
                                for container in containers {
                                    allContainers.append(container)
                                    print(container)
                                }
                            } catch {
                                print(error)
                            }
                        }
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
        } content: {
            switch selection {
            case "containers":
                VStack {
                    List(selection: $selectedContainer) {
                        ForEach(allContainers, id: \.configuration.id) { container in
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
                            }
                        }
                    }
                }
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
        } detail: {
            switch selection {
            case "containers":
                ForEach(allContainers, id: \.configuration.id) { container in
                    if selectedContainer == container.configuration.id {
                        VStack(alignment: .leading) {
                            HStack(alignment: .top) {

                                VStack(alignment: .leading) {
                                    Text(container.configuration.id)
                                    Text(
                                        container.configuration.image.descriptor.digest
                                            .replacingOccurrences(of: "sha256:", with: "").prefix(
                                                12))
                                    Text(String(container.configuration.image.descriptor.size))

                                    // ForEach(container.mounts, id: \.destination) { mount in
                                    // Text("Type: " + mount.type)
                                    // Text("Source: " + mount.source)
                                    // Text("Options: " + mount.options.joined())
                                    // Text("Destination: " + mount.destination)
                                    // Divider()
                                    // }

                                    // Text(container.configuration.mounts.joined())
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
                                            + String(
                                                container.configuration.resources.memoryInBytes))
                                }

                                Spacer()
                            }
                        }.padding()

                        Divider()

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

                        Divider()

                        Text(
                            "User: "
                                + (container.configuration.initProcess.user.raw?.userString ?? ""))
                        Text(
                            "GID: " + String(container.configuration.initProcess.user.id?.gid ?? 0))
                        Text(
                            "UID: " + String(container.configuration.initProcess.user.id?.uid ?? 0))

                        Spacer()
                    }
                }
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
        .toolbar {
            Button(action: {

            }) {
                Label("Start system", systemImage: "play")
            }
        }
    }
}

#Preview {
    ContentView(allContainers: [])
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
