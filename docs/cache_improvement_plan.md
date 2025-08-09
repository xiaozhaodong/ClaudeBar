# 缓存策略优化改进计划

## 📊 现状分析

### 当前缓存架构：三层内存缓存

#### 第一层：ViewModel缓存
- **位置**：`UsageStatisticsViewModel.statisticsCache`
- **数据结构**：`[DateRange: UsageStatistics]`
- **特点**：简单字典缓存，用于页面切换优化
- **生命周期**：与ViewModel实例绑定

#### 第二层：Service层缓存 (核心缓存)
- **位置**：`UsageServiceActor.cachedData`
- **数据结构**：`[String: CachedUsageData]`
- **策略**：30分钟过期时间
- **键名格式**：`{dateRange}_{projectPath}`
- **元数据**：包含过期时间、命中次数、数据大小等

#### 第三层：解析器缓存
- **位置**：`StreamingJSONLParser.JSONLParserCache`
- **策略**：1小时过期，基于文件修改时间
- **粒度**：单个JSONL文件级别
- **功能**：避免重复解析相同文件

### ✅ 现有优势

1. **响应速度快**：多层内存缓存，毫秒级响应
2. **并发安全**：Actor模式保证线程安全
3. **智能失效**：多维度缓存失效机制
4. **状态透明**：完善的缓存状态监控
5. **用户体验好**：流畅的页面切换

### ❌ 存在问题

1. **冷启动慢**：应用重启后缓存全部丢失，需要3-5秒重新解析
2. **内存压力大**：大数据集可占用50-100MB内存
3. **非持久化**：无法跨应用会话保持缓存
4. **架构复杂**：三层缓存增加系统复杂度
5. **资源浪费**：频繁启动时重复解析相同数据

## 🎯 改进目标

### 主要目标
- **大幅提升冷启动速度**：从3-5秒减少到0.5-1秒
- **降低内存占用**：减少50-70%内存使用
- **增强数据持久性**：跨会话保持缓存有效性
- **简化架构复杂度**：减少缓存层级，优化维护性

### 次要目标
- **扩大缓存容量**：支持更多历史数据缓存
- **提升系统稳定性**：减少内存压力相关的问题
- **增强调试能力**：更好的缓存性能监控

## 🏗️ 新架构设计：混合缓存策略

### 整体设计思路

采用**内存+磁盘**的两级混合缓存架构：
- **L1缓存（内存）**：热数据快速访问，保持现有响应速度
- **L2缓存（磁盘）**：冷数据持久化存储，解决冷启动问题

### L1缓存：内存热缓存

**位置**：保留并优化现有 `UsageServiceActor` 缓存

**策略调整**：
- **缓存容量**：限制为最近使用的3个时间段
- **过期时间**：调整为15分钟（更短的热缓存周期）
- **淘汰策略**：LRU（最近最少使用）算法
- **数据类型**：完整的 `UsageStatistics` 对象

**优化目标**：
- 保持毫秒级响应速度
- 控制内存占用在合理范围内
- 快速响应用户常见操作

### L2缓存：磁盘持久化缓存

**存储位置**：
```
~/.claude/cache/usage_statistics/
├── metadata.json                 # 缓存元数据索引
├── all_time.cache               # 全部时间段缓存文件
├── last_7_days.cache            # 最近7天缓存文件  
├── last_30_days.cache           # 最近30天缓存文件
└── temp/                        # 临时文件目录
```

**文件格式**：
```json
{
  "version": "1.0",
  "dateRange": "all",
  "projectPath": null,
  "cacheTime": "2024-XX-XX 10:30:00",
  "expiryTime": "2024-XX-XX 11:00:00", 
  "sourceFilesHash": "abc123...",     // 源JSONL文件哈希
  "statistics": {
    "totalCost": 125.67,
    "totalTokens": 1208150693,
    // ... 完整的UsageStatistics数据
  }
}
```

**缓存策略**：
- **失效机制**：基于源JSONL文件修改时间和内容哈希
- **过期时间**：6小时（平衡数据新鲜度与性能）
- **压缩存储**：可选择gzip压缩减少磁盘占用
- **元数据索引**：快速查找和验证缓存有效性

## 🔧 详细实现计划

### 阶段1：创建磁盘缓存基础设施

#### 1.1 创建 `DiskCacheService` 核心类

**文件**：`Core/Services/DiskCacheService.swift`

