import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Claude CLI API 切换器")
                .font(.title)
                .fontWeight(.bold)
            
            Text("此应用在菜单栏中运行")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("功能说明:")
                    .font(.headline)
                
                Text("• 点击菜单栏图标查看和切换配置")
                Text("• 支持多个 Claude CLI API 端点管理")
                Text("• 自动检测 ~/.claude 目录中的 API 配置")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            HStack {
                Button("打开配置目录") {
                    openConfigDirectory()
                }
                .buttonStyle(.bordered)
                
                Button("关闭窗口") {
                    closeWindow()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private func openConfigDirectory() {
        let configDirectory = getRealClaudeConfigDirectory()
        
        // 确保目录存在
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: configDirectory.path) {
            do {
                try fileManager.createDirectory(at: configDirectory, 
                                              withIntermediateDirectories: true, 
                                              attributes: nil)
            } catch {
                print("创建配置目录失败: \(error)")
                return
            }
        }
        
        NSWorkspace.shared.open(configDirectory)
    }
    
    private func getRealClaudeConfigDirectory() -> URL {
        // 直接从用户名构建路径
        let username = NSUserName()
        let realHomePath = "/Users/\(username)"
        
        // 验证路径是否存在
        if FileManager.default.fileExists(atPath: realHomePath) {
            return URL(fileURLWithPath: realHomePath).appendingPathComponent(".claude")
        }
        
        // 备用方案：尝试使用环境变量 HOME
        if let homeDir = ProcessInfo.processInfo.environment["HOME"] {
            return URL(fileURLWithPath: homeDir).appendingPathComponent(".claude")
        }
        
        // 最后备选：解析沙盒路径
        let homeDir = NSHomeDirectory()
        if homeDir.contains("/Containers/") {
            let components = homeDir.components(separatedBy: "/")
            if let userIndex = components.firstIndex(of: "Users"),
               userIndex + 1 < components.count {
                let extractedUsername = components[userIndex + 1]
                return URL(fileURLWithPath: "/Users/\(extractedUsername)").appendingPathComponent(".claude")
            }
        }
        
        return URL(fileURLWithPath: homeDir).appendingPathComponent(".claude")
    }
    
    private func closeWindow() {
        NSApplication.shared.keyWindow?.close()
    }
}