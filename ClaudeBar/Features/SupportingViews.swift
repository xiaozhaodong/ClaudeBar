import SwiftUI

// MARK: - DirectoryStatusIndicator (移植自 SettingsView)

struct DirectoryStatusIndicator: View {
    let path: String
    @State private var directoryExists = false
    @State private var configCount = 0
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(statusColor)
        }
        .onAppear {
            checkDirectoryStatus()
        }
        .onChange(of: path) {
            checkDirectoryStatus()
        }
    }
    
    private var statusColor: Color {
        if !directoryExists {
            return .red
        } else if configCount == 0 {
            return .orange
        } else {
            return .green
        }
    }
    
    private var statusText: String {
        if !directoryExists {
            return "目录不存在"
        } else if configCount == 0 {
            return "无配置文件"
        } else {
            return "\(configCount) 个配置"
        }
    }
    
    private func checkDirectoryStatus() {
        let url = URL(fileURLWithPath: path)
        let fileManager = FileManager.default
        
        directoryExists = fileManager.fileExists(atPath: url.path)
        
        if directoryExists {
            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                configCount = contents.filter { $0.pathExtension == "json" && $0.lastPathComponent.contains("-settings") }.count
            } catch {
                configCount = 0
            }
        } else {
            configCount = 0
        }
    }
}

