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

    enum SettingsTab: String, CaseIterable {
        case registries = "registries"
        case dns = "dns"
        case builder = "builder"

        var title: String {
            switch self {
            case .registries:
                return "Registries"
            case .dns:
                return "DNS"
            case .builder:
                return "Builder"
            }
        }

        var icon: String {
            switch self {
            case .registries:
                return "server.rack"
            case .dns:
                return "network"
            case .builder:
                return "hammer"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            registriesView
                .tabItem {
                    Label("Registries", systemImage: "server.rack")
                }
                .tag(SettingsTab.registries)

            dnsView
                .tabItem {
                    Label("DNS", systemImage: "network")
                }
                .tag(SettingsTab.dns)

            builderView
                .tabItem {
                    Label("Builder", systemImage: "hammer")
                }
                .tag(SettingsTab.builder)
        }
        .frame(width: 600, height: 500)
        .task {
            await containerService.loadDNSDomains()
        }
        .onAppear {
            Task {
                await containerService.loadDNSDomains()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await containerService.loadDNSDomains()
            }
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: containerService.errorMessage) { _, newValue in
            if let error = newValue {
                errorMessage = error
                showingErrorAlert = true
                containerService.errorMessage = nil
            }
        }
    }

    // MARK: - Registries View

    private var registriesView: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SwiftUI.Image(systemName: "server.rack")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("Container Registries")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Text("Manage container image registries and authentication settings")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(spacing: 16) {
                SwiftUI.Image(systemName: "server.rack")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text("Registry Management")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("Configure container image registries and authentication")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("Coming Soon")
                    .font(.caption)
                    .foregroundColor(Color.secondary.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Spacer()
        }
        .padding(20)
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

    // MARK: - Builder View

    private var builderView: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SwiftUI.Image(systemName: "hammer")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("Container Builder")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Text("Manage container build settings and environments")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(spacing: 16) {
                SwiftUI.Image(systemName: "hammer")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text("Builder Configuration")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("Configure container build settings and environments")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("Coming Soon")
                    .font(.caption)
                    .foregroundColor(Color.secondary.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Spacer()
        }
        .padding(20)
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
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(ContainerService())
    }
}
