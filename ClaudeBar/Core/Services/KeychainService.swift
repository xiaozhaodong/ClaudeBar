import Foundation
import Security

/// Keychain 服务，用于安全存储敏感信息如 API Token
///
/// 这个服务提供了一个安全的方式来存储和管理 Claude 配置的 API Token，
/// 避免将敏感信息以明文形式存储在配置文件中。
///
/// 所有的 Token 都存储在系统钥匙串中，只有当前用户和应用可以访问。
class KeychainService {
    /// 钥匙串服务标识符，用于区分本应用存储的数据
    private let service = "com.claude.bar"
    
    /// 钥匙串操作错误类型
    ///
    /// 定义可能在钥匙串操作过程中出现的各种错误
    enum KeychainError: Error {
        case itemNotFound
        case duplicateItem
        case invalidItemFormat
        case unexpectedError(OSStatus)
        
        /// 错误的本地化描述
        var localizedDescription: String {
            switch self {
            case .itemNotFound:
                return "密钥链中未找到指定项目"
            case .duplicateItem:
                return "密钥链中已存在相同项目"
            case .invalidItemFormat:
                return "密钥链项目格式无效"
            case .unexpectedError(let status):
                return "密钥链操作失败: \(status)"
            }
        }
    }
    
    /// 在钥匙串中存储 API Token
    ///
    /// 将指定配置的 API Token 安全地存储到系统钥匙串中。如果已存在相同配置的 Token，
    /// 会先删除旧的再创建新的，确保不会出现重复项。
    ///
    /// - Parameters:
    ///   - token: 要存储的 API Token
    ///   - configName: 配置名称，用作钥匙串账户标识
    /// - Throws: `KeychainError.duplicateItem` 如果项目已存在且无法删除
    ///           `KeychainError.unexpectedError` 如果钥匙串操作失败
    func store(token: String, for configName: String) throws {
        let account = "\(configName).token"
        
        // 先删除已存在的项目
        _ = delete(for: configName)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: token.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            if status == errSecDuplicateItem {
                throw KeychainError.duplicateItem
            }
            throw KeychainError.unexpectedError(status)
        }
    }
    
    /// 从钥匙串中获取 API Token
    ///
    /// 根据配置名称从系统钥匙串中检索对应的 API Token。
    ///
    /// - Parameter configName: 配置名称
    /// - Returns: 存储的 API Token，如果未找到则返回 nil
    /// - Throws: `KeychainError.invalidItemFormat` 如果存储的数据格式无效
    ///           `KeychainError.unexpectedError` 如果钥匙串操作失败
    func retrieve(for configName: String) throws -> String? {
        let account = "\(configName).token"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.unexpectedError(status)
        }
        
        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidItemFormat
        }
        
        return token
    }
    
    /// 更新已存储的 API Token
    ///
    /// 更新指定配置的 API Token。如果 Token 不存在，会自动创建新的。
    ///
    /// - Parameters:
    ///   - token: 新的 API Token
    ///   - configName: 配置名称
    /// - Throws: `KeychainError.unexpectedError` 如果钥匙串操作失败
    func update(token: String, for configName: String) throws {
        let account = "\(configName).token"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: token.data(using: .utf8)!
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                // 如果不存在，直接创建
                try store(token: token, for: configName)
                return
            }
            throw KeychainError.unexpectedError(status)
        }
    }
    
    /// 从钥匙串中删除 API Token
    ///
    /// 删除指定配置对应的 API Token。即使 Token 不存在，操作也会成功。
    ///
    /// - Parameter configName: 配置名称
    /// - Returns: 操作是否成功。即使项目不存在也返回 true
    @discardableResult
    func delete(for configName: String) -> Bool {
        let account = "\(configName).token"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// 列出钥匙串中存储的所有配置名称
    ///
    /// 扫描钥匙串中所有属于本应用的 Token 项目，提取配置名称列表。
    ///
    /// - Returns: 按字母顺序排序的配置名称数组
    func listStoredConfigs() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }
        
        var configNames: [String] = []
        for item in items {
            if let account = item[kSecAttrAccount as String] as? String,
               account.hasSuffix(".token") {
                let configName = String(account.dropLast(".token".count))
                configNames.append(configName)
            }
        }
        
        return configNames.sorted()
    }
    
    /// 清除钥匙串中所有存储的配置数据
    ///
    /// 删除所有属于本应用的钥匙串项目。这是一个危险操作，会永久删除所有存储的 Token。
    ///
    /// - Returns: 操作是否成功
    /// - Warning: 此操作不可撤销，请谨慎使用
    func clearAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}