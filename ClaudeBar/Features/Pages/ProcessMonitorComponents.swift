//
//  ProcessMonitorComponents.swift
//  ClaudeBar
//
//  Created by 肖照东 on 2025/7/31.
//

import SwiftUI

// MARK: - 进程监控页面组件

struct ProcessMonitorHeader: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("进程监控")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("监控 Claude CLI 进程状态和性能")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 刷新按钮
                Button(action: refreshProcessStatus) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                        Text("刷新")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            Rectangle()
                .fill(Color(.separatorColor))
                .frame(height: 1)
        }
    }
    
    private func refreshProcessStatus() {
        appState.refreshProcessStatus()
    }
}

struct ProcessStatusCard: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 卡片标题
            HStack {
                Image(systemName: processStatusIcon)
                    .font(.system(size: 18))
                    .foregroundColor(processStatusColor)
                
                Text("Claude 进程状态")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 进程数量标识
                Text("\(appState.claudeProcessStatus.processCount) 个进程")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.controlBackgroundColor))
                    )
            }
            
            // 状态概览
            HStack(spacing: 16) {
                ProcessStatusItem(
                    title: "进程状态",
                    value: processStatusText,
                    icon: processStatusIcon,
                    color: processStatusColor
                )
                
                ProcessStatusItem(
                    title: "总内存使用",
                    value: totalMemoryUsage,
                    icon: "memorychip.fill",
                    color: memoryStatusColor
                )
                
                ProcessStatusItem(
                    title: "平均CPU",
                    value: averageCPUUsage,
                    icon: "cpu.fill",
                    color: cpuStatusColor
                )
            }
            
            // 详细描述
            Text(processStatusDescription)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(processStatusColor.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    private var processStatusIcon: String {
        switch appState.claudeProcessStatus {
        case .running(let processes):
            return processes.isEmpty ? "stop.circle.fill" : "checkmark.circle.fill"
        case .stopped:
            return "stop.circle.fill"
        case .error(_):
            return "xmark.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
    
    private var processStatusColor: Color {
        switch appState.claudeProcessStatus {
        case .running(let processes):
            return processes.isEmpty ? .gray : .green
        case .stopped:
            return .gray
        case .error(_):
            return .red
        case .unknown:
            return .orange
        }
    }
    
    private var processStatusText: String {
        switch appState.claudeProcessStatus {
        case .running(let processes):
            return processes.isEmpty ? "无进程" : "运行中"
        case .stopped:
            return "已停止"
        case .error(_):
            return "错误"
        case .unknown:
            return "未知"
        }
    }
    
    private var processStatusDescription: String {
        switch appState.claudeProcessStatus {
        case .running(let processes):
            if processes.isEmpty {
                return "当前没有检测到 Claude CLI 进程在运行。您可能需要先启动 Claude 命令行工具。"
            } else {
                return "检测到 \(processes.count) 个 Claude 进程正在运行，系统工作正常。"
            }
        case .stopped:
            return "没有 Claude 进程在运行。您可以通过命令行启动 Claude 工具。"
        case .error(let message):
            return "进程监控遇到问题：\(message)"
        case .unknown:
            return "正在检查 Claude 进程状态，请稍候..."
        }
    }
    
    private var totalMemoryUsage: String {
        let processes = appState.claudeProcessStatus.processes
        let totalMemory = processes.compactMap { $0.memoryInfo?.residentSizeMB }.reduce(0, +)
        return totalMemory > 0 ? String(format: "%.1f MB", totalMemory) : "N/A"
    }
    
    private var averageCPUUsage: String {
        let processes = appState.claudeProcessStatus.processes
        let cpuValues = processes.compactMap { $0.cpuUsage }.compactMap { Double($0) }
        if cpuValues.isEmpty {
            return "N/A"
        }
        let average = cpuValues.reduce(0, +) / Double(cpuValues.count)
        return String(format: "%.1f%%", average)
    }
    
    private var memoryStatusColor: Color {
        let processes = appState.claudeProcessStatus.processes
        let totalMemory = processes.compactMap { $0.memoryInfo?.residentSizeMB }.reduce(0, +)
        if totalMemory > 500 {
            return .red
        } else if totalMemory > 200 {
            return .orange
        } else {
            return .green
        }
    }
    
    private var cpuStatusColor: Color {
        let processes = appState.claudeProcessStatus.processes
        let cpuValues = processes.compactMap { $0.cpuUsage }.compactMap { Double($0) }
        if cpuValues.isEmpty {
            return .gray
        }
        let average = cpuValues.reduce(0, +) / Double(cpuValues.count)
        if average > 50 {
            return .red
        } else if average > 20 {
            return .orange
        } else {
            return .green
        }
    }
}

struct ProcessStatusItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.windowBackgroundColor))
        )
    }
}

struct ProcessDetailsList: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("进程详情")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            if appState.claudeProcessStatus.processCount > 0 {
                LazyVStack(spacing: 12) {
                    ForEach(appState.claudeProcessStatus.processes) { process in
                        DetailedProcessRowView(process: process)
                    }
                }
            } else {
                EmptyProcessDetailView()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

struct DetailedProcessRowView: View {
    let process: ProcessService.ClaudeProcess
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 主要信息行
            HStack(spacing: 16) {
                // 状态指示器
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.green)
                }
                
                // 进程信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(process.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("PID: \(process.pid)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    // 性能指标
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CPU 使用率")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text(process.cpuUsageText)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(process.cpuUsageColor))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("内存使用")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text(process.memoryUsageText)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(process.memoryUsageColor))
                        }
                        
                        if let startTime = process.startTime {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("运行时间")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text(formatRunningTime(startTime))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                // 展开/折叠按钮
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                    )
            )
            
            // 详细信息（展开时显示）
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    if let executablePath = process.executablePath {
                        ProcessDetailRow(
                            icon: "terminal",
                            label: "可执行文件",
                            value: executablePath
                        )
                    }
                    
                    if let workingDirectory = process.workingDirectory {
                        ProcessDetailRow(
                            icon: "folder",
                            label: "工作目录",
                            value: workingDirectory
                        )
                    }
                    
                    if let memoryInfo = process.memoryInfo {
                        ProcessDetailRow(
                            icon: "memorychip",
                            label: "物理内存",
                            value: memoryInfo.formattedResident,
                            valueColor: Color(process.memoryUsageColor)
                        )
                        
                        ProcessDetailRow(
                            icon: "square.stack.3d.down.right",
                            label: "虚拟内存",
                            value: String(format: "%.1f MB", memoryInfo.virtualSizeMB)
                        )
                    }
                    
                    ProcessDetailRow(
                        icon: "cpu",
                        label: "CPU 使用率",
                        value: process.cpuUsageText,
                        valueColor: Color(process.cpuUsageColor)
                    )
                    
                    if let startTime = process.startTime {
                        ProcessDetailRow(
                            icon: "clock",
                            label: "启动时间",
                            value: formatStartTime(startTime)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.green.opacity(0.05))
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
            }
        }
    }
    
    private func formatStartTime(_ startTime: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: startTime)
    }
    
    private func formatRunningTime(_ startTime: Date) -> String {
        let interval = Date().timeIntervalSince(startTime)
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

// ProcessDetailRow 已在 StatusComponents.swift 中定义

struct EmptyProcessDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("没有检测到 Claude 进程")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Claude CLI 当前未在运行，请先启动 Claude 命令行工具")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("如何启动 Claude") {
                if let url = URL(string: "https://docs.anthropic.com/claude/docs") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}