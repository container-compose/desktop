import Foundation

// MARK: - Container Models

struct Container: Codable, Equatable {
    let status: String
    let configuration: ContainerConfiguration
    let networks: [Network]

    enum CodingKeys: String, CodingKey {
        case status
        case configuration
        case networks
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
        case id
        case hostname
        case runtimeHandler
        case initProcess
        case mounts
        case platform
        case image
        case rosetta
        case dns
        case resources
    }
}

struct Mount: Codable, Equatable {
    let type: MountType
    let source: String
    let options: [String]
    let destination: String

    enum CodingKeys: String, CodingKey {
        case type
        case source
        case options
        case destination
    }
}

struct MountType: Codable, Equatable {
    let tmpfs: Tmpfs?
    let virtiofs: Virtiofs?

    enum CodingKeys: String, CodingKey {
        case tmpfs
        case virtiofs
    }
}

struct Tmpfs: Codable, Equatable {
}

struct Virtiofs: Codable, Equatable {
}

struct initProcess: Codable, Equatable {
    let terminal: Bool
    let environment: [String]
    let workingDirectory: String
    let arguments: [String]
    let executable: String
    let user: User

    enum CodingKeys: String, CodingKey {
        case terminal
        case environment
        case workingDirectory
        case arguments
        case executable
        case user
    }
}

struct User: Codable, Equatable {
    let id: UserID?
    let raw: UserRaw?

    enum CodingKeys: String, CodingKey {
        case id
        case raw
    }
}

struct UserRaw: Codable, Equatable {
    let userString: String

    enum CodingKeys: String, CodingKey {
        case userString
    }
}

struct UserID: Codable, Equatable {
    let gid: Int
    let uid: Int

    enum CodingKeys: String, CodingKey {
        case gid
        case uid
    }
}

struct Network: Codable, Equatable {
    let gateway: String
    let hostname: String
    let network: String
    let address: String

    enum CodingKeys: String, CodingKey {
        case gateway
        case hostname
        case network
        case address
    }
}

struct Image: Codable, Equatable {
    let descriptor: ImageDescriptor
    let reference: String

    enum CodingKeys: String, CodingKey {
        case descriptor
        case reference
    }
}

struct ImageDescriptor: Codable, Equatable {
    let mediaType: String
    let digest: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case mediaType
        case digest
        case size
    }
}

struct DNS: Codable, Equatable {
    let nameservers: [String]
    let searchDomains: [String]
    let options: [String]

    enum CodingKeys: String, CodingKey {
        case nameservers
        case searchDomains
        case options
    }
}

struct Resources: Codable, Equatable {
    let cpus: Int
    let memoryInBytes: Int

    enum CodingKeys: String, CodingKey {
        case cpus
        case memoryInBytes
    }
}

struct Platform: Codable, Equatable {
    let os: String
    let architecture: String

    enum CodingKeys: String, CodingKey {
        case os
        case architecture
    }
}

// MARK: - Container Image Models

struct ContainerImage: Codable, Equatable, Identifiable {
    let descriptor: ContainerImageDescriptor
    let reference: String

    var id: String { reference }

    enum CodingKeys: String, CodingKey {
        case descriptor
        case reference
    }
}

struct ContainerImageDescriptor: Codable, Equatable {
    let digest: String
    let mediaType: String
    let size: Int
    let annotations: [String: String]?

    enum CodingKeys: String, CodingKey {
        case digest
        case mediaType
        case size
        case annotations
    }
}

// MARK: - Mount Models

struct ContainerMount: Identifiable, Equatable {
    let id: String
    let mount: Mount
    let containerIds: [String]

    init(mount: Mount, containerIds: [String]) {
        self.mount = mount
        self.containerIds = containerIds
        // Create a unique ID based on source and destination
        self.id = "\(mount.source)->\(mount.destination)"
    }

    var mountType: String {
        if mount.type.virtiofs != nil {
            return "VirtioFS"
        } else if mount.type.tmpfs != nil {
            return "tmpfs"
        } else {
            return "Unknown"
        }
    }

    var optionsString: String {
        mount.options.joined(separator: ", ")
    }
}

// MARK: - DNS Models

struct DNSDomain: Codable, Equatable, Identifiable {
    let domain: String
    let isDefault: Bool

    var id: String { domain }

    init(domain: String, isDefault: Bool = false) {
        self.domain = domain
        self.isDefault = isDefault
    }
}

// MARK: - Builder Models

struct Builder: Codable, Equatable {
    let status: String
    let configuration: BuilderConfiguration
    let networks: [Network]

    enum CodingKeys: String, CodingKey {
        case status
        case configuration
        case networks
    }
}

struct BuilderConfiguration: Codable, Equatable {
    let id: String
    let image: Image
    let initProcess: initProcess
    let labels: [String: String]
    let mounts: [Mount]
    let networks: [String]
    let platform: Platform
    let resources: Resources
    let rosetta: Bool
    let runtimeHandler: String
    let sysctls: [String: String]
    let dns: DNS

    enum CodingKeys: String, CodingKey {
        case id
        case image
        case initProcess
        case labels
        case mounts
        case networks
        case platform
        case resources
        case rosetta
        case runtimeHandler
        case sysctls
        case dns
    }
}
