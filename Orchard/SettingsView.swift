//
//  SettingsView.swift
//  Orchard
//
//  Created by Andrew Waters on 16/06/2025.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var containerService: ContainerService
    @State private var selectedTab: SettingsTab = .dns
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""

    enum SettingsTab: String, CaseIterable {
        case registries = "registries"
        case dns = "dns"
        case kernel = "kernel"

        var title: String {
            switch self {
            case .registries:
                return "Registries"
            case .dns:
                return "DNS"
            case .kernel:
                return "Kernel"
            }
        }

        var icon: String {
            switch self {
            case .registries:
                return "server.rack"
            case .dns:
                return "network"
            case .kernel:
                return "cpu"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            registryView
                .tabItem {
                    Label("Registries", systemImage: "server.rack")
                }
                .tag(SettingsTab.registries)

            dnsView
                .tabItem {
                    Label("DNS", systemImage: "network")
                }
                .tag(SettingsTab.dns)

            kernelView
                .tabItem {
                    Label("Kernel", systemImage: "cpu")
                }
                .tag(SettingsTab.kernel)
        }
        .frame(width: 600, height: 500)
        .task {
            await containerService.loadDNSDomains()
            await containerService.loadKernelConfig()
            await containerService.loadRegistries()
        }
        .onAppear {
            Task {
                await containerService.loadDNSDomains()
                await containerService.loadKernelConfig()
                await containerService.loadRegistries()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await containerService.loadDNSDomains()
                await containerService.loadKernelConfig()
                await containerService.loadRegistries()
            }
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showingSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(successMessage)
        }
        .onChange(of: containerService.errorMessage) { _, newValue in
            if let error = newValue {
                errorMessage = error
                showingErrorAlert = true
                containerService.errorMessage = nil
            }
        }
        .onChange(of: containerService.successMessage) { _, newValue in
            if let success = newValue {
                successMessage = success
                showingSuccessAlert = true
                containerService.successMessage = nil
            }
        }
    }



    // MARK: - DNS View

    private var dnsView: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SwiftUI.Image(systemName: "network")
                        .font(.title2)
                        .foregroundColor(.green)
                    Text("DNS Domains")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    Button(action: {
                        showAddDNSDomainDialog()
                    }) {
                        Label("Add Domain", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text("Manage local DNS domains for container networking")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            if containerService.isDNSLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading DNS domains...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if containerService.dnsDomains.isEmpty {
                VStack(spacing: 16) {
                    SwiftUI.Image(systemName: "network.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No DNS Domains")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Add a DNS domain to enable local container networking.\nThis requires administrator privileges.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Add First Domain") {
                        showAddDNSDomainDialog()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(containerService.dnsDomains) { domain in
                            dnsRow(domain: domain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            Spacer()
        }
        .padding(20)
    }

    private func dnsRow(domain: DNSDomain) -> some View {
        HStack {
            HStack(spacing: 12) {
                // Default indicator icon
                if domain.isDefault {
                    SwiftUI.Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                } else {
                    SwiftUI.Image(systemName: "circle")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(domain.domain)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(domain.isDefault ? .semibold : .medium)

                    if domain.isDefault {
                        Text("Default Domain")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if domain.isDefault {
                    Button("Unset Default") {
                        Task {
                            await containerService.unsetDefaultDNSDomain()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.orange)
                    .disabled(containerService.isDNSLoading)
                } else {
                    Button("Set Default") {
                        Task {
                            await containerService.setDefaultDNSDomain(domain.domain)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(containerService.isDNSLoading)
                }

                Button("Delete") {
                    showDeleteDNSDomainDialog(domain: domain.domain)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
                .disabled(containerService.isDNSLoading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(domain.isDefault ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Kernel View

    private var kernelView: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SwiftUI.Image(systemName: "cpu")
                        .font(.title2)
                        .foregroundColor(.purple)
                    Text("Kernel Configuration")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Text("Manage the default kernel configuration for containers")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            if containerService.isKernelLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Configuring kernel...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 24) {
                    // Recommended Kernel Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recommended Kernel")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("Use the recommended kernel configuration. This is the easiest option and works for most use cases.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            if containerService.kernelConfig.isRecommended {
                                Button("Recommended Kernel Active") {
                                    // No action needed - already active
                                }
                                .buttonStyle(.bordered)
                                .disabled(true)

                                Label("Currently Active", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.subheadline)
                            } else {
                                Button("Use Recommended Kernel") {
                                    Task {
                                        await containerService.setRecommendedKernel()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(containerService.isKernelLoading)
                            }

                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    // Custom Kernel Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Custom Kernel")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("Configure a custom kernel using a binary path, tar archive, or remote URL.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button("Configure Custom Kernel") {
                            showCustomKernelDialog()
                        }
                        .buttonStyle(.bordered)
                        .disabled(containerService.isKernelLoading)

                        if !containerService.kernelConfig.isRecommended &&
                           (containerService.kernelConfig.binary != nil || containerService.kernelConfig.tar != nil) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Custom Configuration:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                if let binary = containerService.kernelConfig.binary {
                                    Text("Binary: \(binary)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if let tar = containerService.kernelConfig.tar {
                                    Text("Archive: \(tar)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Text("Architecture: \(containerService.kernelConfig.arch.displayName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    Spacer()
                }
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Registry View

    private var registryView: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SwiftUI.Image(systemName: "server.rack")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("Container Registries")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    Button(action: {
                        showRegistryLoginDialog()
                    }) {
                        Label("Add Registry", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text("Manage container registry logins and default registry")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            if containerService.isRegistriesLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading registries...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if containerService.registries.isEmpty {
                VStack(spacing: 16) {
                    SwiftUI.Image(systemName: "server.rack")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No Registries")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Add a registry login to pull images from private repositories.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Add Registry") {
                        showRegistryLoginDialog()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(containerService.registries) { registry in
                            registryRow(registry: registry)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            Spacer()
        }
        .padding(20)
    }

    private func registryRow(registry: Registry) -> some View {
        HStack {
            HStack(spacing: 12) {
                // Default indicator icon
                if registry.isDefault {
                    SwiftUI.Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                } else {
                    SwiftUI.Image(systemName: "circle")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(registry.server)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(registry.isDefault ? .semibold : .medium)

                    if let username = registry.username {
                        Text("User: \(username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if registry.isDefault {
                        Text("Default Registry")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if registry.isDefault {
                    Button("Unset Default") {
                        Task {
                            await containerService.unsetDefaultRegistry()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.orange)
                    .disabled(containerService.isRegistriesLoading)
                } else {
                    Button("Set Default") {
                        Task {
                            await containerService.setDefaultRegistry(registry.server)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(containerService.isRegistriesLoading)
                }

                Button("Logout") {
                    showRegistryLogoutDialog(registry: registry.server)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
                .disabled(containerService.isRegistriesLoading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(registry.isDefault ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Helper Methods

    private func showAddDNSDomainDialog() {
        let alert = NSAlert()
        alert.messageText = "Add DNS Domain"
        alert.informativeText = "Enter a domain name for local container networking.\n\nThis operation requires administrator privileges and you will be prompted for your password."
        alert.alertStyle = .informational

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = "e.g., local.dev, myapp.local"
        alert.accessoryView = textField

        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let domain = textField.stringValue.trimmingCharacters(in: .whitespaces)
            if !domain.isEmpty {
                // Validate domain format
                if isValidDomainName(domain) {
                    Task {
                        await containerService.createDNSDomain(domain)
                    }
                } else {
                    errorMessage = "Invalid domain name format. Please enter a valid domain like 'local.dev' or 'myapp.local'."
                    showingErrorAlert = true
                }
            }
        }
    }

    private func showDeleteDNSDomainDialog(domain: String) {
        let alert = NSAlert()
        alert.messageText = "Delete DNS Domain"
        alert.informativeText = "Are you sure you want to delete the DNS domain '\(domain)'? This action cannot be undone and requires administrator privileges. You will be prompted for your password."
        alert.alertStyle = .warning

        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            Task {
                await containerService.deleteDNSDomain(domain)
            }
        }
    }

    private func isValidDomainName(_ domain: String) -> Bool {
        let domainRegex = "^[a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?\\.[a-zA-Z]{2,}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", domainRegex)
        return predicate.evaluate(with: domain)
    }

    private func showCustomKernelDialog() {
        let alert = NSAlert()
        alert.messageText = "Custom Kernel Configuration"
        alert.informativeText = "Configure a custom kernel. You can specify either a binary path, a tar archive (local path or URL), or both. This operation requires administrator privileges."
        alert.alertStyle = .informational

        // Create a custom view for the dialog
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 120))

        // Binary path field
        let binaryLabel = NSTextField(labelWithString: "Binary Path (optional):")
        binaryLabel.frame = NSRect(x: 0, y: 90, width: 150, height: 20)
        let binaryField = NSTextField(frame: NSRect(x: 0, y: 70, width: 400, height: 24))
        binaryField.placeholderString = "/path/to/kernel/binary"

        // Tar path field
        let tarLabel = NSTextField(labelWithString: "Tar Archive (optional):")
        tarLabel.frame = NSRect(x: 0, y: 45, width: 150, height: 20)
        let tarField = NSTextField(frame: NSRect(x: 0, y: 25, width: 400, height: 24))
        tarField.placeholderString = "/path/to/archive.tar or https://example.com/kernel.tar"

        // Architecture popup
        let archLabel = NSTextField(labelWithString: "Architecture:")
        archLabel.frame = NSRect(x: 0, y: 0, width: 100, height: 20)
        let archPopup = NSPopUpButton(frame: NSRect(x: 100, y: -3, width: 200, height: 26))
        archPopup.addItems(withTitles: KernelArch.allCases.map { $0.displayName })
        archPopup.selectItem(at: KernelArch.allCases.firstIndex(of: .arm64) ?? 0)

        containerView.addSubview(binaryLabel)
        containerView.addSubview(binaryField)
        containerView.addSubview(tarLabel)
        containerView.addSubview(tarField)
        containerView.addSubview(archLabel)
        containerView.addSubview(archPopup)

        alert.accessoryView = containerView
        alert.addButton(withTitle: "Set Kernel")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let binary = binaryField.stringValue.trimmingCharacters(in: .whitespaces)
            let tar = tarField.stringValue.trimmingCharacters(in: .whitespaces)
            let archIndex = archPopup.indexOfSelectedItem
            let arch = KernelArch.allCases[archIndex]

            if binary.isEmpty && tar.isEmpty {
                errorMessage = "Please specify either a binary path or tar archive."
                showingErrorAlert = true
                return
            }

            Task {
                await containerService.setCustomKernel(
                    binary: binary.isEmpty ? nil : binary,
                    tar: tar.isEmpty ? nil : tar,
                    arch: arch
                )
            }
        }
    }

    private func showRegistryLoginDialog() {
        let alert = NSAlert()
        alert.messageText = "Registry Login"
        alert.informativeText = "Login to a container registry to access private repositories."
        alert.alertStyle = .informational

        // Create a custom view for the dialog
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 140))

        // Server field
        let serverLabel = NSTextField(labelWithString: "Registry Server:")
        serverLabel.frame = NSRect(x: 0, y: 115, width: 120, height: 20)
        let serverField = NSTextField(frame: NSRect(x: 0, y: 95, width: 400, height: 24))
        serverField.placeholderString = "docker.io, ghcr.io, registry.example.com"

        // Username field
        let usernameLabel = NSTextField(labelWithString: "Username:")
        usernameLabel.frame = NSRect(x: 0, y: 70, width: 120, height: 20)
        let usernameField = NSTextField(frame: NSRect(x: 0, y: 50, width: 400, height: 24))
        usernameField.placeholderString = "your-username"

        // Password field
        let passwordLabel = NSTextField(labelWithString: "Password:")
        passwordLabel.frame = NSRect(x: 0, y: 25, width: 120, height: 20)
        let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 5, width: 400, height: 24))
        passwordField.placeholderString = "your-password or token"

        containerView.addSubview(serverLabel)
        containerView.addSubview(serverField)
        containerView.addSubview(usernameLabel)
        containerView.addSubview(usernameField)
        containerView.addSubview(passwordLabel)
        containerView.addSubview(passwordField)

        alert.accessoryView = containerView
        alert.addButton(withTitle: "Login")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let server = serverField.stringValue.trimmingCharacters(in: .whitespaces)
            let username = usernameField.stringValue.trimmingCharacters(in: .whitespaces)
            let password = passwordField.stringValue

            if server.isEmpty || username.isEmpty || password.isEmpty {
                errorMessage = "Please fill in all fields."
                showingErrorAlert = true
                return
            }

            let request = RegistryLoginRequest(
                server: server,
                username: username,
                password: password,
                scheme: .auto
            )

            Task {
                await containerService.loginToRegistry(request)
            }
        }
    }

    private func showRegistryLogoutDialog(registry: String) {
        let alert = NSAlert()
        alert.messageText = "Registry Logout"
        alert.informativeText = "Are you sure you want to logout from '\(registry)'? You will need to login again to access private repositories."
        alert.alertStyle = .warning

        alert.addButton(withTitle: "Logout")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            Task {
                await containerService.logoutFromRegistry(registry)
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(ContainerService())
    }
}
