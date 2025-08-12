# ClaudeBar SQLite 配置管理改造方案

## 概述

将现有的基于 JSON 文件的配置管理系统改造为基于 SQLite 数据库的方案，实现数据存储分离，提高性能和数据完整性。

## 设计原则

### 数据存储分离策略
- **应用内部数据库**: 存储完整的配置管理数据
- **外部配置文件**: 仅导出当前激活配置供 Claude CLI 使用
- **最小化污染**: 不在用户 ~/.claude 目录存储应用专用数据

## 架构设计

### 1. 数据库位置
```
~/Library/Application Support/ClaudeBar/
├── configs.db          # SQLite 数据库文件
└── app_data/           # 其他应用数据（备份、日志等）
```

### 2. 外部文件
```
~/.claude/
├── settings.json       # 当前激活配置（由应用维护）
└── *.jsonl            # Claude CLI 生成的使用日志（只读）
```

## 数据库设计

### 表结构设计

#### configs 表（配置主表）
```sql
CREATE TABLE configs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,           -- 配置名称
    base_url TEXT NOT NULL,              -- API Base URL  
    auth_token TEXT NOT NULL,            -- API Token
    max_output_tokens INTEGER DEFAULT 32000, -- 最大输出 Token
    disable_nonessential_traffic INTEGER DEFAULT 1, -- 禁用非必要流量
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_used_at DATETIME,               -- 最后使用时间
    is_active INTEGER DEFAULT 0,         -- 是否为当前激活配置
    is_valid INTEGER DEFAULT 1,          -- 配置是否有效
    notes TEXT                           -- 备注信息
);
```

#### config_permissions 表（权限配置）
```sql
CREATE TABLE config_permissions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    config_id INTEGER NOT NULL,
    permission_type TEXT NOT NULL,       -- 'allow' 或 'deny'
    permission_value TEXT NOT NULL,      -- 权限值
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (config_id) REFERENCES configs(id) ON DELETE CASCADE
);
```

#### config_usage_stats 表（使用统计缓存）
```sql
CREATE TABLE config_usage_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    config_id INTEGER NOT NULL,
    date TEXT NOT NULL,                  -- YYYY-MM-DD 格式
    input_tokens INTEGER DEFAULT 0,
    output_tokens INTEGER DEFAULT 0,
    cached_tokens INTEGER DEFAULT 0,
    request_count INTEGER DEFAULT 0,
    cost_amount REAL DEFAULT 0.0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (config_id) REFERENCES configs(id) ON DELETE CASCADE,
    UNIQUE(config_id, date)
);
```

### 索引设计
```sql
-- 性能优化索引
CREATE INDEX idx_configs_name ON configs(name);
CREATE INDEX idx_configs_is_active ON configs(is_active);
CREATE INDEX idx_configs_last_used ON configs(last_used_at DESC);
CREATE INDEX idx_permissions_config_id ON config_permissions(config_id);
CREATE INDEX idx_usage_stats_config_date ON config_usage_stats(config_id, date);
```

## 技术实现方案

### 1. SQLite 集成方式

#### 选择 SQLite.swift 库
```swift
// Package.swift 或 Xcode Package Manager
.package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.14.1")
```

#### 数据库连接管理
```swift
import SQLite

class DatabaseManager {
    private var db: Connection?
    private let dbPath: String
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                 in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("ClaudeBar")
        dbPath = appDir.appendingPathComponent("configs.db").path
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: appDir, 
                                               withIntermediateDirectories: true)
    }
}
```

### 2. 服务层设计

#### SQLiteConfigService 类
```swift
class SQLiteConfigService: ConfigServiceProtocol {
    private let dbManager: DatabaseManager
    private let settingsExporter: SettingsExporter
    
    // CRUD 操作
    func createConfig(_ config: ClaudeConfig) async throws
    func loadConfigs() async throws -> [ClaudeConfig]
    func switchToConfig(_ config: ClaudeConfig) async throws
    func deleteConfig(_ config: ClaudeConfig) async throws
    func getCurrentConfig() -> ClaudeConfig?
    
    // 扩展功能
    func getUsageStats(for configId: Int, dateRange: DateRange) async throws -> [UsageStats]
    func updateConfigUsage(_ configId: Int, stats: UsageStats) async throws
}
```

