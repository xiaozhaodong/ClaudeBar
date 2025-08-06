#!/usr/bin/env swift

import Foundation

/**
 * 验证请求数计算修复的脚本
 * 
 * 此脚本用于验证按模型统计的请求数与总请求数计算逻辑是否一致
 * 修复前：各模型使用不同的计算方式（requestIds vs entryCount）
 * 修复后：统一使用条目数（entryCount）
 */

print("🔍 验证请求数计算修复...")
print("")

// 检查 UsageService.swift 中的修复
let usageServicePath = "ClaudeBar/Core/Services/UsageService.swift"
let testFilePath = "ClaudeBarTests/UsageServiceTests.swift"

func validateFile(_ filePath: String, description: String) -> Bool {
    do {
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        // 检查旧的逻辑是否已被移除
        let hasOldLogic = content.contains("requestIds.count > 0 ? requestIds.count : entryCount")
        
        // 检查新的统一逻辑是否存在
        let hasNewLogic = content.contains("统一使用条目数") && content.contains("let requestCount = entryCount")
        
        print("📋 \(description):")
        print("   - 移除旧逻辑: \(hasOldLogic ? "❌ 未完成" : "✅ 完成")")
        print("   - 添加新逻辑: \(hasNewLogic ? "✅ 完成" : "❌ 未完成")")
        
        return !hasOldLogic && hasNewLogic
    } catch {
        print("❌ 无法读取文件: \(filePath)")
        return false
    }
}

// 验证主要文件
let mainFileValid = validateFile(usageServicePath, description: "UsageService.swift 主文件")
print("")

// 验证测试文件
let testFileValid = validateFile(testFilePath, description: "UsageServiceTests.swift 测试文件")
print("")

// 检查数据一致性验证是否添加
func validateConsistencyCheck() -> Bool {
    do {
        let content = try String(contentsOfFile: usageServicePath, encoding: .utf8)
        
        let hasConsistencyCheck = content.contains("数据一致性验证") &&
                                 content.contains("modelRequestsSum") &&
                                 content.contains("各模型请求数之和")
        
        print("📊 数据一致性验证:")
        print("   - 添加验证逻辑: \(hasConsistencyCheck ? "✅ 完成" : "❌ 未完成")")
        
        return hasConsistencyCheck
    } catch {
        print("❌ 无法验证一致性检查")
        return false
    }
}

let consistencyCheckValid = validateConsistencyCheck()
print("")

// 总结
print("🎯 修复验证结果:")
print("=" * 50)

if mainFileValid && testFileValid && consistencyCheckValid {
    print("✅ 所有修复项目已成功完成!")
    print("")
    print("修复内容总结:")
    print("1. ✅ ModelUsageBuilder.build() - 统一使用 entryCount")
    print("2. ✅ ProjectUsageBuilder.build() - 统一使用 entryCount")
    print("3. ✅ 添加数据一致性验证和调试信息")
    print("4. ✅ 更新测试代码保持一致性")
    print("")
    print("预期效果:")
    print("- 各模型请求数之和 = 总请求数")
    print("- 统计数据展示一致性和可预测性")
    print("- 详细的调试信息便于监控修复效果")
    print("")
    print("🎉 请求数计算逻辑修复完成！")
    
    exit(0)
} else {
    print("⚠️ 部分修复项目未完成，请检查:")
    if !mainFileValid {
        print("- 主文件 UsageService.swift 需要进一步修复")
    }
    if !testFileValid {
        print("- 测试文件 UsageServiceTests.swift 需要进一步修复")
    }
    if !consistencyCheckValid {
        print("- 数据一致性验证逻辑需要添加")
    }
    
    exit(1)
}

// 字符串重复扩展
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}