**主要接口**：
```swift
class DiskCacheService {
    // 初始化缓存目录
    init(cacheDirectory: URL)
    
    // 读取缓存
    func getCachedStatistics(for dateRange: DateRange, projectPath: String?) async -> UsageStatistics?
    
    // 写入缓存  
    func setCachedStatistics(_ statistics: UsageStatistics, for dateRange: DateRange, projectPath: String?, sourceFilesHash: String) async
    
    // 验证缓存有效性
    func isCacheValid(for dateRange: DateRange, projectPath: String?, currentFilesHash: String) async -> Bool
    
    // 清理过期缓存
    func cleanupExpiredCache() async
    
    // 获取缓存统计信息
    func getCacheStats() async -> DiskCacheStats
}
```

#### 1.2 实现缓存文件管理

**功能模块**：
- 缓存目录创建和权限管理
- 文件原子性写入（避免并发问题）
- 损坏文件检测和恢复
- 磁盘空间监控和清理

#### 1.3 创建源文件哈希计算机制

**目的**：精确检测JSONL文件变化，决定缓存失效

**实现方式**：
- 计算所有相关JSONL文件的修改时间和大小组合哈希
- 支持增量哈希计算，优化大数据集性能
- 缓存文件列表，避免重复文件系统扫描

### 阶段2：集成混合缓存逻辑

#### 2.1 重构 `UsageService` 缓存查找顺序

**新的数据获取流程**：
```
1. 检查L1缓存（内存）→ 命中则直接返回
2. 检查L2缓存（磁盘）→ 命中且有效则加载到L1并返回
3. 重新解析JSONL → 写入L2缓存，加载到L1，返回数据
```

**关键方法重构**：
```swift
func getUsageStatistics(dateRange: DateRange, projectPath: String?) async throws -> UsageStatistics {
    // 1. L1缓存查找
    if let l1Data = await checkL1Cache(dateRange, projectPath) {
        return l1Data
    }
    
    // 2. L2缓存查找
    if let l2Data = await diskCacheService.getCachedStatistics(for: dateRange, projectPath: projectPath) {
        await setL1Cache(l2Data, dateRange, projectPath)
        return l2Data
    }
    
    // 3. 重新解析
    let statistics = try await parseAndCalculateStatistics(dateRange, projectPath)
    
    // 4. 写入两级缓存
    await diskCacheService.setCachedStatistics(statistics, for: dateRange, projectPath: projectPath, sourceFilesHash: currentHash)
    await setL1Cache(statistics, dateRange, projectPath)
    
    return statistics
}
```

#### 2.2 实现异步缓存写入机制

**目标**：不阻塞用户操作的情况下写入磁盘缓存

**实现**：
- 使用 `Task.detached` 异步写入L2缓存
- 写入队列管理，避免并发写入冲突
- 写入失败时的重试和降级策略

#### 2.3 添加缓存预热机制

**时机**：
- 应用启动时预热最常用的时间段（全部时间）
- 用户操作间隙预热相关时间段

**策略**：
- 后台异步预热，不影响用户体验
- 基于使用统计智能预测需要预热的数据

### 阶段3：优化现有缓存层

#### 3.1 简化ViewModel缓存逻辑

**现状问题**：
- ViewModel层缓存与Service层功能重叠
- 同步逻辑复杂，容易出现不一致

**优化方案**：
- 移除ViewModel层的 `statisticsCache`
- 完全依赖Service层的L1缓存
- 简化 `onPageAppear` 和 `switchToDateRange` 逻辑

#### 3.2 调整Service层缓存策略

**容量限制**：
```swift
// 限制L1缓存最大容量
private let maxCacheItems = 3
private let maxMemoryUsage = 50 * 1024 * 1024  // 50MB

// LRU淘汰策略
private var accessOrder: [String] = []
```

**智能淘汰**：
- 基于访问频率和数据大小的综合评分
- 优先保留用户最常访问的时间段
- 动态调整缓存大小

#### 3.3 重构解析器缓存

**简化目标**：避免与磁盘缓存功能重叠

**调整方案**：
- 保留文件级解析缓存，但缩短过期时间至15分钟
- 主要用于同一会话内的重复解析优化
- 与磁盘缓存形成互补而非竞争关系

### 阶段4：性能优化和监控

#### 4.1 添加性能监控指标

**关键指标**：
```swift
struct CachePerformanceMetrics {
    var l1HitRate: Double          // L1缓存命中率
    var l2HitRate: Double          // L2缓存命中率  
    var avgLoadTime: TimeInterval  // 平均加载时间
    var memoryUsage: Int          // 内存使用量
    var diskUsage: Int            // 磁盘使用量
    var coldStartTime: TimeInterval // 冷启动时间
}
```

**监控机制**：
- 实时性能数据收集
- 关键操作的性能埋点
- 异常情况的自动报警

#### 4.2 实现缓存健康检查

**检查项目**：
- 磁盘空间充足性
- 缓存文件完整性
- 内存使用合理性
- 命中率健康水平