#### SettingsExporter 类
```swift
class SettingsExporter {
    private let claudeSettingsPath = "~/.claude/settings.json"
    
    func exportCurrentConfig(_ config: ClaudeConfig) throws {
        let settingsData: [String: Any] = [
            "env": [
                "ANTHROPIC_AUTH_TOKEN": config.authToken,
                "ANTHROPIC_BASE_URL": config.baseURL,
                "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "\(config.maxOutputTokens)",
                "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "\(config.disableNonessentialTraffic)"
            ],
            "permissions": [
                "allow": config.allowPermissions,
                "deny": config.denyPermissions
            ],
            "cleanupPeriodDays": 365,
            "includeCoAuthoredBy": false
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: settingsData, options: [.prettyPrinted])
        try jsonData.write(to: URL(fileURLWithPath: claudeSettingsPath.expandingTildeInPath))
    }
}
```

## 数据迁移方案

### 1. 迁移策略
- **向后兼容**: 继续支持读取现有 JSON 配置文件
- **渐进迁移**: 首次启动时自动迁移现有配置到数据库
- **数据校验**: 迁移后验证数据完整性

### 2. 迁移流程
```swift
class ConfigMigrationService {
    func migrateFromJsonToSqlite() async throws {
        // 1. 检查是否需要迁移
        guard needsMigration() else { return }
        
        // 2. 读取现有 JSON 配置
        let existingConfigs = try loadExistingJsonConfigs()
        
        // 3. 迁移到 SQLite
        for config in existingConfigs {
            try await sqliteService.createConfig(config)
        }
        
        // 4. 标记迁移完成
        UserDefaults.standard.set(true, forKey: "config_migrated_to_sqlite")
        
        // 5. 备份原文件（可选）
        try backupOriginalFiles()
    }
}
```

## 实现计划

### 阶段一：基础架构搭建
1. **集成 SQLite.swift 依赖**
2. **创建 DatabaseManager 类**
3. **设计数据库表结构并创建迁移脚本**
4. **实现基础的 CRUD 操作**

### 阶段二：服务层重构
1. **创建 SQLiteConfigService 类**
2. **实现 SettingsExporter 类**
3. **重构 AppState 以使用新的服务**
4. **更新所有相关的 ViewModel**

### 阶段三：数据迁移
1. **实现 ConfigMigrationService**
2. **创建数据校验逻辑**
3. **测试迁移流程的各种场景**
4. **添加错误恢复机制**

### 阶段四：UI 适配
1. **更新配置管理界面**
2. **添加数据库状态监控**
3. **优化用户体验（加载状态、错误提示）**
4. **测试所有功能点**

### 阶段五：测试与优化
1. **单元测试覆盖**
2. **性能测试和优化**
3. **边界条件测试**
4. **用户接受度测试**

## 预期收益

### 性能提升
- **查询速度**: SQLite 比 JSON 文件解析快 3-5 倍
- **并发安全**: 数据库事务保证数据一致性
- **内存使用**: 按需加载，减少内存占用

### 功能扩展
- **使用统计**: 轻松添加配置使用频率统计
- **历史记录**: 记录配置变更历史
- **备份恢复**: 一键导出导入所有配置
- **搜索过滤**: 支持复杂的配置搜索和过滤

### 用户体验
- **响应速度**: 配置切换更快响应
- **数据安全**: 事务保证防止数据丢失
- **扩展性**: 为未来功能预留空间

## 风险评估

### 技术风险
- **依赖风险**: SQLite.swift 库的稳定性（风险较低）
- **迁移风险**: 数据迁移可能失败（通过备份和回滚机制降低）
- **兼容性**: macOS 版本兼容性（SQLite 是系统内置，风险很低）

### 业务风险
- **用户学习成本**: 界面变化不大，风险低
- **数据丢失**: 通过备份机制和测试降低风险

## 总结

SQLite 配置管理改造将显著提升 ClaudeBar 的性能和扩展性，同时保持对用户 ~/.claude 目录的最小影响。通过分阶段实施和充分测试，可以确保改造过程平稳进行。