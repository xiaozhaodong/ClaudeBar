import Foundation
import SQLite3

/// SQLite 数据库管理器
/// 专门管理 API 配置的数据库操作
class DatabaseManager {
    private var db: OpaquePointer?
    private let dbPath: String
    private let dbQueue = DispatchQueue(label: "com.claude.database", qos: .userInitiated)
    
    init() {
        // 数据库文件路径
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                 in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("ClaudeBar")
        
        // 确保应用支持目录存在
        try? FileManager.default.createDirectory(at: appDir, 
                                               withIntermediateDirectories: true)
        
        dbPath = appDir.appendingPathComponent("configs.db").path
        
        print("数据库路径: \(dbPath)")
        
        do {
            try openDatabase()
            try createTables()
        } catch {
            print("数据库初始化失败: \(error)")
        }
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    /// 打开数据库连接
    private func openDatabase() throws {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            sqlite3_close(db)
            throw DatabaseError.connectionFailed
        }
        print("数据库连接成功")
    }
    
    /// 创建数据库表结构
    private func createTables() throws {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS api_configs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            base_url TEXT NOT NULL,
            auth_token TEXT NOT NULL,
            is_active INTEGER DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("创建表失败: \(errmsg)")
            throw DatabaseError.operationFailed
        }
        
        // 创建索引
        let createIndexSQL = """
        CREATE INDEX IF NOT EXISTS idx_api_configs_name ON api_configs(name);
        CREATE INDEX IF NOT EXISTS idx_api_configs_active ON api_configs(is_active);
        """
        
        if sqlite3_exec(db, createIndexSQL, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("创建索引警告: \(errmsg)")
        }
        
