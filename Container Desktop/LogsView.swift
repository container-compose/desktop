import SwiftUI
import Foundation

struct LogsView: View {
    let containerId: String
    @EnvironmentObject var containerService: ContainerService
    @State private var logs: String = ""
    @State private var isLoading: Bool = false
    @State private var autoScroll: Bool = true
    @State private var refreshTimer: Timer?
    @State private var lastLogSize: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with controls
            HStack {
                Text("Logs")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(SwitchToggleStyle())

                Button(action: clearLogs) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Logs content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if isLoading && logs.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView("Loading logs...")
                                    .padding()
                                Spacer()
                            }
                        } else if logs.isEmpty {
                            HStack {
                                Spacer()
                                Text("No logs available")
                                    .foregroundColor(.secondary)
                                    .padding()
                                Spacer()
                            }
                        } else {
                            Text(logs)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("logs-bottom")
                        }
                    }
                }
                .background(Color(NSColor.textBackgroundColor))
                .onChange(of: logs) { _ in
                    if autoScroll {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("logs-bottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .onAppear {
            startLogRefresh()
        }
        .onDisappear {
            stopLogRefresh()
        }
    }

    private func startLogRefresh() {
        refreshLogs()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            refreshLogs()
        }
    }

    private func stopLogRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refreshLogs() {
        Task {
            await fetchLogs()
        }
    }

    private func fetchLogs() async {
        await MainActor.run {
            isLoading = true
        }

        do {
            let newLogs = try await containerService.fetchContainerLogs(containerId: containerId)

            await MainActor.run {
                // Only update if logs have changed
                if newLogs != logs {
                    logs = newLogs
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                logs = "Error fetching logs: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    private func clearLogs() {
        logs = ""
        lastLogSize = 0
    }
}

struct LogsView_Previews: PreviewProvider {
    static var previews: some View {
        LogsView(containerId: "test-container")
            .environmentObject(ContainerService())
            .frame(width: 600, height: 400)
    }
}