**自动修复**：
- 损坏文件自动清理
- 过期缓存定时清理
- 内存溢出时的紧急清理

#### 4.3 增强错误处理和降级策略

**磁盘缓存失败时**：
```swift
// 降级到纯内存缓存模式
if diskCacheService.isAvailable == false {
    Logger.shared.warning("磁盘缓存不可用，降级到内存缓存模式")
    // 扩大L1缓存容量作为补偿
    maxCacheItems = 5
}
```

**内存压力大时**：
```swift
// 激进的内存释放策略
if memoryPressureDetected {
    await clearL1Cache()
    await diskCacheService.flushPendingWrites()
}
```

## 📈 预期性能提升

### 量化指标

| 指标 | 当前表现 | 预期表现 | 提升幅度 |
|------|----------|----------|----------|
| 冷启动时间 | 3-5秒 | 0.5-1秒 | **80-90%** |
| 内存占用 | 50-100MB | 20-40MB | **50-70%** |
| 页面切换响应 | 50-100ms | 30-50ms | **30-50%** |
| 缓存命中率 | 60-70% | 85-95% | **25-35%** |
| 磁盘占用 | 0MB | 10-20MB | 新增但可控 |

### 用户体验提升

1. **应用启动**：从等待数秒到近乎即时显示历史数据
2. **数据刷新**：更智能的缓存失效，减少不必要的重新加载
3. **内存稳定性**：大数据集下更稳定的应用表现
4. **多会话使用**：频繁启动应用时的一致体验

## 🚧 实施风险和缓解

### 潜在风险

1. **磁盘空间占用**：缓存文件可能占用10-50MB空间
2. **数据一致性**：两级缓存可能出现不同步问题
3. **复杂度增加**：新增的磁盘IO逻辑增加系统复杂度
4. **兼容性问题**：旧版本数据格式的兼容处理

### 缓解措施

1. **空间管理**：
   - 实施磁盘空间监控和自动清理
   - 提供用户手动清理缓存的选项
   - 压缩存储减少空间占用

2. **一致性保证**：
   - 严格的缓存失效机制
   - 写入时的原子性操作
   - 定期的一致性验证

3. **复杂度控制**：
   - 充分的单元测试覆盖
   - 详细的错误日志和监控
   - 简化的降级策略

4. **兼容性处理**：
   - 版本化的缓存文件格式
   - 平滑的数据迁移机制
   - 向后兼容的数据读取

## 📅 实施时间计划

### 第1周：基础设施搭建
- [ ] 创建 `DiskCacheService` 基础框架
- [ ] 实现缓存目录管理
- [ ] 添加基础的读写操作

### 第2周：核心功能实现  
- [ ] 完善缓存文件格式设计
- [ ] 实现源文件哈希计算机制
- [ ] 添加缓存有效性验证逻辑

### 第3周：集成和重构
- [ ] 集成磁盘缓存到 `UsageService`
- [ ] 重构现有缓存查找逻辑
- [ ] 简化ViewModel缓存代码

### 第4周：优化和测试
- [ ] 性能监控和调优
- [ ] 错误处理和边界测试
- [ ] 用户体验验证

## 🧪 验证和测试计划

### 功能测试
- [ ] 冷启动性能测试
- [ ] 缓存命中率测试  
- [ ] 数据一致性验证
- [ ] 错误场景处理测试

### 压力测试
- [ ] 大数据集处理测试（1GB+ JSONL数据）
- [ ] 高频操作压力测试
- [ ] 内存限制环境测试
- [ ] 磁盘空间不足场景测试

### 回归测试
- [ ] 现有功能完整性验证
- [ ] UI交互流畅性测试
- [ ] 多用户场景测试
- [ ] 长期运行稳定性测试

## 💡 后续优化方向

### 短期优化（1-2个月）
- **智能预测**：基于用户行为预测并预热缓存
- **压缩优化**：进一步优化缓存文件大小
- **云同步**：支持多设备间的缓存同步

### 中期扩展（3-6个月）
- **增量更新**：支持增量数据更新而非全量重建
- **分布式缓存**：支持多用户环境的缓存共享
- **机器学习**：基于使用模式的智能缓存策略

### 长期愿景（6个月+）
- **实时更新**：监听文件变化实时更新缓存
- **插件化架构**：支持可插拔的缓存策略
- **性能分析**：深度的用户使用模式分析和优化

---

## 📝 总结

本改进计划通过引入磁盘持久化缓存，在保持现有快速响应优势的基础上，显著提升冷启动性能并降低内存占用。新的混合缓存架构更符合大数据量、频繁访问的使用场景需求，为用户提供更流畅的体验。

通过分阶段实施和充分测试，可以确保改进过程中的系统稳定性，最终实现显著的性能提升和用户体验改善。