        print("数据库表创建成功")
    }
    
    /// 获取所有配置
    func getAllConfigs() throws -> [APIConfigRecord] {
        return try dbQueue.sync {
            return try getAllConfigsInternal()
        }
    }
    
    /// 内部实现 - 获取所有配置
    private func getAllConfigsInternal() throws -> [APIConfigRecord] {
        let query = "SELECT id, name, base_url, auth_token, is_active, created_at, updated_at FROM api_configs ORDER BY name"
        var statement: OpaquePointer?
        var configs: [APIConfigRecord] = []
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = sqlite3_column_int64(statement, 0)
                
                // 安全地获取文本字段，防止空指针崩溃
                let namePtr = sqlite3_column_text(statement, 1)
                let name = namePtr != nil ? String(cString: namePtr!) : ""
                
                let baseURLPtr = sqlite3_column_text(statement, 2)
                let baseURL = baseURLPtr != nil ? String(cString: baseURLPtr!) : ""
                
                let authTokenPtr = sqlite3_column_text(statement, 3)
                let authToken = authTokenPtr != nil ? String(cString: authTokenPtr!) : ""
                
                let isActive = sqlite3_column_int(statement, 4) == 1
                
                let createdAtPtr = sqlite3_column_text(statement, 5)
                let createdAtString = createdAtPtr != nil ? String(cString: createdAtPtr!) : ""
                
                let updatedAtPtr = sqlite3_column_text(statement, 6)
                let updatedAtString = updatedAtPtr != nil ? String(cString: updatedAtPtr!) : ""
                
                let formatter = ISO8601DateFormatter()
                let createdAt = formatter.date(from: createdAtString) ?? Date()
                let updatedAt = formatter.date(from: updatedAtString) ?? Date()
                
                let record = APIConfigRecord(
                    id: id,
                    name: name,
                    baseURL: baseURL,
                    authToken: authToken,
                    isActive: isActive,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
                configs.append(record)
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("查询失败: \(errmsg)")
            throw DatabaseError.operationFailed
        }
        
        sqlite3_finalize(statement)
        return configs
    }
    
    /// 获取当前活动配置
    func getActiveConfig() throws -> APIConfigRecord? {
        return try dbQueue.sync {
            return try getActiveConfigInternal()
        }
    }
    
    /// 内部实现 - 获取当前活动配置
    private func getActiveConfigInternal() throws -> APIConfigRecord? {
        let query = "SELECT id, name, base_url, auth_token, is_active, created_at, updated_at FROM api_configs WHERE is_active = 1 LIMIT 1"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                let id = sqlite3_column_int64(statement, 0)
                
                // 安全地获取文本字段，防止空指针崩溃
                let namePtr = sqlite3_column_text(statement, 1)
                let name = namePtr != nil ? String(cString: namePtr!) : ""
                
                let baseURLPtr = sqlite3_column_text(statement, 2)
                let baseURL = baseURLPtr != nil ? String(cString: baseURLPtr!) : ""
                
                let authTokenPtr = sqlite3_column_text(statement, 3)
                let authToken = authTokenPtr != nil ? String(cString: authTokenPtr!) : ""
                
                let isActive = sqlite3_column_int(statement, 4) == 1
                
                let createdAtPtr = sqlite3_column_text(statement, 5)
                let createdAtString = createdAtPtr != nil ? String(cString: createdAtPtr!) : ""
                
                let updatedAtPtr = sqlite3_column_text(statement, 6)
                let updatedAtString = updatedAtPtr != nil ? String(cString: updatedAtPtr!) : ""
                
                let formatter = ISO8601DateFormatter()
                let createdAt = formatter.date(from: createdAtString) ?? Date()
                let updatedAt = formatter.date(from: updatedAtString) ?? Date()
                
                sqlite3_finalize(statement)
                return APIConfigRecord(
                    id: id,
                    name: name,
                    baseURL: baseURL,
                    authToken: authToken,
                    isActive: isActive,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("查询活动配置失败: \(errmsg)")
            throw DatabaseError.operationFailed
        }
        
        sqlite3_finalize(statement)
        return nil
    }
    
    /// 创建新配置
    func createConfig(_ record: APIConfigRecord) throws {
        try dbQueue.sync {
            try createConfigInternal(record)
        }
    }
    
    /// 内部实现 - 创建新配置
    private func createConfigInternal(_ record: APIConfigRecord) throws {
        let insertSQL = "INSERT INTO api_configs (name, base_url, auth_token, is_active) VALUES (?, ?, ?, ?)"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            // 使用 SQLITE_TRANSIENT 确保字符串被正确复制和处理
            record.name.withCString { cString in
                sqlite3_bind_text(statement, 1, cString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
            
            record.baseURL.withCString { cString in
                sqlite3_bind_text(statement, 2, cString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
            
            record.authToken.withCString { cString in
                sqlite3_bind_text(statement, 3, cString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
            
            sqlite3_bind_int(statement, 4, record.isActive ? 1 : 0)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("配置创建成功: \(record.name)")
            } else {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("创建配置失败: \(errmsg)")
                throw DatabaseError.operationFailed
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("准备创建配置语句失败: \(errmsg)")
            throw DatabaseError.operationFailed
        }
        
        sqlite3_finalize(statement)
    }
    
    /// 更新配置
    func updateConfig(_ record: APIConfigRecord) throws {
        try dbQueue.sync {
            try updateConfigInternal(record)
        }
    }
    
    /// 内部实现 - 更新配置
    private func updateConfigInternal(_ record: APIConfigRecord) throws {
        let updateSQL = "UPDATE api_configs SET name = ?, base_url = ?, auth_token = ?, is_active = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
            // 使用 SQLITE_TRANSIENT 确保字符串被正确复制和处理
            record.name.withCString { cString in
                sqlite3_bind_text(statement, 1, cString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
            
            record.baseURL.withCString { cString in
                sqlite3_bind_text(statement, 2, cString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
            
            record.authToken.withCString { cString in
                sqlite3_bind_text(statement, 3, cString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
            
            sqlite3_bind_int(statement, 4, record.isActive ? 1 : 0)
            sqlite3_bind_int64(statement, 5, record.id)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("配置更新成功: \(record.name)")
            } else {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("更新配置失败: \(errmsg)")
                throw DatabaseError.operationFailed
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("准备更新配置语句失败: \(errmsg)")
            throw DatabaseError.operationFailed
        }
        
        sqlite3_finalize(statement)
    }
    
    /// 删除配置
    func deleteConfig(byId configId: Int64) throws {
        try dbQueue.sync {
            try deleteConfigInternal(byId: configId)
        }
    }
    
    /// 内部实现 - 删除配置
    private func deleteConfigInternal(byId configId: Int64) throws {
        let deleteSQL = "DELETE FROM api_configs WHERE id = ?"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int64(statement, 1, configId)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("配置删除成功: ID \(configId)")
            } else {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("删除配置失败: \(errmsg)")
                throw DatabaseError.operationFailed
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("准备删除配置语句失败: \(errmsg)")
            throw DatabaseError.operationFailed
        }
        
        sqlite3_finalize(statement)
    }
    
    /// 设置活动配置（只能有一个活动配置）
    func setActiveConfig(byId configId: Int64) throws {
        try dbQueue.sync {
            try setActiveConfigInternal(byId: configId)
        }
    }
    
    /// 内部实现 - 设置活动配置
    private func setActiveConfigInternal(byId configId: Int64) throws {
        // 开始事务
        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
        
        do {
            // 先将所有配置设为非活动状态
            let deactivateSQL = "UPDATE api_configs SET is_active = 0, updated_at = CURRENT_TIMESTAMP"
            if sqlite3_exec(db, deactivateSQL, nil, nil, nil) != SQLITE_OK {
                throw DatabaseError.operationFailed
            }
            
            // 设置指定配置为活动状态
            let activateSQL = "UPDATE api_configs SET is_active = 1, updated_at = CURRENT_TIMESTAMP WHERE id = ?"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, activateSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_int64(statement, 1, configId)
                
                if sqlite3_step(statement) == SQLITE_DONE {
                    sqlite3_finalize(statement)
                    // 提交事务
                    sqlite3_exec(db, "COMMIT", nil, nil, nil)
                    print("活动配置已设置: ID \(configId)")
                } else {
                    sqlite3_finalize(statement)
                    throw DatabaseError.operationFailed
                }
            } else {
                throw DatabaseError.operationFailed
            }
        } catch {
            // 回滚事务
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("设置活动配置失败: \(errmsg)")
            throw error
        }
    }
    
    /// 根据名称查找配置
    func getConfig(byName configName: String) throws -> APIConfigRecord? {
        return try dbQueue.sync {
            return try getConfigInternal(byName: configName)
        }
    }
    
    /// 内部实现 - 根据名称查找配置
    private func getConfigInternal(byName configName: String) throws -> APIConfigRecord? {
        let query = "SELECT id, name, base_url, auth_token, is_active, created_at, updated_at FROM api_configs WHERE name = ? LIMIT 1"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            // 使用 SQLITE_TRANSIENT 确保字符串被正确复制和处理
            configName.withCString { cString in
                sqlite3_bind_text(statement, 1, cString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let id = sqlite3_column_int64(statement, 0)
                
                // 安全地获取文本字段，防止空指针崩溃
                let namePtr = sqlite3_column_text(statement, 1)
                let name = namePtr != nil ? String(cString: namePtr!) : ""
                
                let baseURLPtr = sqlite3_column_text(statement, 2)
                let baseURL = baseURLPtr != nil ? String(cString: baseURLPtr!) : ""
                
                let authTokenPtr = sqlite3_column_text(statement, 3)
                let authToken = authTokenPtr != nil ? String(cString: authTokenPtr!) : ""
                
                let isActive = sqlite3_column_int(statement, 4) == 1
                
                let createdAtPtr = sqlite3_column_text(statement, 5)
                let createdAtString = createdAtPtr != nil ? String(cString: createdAtPtr!) : ""
                
                let updatedAtPtr = sqlite3_column_text(statement, 6)
                let updatedAtString = updatedAtPtr != nil ? String(cString: updatedAtPtr!) : ""
                
                let formatter = ISO8601DateFormatter()
                let createdAt = formatter.date(from: createdAtString) ?? Date()
                let updatedAt = formatter.date(from: updatedAtString) ?? Date()
                
                sqlite3_finalize(statement)
                return APIConfigRecord(
                    id: id,
                    name: name,
                    baseURL: baseURL,
                    authToken: authToken,
                    isActive: isActive,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("按名称查询配置失败: \(errmsg)")
            throw DatabaseError.operationFailed
        }
        
        sqlite3_finalize(statement)
        return nil
    }
    
    /// 检查配置名称是否存在
    func configExists(name configName: String) throws -> Bool {
        return try dbQueue.sync {
            return try configExistsInternal(name: configName)
        }
    }
    
    /// 内部实现 - 检查配置名称是否存在
    private func configExistsInternal(name configName: String) throws -> Bool {
        let query = "SELECT COUNT(*) FROM api_configs WHERE name = ?"
        var statement: OpaquePointer?
        var count = 0
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            // 使用 SQLITE_TRANSIENT 确保字符串被正确复制和处理
            configName.withCString { cString in
                sqlite3_bind_text(statement, 1, cString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
            
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("检查配置存在性失败: \(errmsg)")
            throw DatabaseError.operationFailed
        }
        
        sqlite3_finalize(statement)
        return count > 0
    }
}

/// API 配置记录数据结构
struct APIConfigRecord {
    let id: Int64
    let name: String
    let baseURL: String
    let authToken: String
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    
    /// 用于创建新记录的便利初始化器
    init(name: String, baseURL: String, authToken: String, isActive: Bool = false) {
        self.id = 0 // 数据库自动生成
        self.name = name
        self.baseURL = baseURL
        self.authToken = authToken
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// 完整初始化器（用于从数据库读取）
    init(id: Int64, name: String, baseURL: String, authToken: String, 
         isActive: Bool, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.authToken = authToken
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// 数据库错误类型
enum DatabaseError: Error {
    case connectionFailed
    case configNotFound
    case configExists
    case operationFailed
    
    var localizedDescription: String {
        switch self {
        case .connectionFailed:
            return "数据库连接失败"
        case .configNotFound:
            return "配置不存在"
        case .configExists:
            return "配置已存在"
        case .operationFailed:
            return "数据库操作失败"
        }
    }
}