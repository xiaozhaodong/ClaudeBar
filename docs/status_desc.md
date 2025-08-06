# Claudiatron 使用统计页面技术实现说明

## 1. 系统架构概览

### 1.1 整体架构
使用统计系统采用典型的 Electron 架构模式：
- **渲染进程（Frontend）**: React + TypeScript 实现的用户界面
- **主进程（Backend）**: Electron 主进程处理数据逻辑和文件系统操作
- **IPC 通信**: 通过 Electron IPC 机制实现跨进程通信
- **数据源**: 基于 JSONL 文件的使用数据（位于 `~/.claude/projects/` 目录）

### 1.2 技术栈
- **UI框架**: React 18 + TypeScript
- **组件库**: shadcn/ui + Tailwind CSS v4
- **动画**: framer-motion
- **国际化**: react-i18next
- **数据处理**: 原生 JavaScript + Node.js 文件系统 API
- **进程通信**: Electron IPC

## 2. 核心组件分析

### 2.1 UsageDashboard 组件

**文件位置**: `/src/renderer/src/components/UsageDashboard.tsx`

#### 2.1.1 组件结构
```typescript
interface UsageDashboardProps {
  onBack: () => void
}

export const UsageDashboard: React.FC<UsageDashboardProps>
```

#### 2.1.2 状态管理
组件使用 React Hooks 进行本地状态管理：

```typescript
const [loading, setLoading] = useState(true)
const [error, setError] = useState<string | null>(null)
const [stats, setStats] = useState<UsageStats | null>(null)
const [sessionStats, setSessionStats] = useState<ProjectUsage[] | null>(null)
const [selectedDateRange, setSelectedDateRange] = useState<'all' | '7d' | '30d'>('all')
const [activeTab, setActiveTab] = useState('overview')
```

#### 2.1.3 页面布局结构
1. **顶部导航栏**
   - 返回按钮
   - 页面标题和子标题
   - 日期范围过滤器（全部时间/最近30天/最近7天）

2. **数据概览卡片**（4个卡片网格布局）
   - 总成本（Total Cost）
   - 总会话数（Total Sessions）
   - 总令牌数（Total Tokens）
   - 平均每请求成本（Average Cost per Request）

3. **标签页内容区域**
   - 概览（Overview）
   - 按模型统计（By Model）
   - 按项目统计（By Project）
   - 按会话统计（By Session）
   - 时间线图表（Timeline）

## 3. 数据获取和状态管理

### 3.1 数据获取流程

```typescript
const loadUsageStats = useCallback(async (): Promise<void> => {
  try {
    setLoading(true)
    setError(null)

    let statsData: UsageStats
    let sessionData: ProjectUsage[]

    if (selectedDateRange === 'all') {
      statsData = await api.getUsageStats()
      sessionData = await api.getSessionStats(undefined, undefined, 'desc')
    } else {
      const endDate = new Date()
      const startDate = new Date()
      const days = selectedDateRange === '7d' ? 7 : 30
      startDate.setDate(startDate.getDate() - days)

      const formatDateForApi = (date: Date): string => {
        return date.toISOString().split('T')[0]
      }

      statsData = await api.getUsageStats({
        startDate: formatDateForApi(startDate),
        endDate: formatDateForApi(endDate)
      })
      sessionData = await api.getSessionStats(
        formatDateForApi(startDate),
        formatDateForApi(endDate),
        'desc'
      )
    }

    setStats(statsData)
    setSessionStats(sessionData)
  } catch (err) {
    console.error('Failed to load usage stats:', err)
    setError(t('error'))
  } finally {
    setLoading(false)
  }
}, [selectedDateRange, t])
```

### 3.2 API 接口定义

**文件位置**: `/src/renderer/src/lib/api.ts`

主要 API 方法：
```typescript
// 获取整体使用统计
async getUsageStats(params?: {
  startDate?: string
  endDate?: string
  projectPath?: string
}): Promise<UsageStats>

// 获取会话统计
async getSessionStats(
  since?: string,
  until?: string,
  order?: 'asc' | 'desc'
): Promise<ProjectUsage[]>
```

### 3.3 数据类型定义

```typescript
export interface UsageStats {
  total_cost: number
  total_tokens: number
  total_input_tokens: number
  total_output_tokens: number
  total_cache_creation_tokens: number
  total_cache_read_tokens: number
  total_sessions: number
  total_requests: number
  by_model: ModelUsage[]
  by_date: DailyUsage[]
  by_project: ProjectUsage[]
}

export interface ModelUsage {
  model: string
  total_cost: number
  total_tokens: number
  input_tokens: number
  output_tokens: number
  cache_creation_tokens: number
  cache_read_tokens: number
  session_count: number
  request_count?: number
}

export interface ProjectUsage {
  project_path: string
  project_name: string
  total_cost: number
  total_tokens: number
  session_count: number
  request_count?: number
  last_used: string
}

export interface DailyUsage {
  date: string
  total_cost: number
  total_tokens: number
  models_used: string[]
}
```

## 4. 后端数据处理逻辑

### 4.1 主要处理器

**文件位置**: `/src/main/api/usage.ts`

#### 4.1.1 IPC 处理器设置
```typescript
export function setupUsageHandlers() {
  ipcMain.handle('get-usage-stats', async (_, params?: {
    startDate?: string
    endDate?: string
    projectPath?: string
  }) => {
    // 处理获取使用统计的请求
  })

  ipcMain.handle('get-session-stats', async (_, since?: string, until?: string, order?: 'asc' | 'desc') => {
    // 处理获取会话统计的请求
  })
}
```

#### 4.1.2 数据源和解析
数据来源于 `~/.claude/projects/` 目录下的 JSONL 文件：

```typescript
async function getUsageStats(
  startDate?: string,
  endDate?: string,
  projectPath?: string
): Promise<UsageStats> {
  const claudeDir = join(homedir(), '.claude', 'projects')
  const entries: UsageEntry[] = []
  const sessionIds = new Set<string>()

  // 查找所有 JSONL 文件
  const pattern = join(claudeDir, '**', '*.jsonl')
  const files = await glob(pattern.replace(/\\/g, '/'))

  for (const file of files) {
    // 解析每个 JSONL 文件
    const content = await fs.readFile(file, 'utf-8')
    const lines = content.split('\n').filter((line) => line.trim())

    for (const line of lines) {
      try {
        const json = JSON.parse(line)
        const entry = parseUsageEntry(json, fileProjectPath)
        
        if (entry) {
          // 日期过滤
          if (startDate && entry.timestamp.split('T')[0] < startDate) continue
          if (endDate && entry.timestamp.split('T')[0] > endDate) continue
          
          entries.push(entry)
          sessionIds.add(entry.session_id)
        }
      } catch {
        // 跳过无效的 JSON 行
      }
    }
  }

  return calculateStats(entries, sessionIds)
}
```

#### 4.1.3 数据解析逻辑
```typescript
function parseUsageEntry(json: any, projectPath: string): UsageEntry | null {
  // 只处理助手消息且包含使用数据
  const messageType = json.type || json.message_type || undefined
  if (messageType !== 'assistant') return null

  const usage = json.usage || (json.message && json.message.usage)
  if (!usage) return null

  const model = json.model || (json.message && json.message.model) || 'unknown'
  
  // 跳过合成消息
  if (model === '<synthetic>') return null

  const inputTokens = usage.input_tokens || 0
  const outputTokens = usage.output_tokens || 0
  const cacheCreationTokens = usage.cache_creation_input_tokens || 0
  const cacheReadTokens = usage.cache_read_input_tokens || 0

  // 计算成本
  const cost = json.cost || json.costUSD || 
    calculateCost(model, inputTokens, outputTokens, cacheCreationTokens, cacheReadTokens)

  return {
    timestamp: json.timestamp || new Date().toISOString(),
    model,
    input_tokens: inputTokens,
    output_tokens: outputTokens,
    cache_creation_tokens: cacheCreationTokens,
    cache_read_tokens: cacheReadTokens,
    cost,
    session_id: json.session_id || json.sessionId || 'unknown',
    project_path: projectPath,
    request_id: json.requestId || json.request_id || json.message_id || undefined,
    message_type: messageType
  }
}
```

### 4.2 定价计算

```typescript
const PRICING = {
  'sonnet-4': {
    input: 3.0,
    output: 15.0,
    cache_write: 3.75,
    cache_read: 0.3
  },
  'opus-4': {
    input: 15.0,
    output: 75.0,
    cache_write: 18.75,
    cache_read: 1.5
  },
  'haiku-4': {
    input: 1.0,
    output: 5.0,
    cache_write: 1.25,
    cache_read: 0.1
  }
  // ... 其他模型定价
}

function calculateCost(
  model: string,
  inputTokens: number,
  outputTokens: number,
  cacheCreationTokens: number,
  cacheReadTokens: number
): number {
  const modelKey = model.toLowerCase().replace(/-/g, '')
  const pricing = PRICING[modelKey as keyof typeof PRICING]

  if (!pricing) {
    console.warn(`Unknown model: ${model}, setting cost to $0`)
    return 0
  }

  const inputCost = (inputTokens / 1000000) * pricing.input
  const outputCost = (outputTokens / 1000000) * pricing.output
  const cacheWriteCost = (cacheCreationTokens / 1000000) * pricing.cache_write
  const cacheReadCost = (cacheReadTokens / 1000000) * pricing.cache_read

  return inputCost + outputCost + cacheWriteCost + cacheReadCost
}
```

### 4.3 统计计算逻辑

```typescript
function calculateStats(entries: UsageEntry[], sessionIds: Set<string>): UsageStats {
  const modelStats = new Map<string, ModelUsage>()
  const dateStats = new Map<string, DailyUsage>()
  const projectStats = new Map<string, ProjectUsage>()
  const uniqueRequestIds = new Set<string>()
  const processedRequestIds = new Set<string>()

  let totalCost = 0
  let totalTokens = 0
  let totalInputTokens = 0
  let totalOutputTokens = 0
  let totalCacheCreationTokens = 0
  let totalCacheReadTokens = 0

  for (const entry of entries) {
    // 去重处理（基于 request_id）
    if (entry.request_id) {
      if (processedRequestIds.has(entry.request_id)) {
        continue // 跳过重复条目
      }
      processedRequestIds.add(entry.request_id)
      uniqueRequestIds.add(entry.request_id)
    }

    // 更新总计
    totalCost += entry.cost
    totalInputTokens += entry.input_tokens
    totalOutputTokens += entry.output_tokens
    totalCacheCreationTokens += entry.cache_creation_tokens
    totalCacheReadTokens += entry.cache_read_tokens
    totalTokens += entry.input_tokens + entry.output_tokens + 
                   entry.cache_creation_tokens + entry.cache_read_tokens

    // 按模型统计
    if (!modelStats.has(entry.model)) {
      modelStats.set(entry.model, {
        model: entry.model,
        total_cost: 0,
        total_tokens: 0,
        input_tokens: 0,
        output_tokens: 0,
        cache_creation_tokens: 0,
        cache_read_tokens: 0,
        session_count: 0,
        request_count: 0
      })
    }
    
    const modelStat = modelStats.get(entry.model)!
    modelStat.total_cost += entry.cost
    modelStat.input_tokens += entry.input_tokens
    modelStat.output_tokens += entry.output_tokens
    modelStat.cache_creation_tokens += entry.cache_creation_tokens
    modelStat.cache_read_tokens += entry.cache_read_tokens
    modelStat.total_tokens += entry.input_tokens + entry.output_tokens + 
                              entry.cache_creation_tokens + entry.cache_read_tokens

    // 按日期统计
    const date = entry.timestamp.split('T')[0]
    if (!dateStats.has(date)) {
      dateStats.set(date, {
        date,
        total_cost: 0,
        total_tokens: 0,
        models_used: []
      })
    }
    
    const dateStat = dateStats.get(date)!
    dateStat.total_cost += entry.cost
    dateStat.total_tokens += entry.input_tokens + entry.output_tokens + 
                             entry.cache_creation_tokens + entry.cache_read_tokens
    if (!dateStat.models_used.includes(entry.model)) {
      dateStat.models_used.push(entry.model)
    }

    // 按项目统计
    if (!projectStats.has(entry.project_path)) {
      projectStats.set(entry.project_path, {
        project_path: entry.project_path,
        project_name: getProjectName(entry.project_path),
        total_cost: 0,
        total_tokens: 0,
        session_count: 0,
        request_count: 0,
        last_used: entry.timestamp
      })
    }
    
    const projectStat = projectStats.get(entry.project_path)!
    projectStat.total_cost += entry.cost
    projectStat.total_tokens += entry.input_tokens + entry.output_tokens + 
                                entry.cache_creation_tokens + entry.cache_read_tokens
    if (entry.timestamp > projectStat.last_used) {
      projectStat.last_used = entry.timestamp
    }
  }

  // 计算API请求计数
  const totalRequests = uniqueRequestIds.size > 0 ? uniqueRequestIds.size : entries.length

  return {
    total_cost: totalCost,
    total_tokens: totalTokens,
    total_input_tokens: totalInputTokens,
    total_output_tokens: totalOutputTokens,
    total_cache_creation_tokens: totalCacheCreationTokens,
    total_cache_read_tokens: totalCacheReadTokens,
    total_sessions: sessionIds.size,
    total_requests: totalRequests,
    by_model: Array.from(modelStats.values()).sort((a, b) => b.total_cost - a.total_cost),
    by_date: Array.from(dateStats.values()).sort((a, b) => a.date.localeCompare(b.date)),
    by_project: Array.from(projectStats.values()).sort((a, b) => b.total_cost - a.total_cost)
  }
}
```

## 5. 多维度数据展示功能

### 5.1 概览标签页（Overview Tab）
展示内容：
- **Token 详情**: 输入、输出、缓存写入、缓存读取令牌统计
- **最常用模型**: 前3个按成本排序的模型
- **热门项目**: 前3个按成本排序的项目

### 5.2 按模型统计（Models Tab）
展示内容：
- 每个模型的详细使用情况
- 包含成本、令牌数、会话数、请求数
- 支持模型名称友好显示和颜色编码

```typescript
const getModelDisplayName = (model: string): string => {
  const modelMap: Record<string, string> = {
    'claude-4-opus': 'Opus 4',
    'claude-4-sonnet': 'Sonnet 4',
    'claude-3.5-sonnet': 'Sonnet 3.5',
    'claude-3-opus': 'Opus 3'
  }
  return modelMap[model] || model
}

const getModelColor = (model: string): string => {
  if (model.includes('opus')) return 'text-purple-500'
  if (model.includes('sonnet')) return 'text-blue-500'
  return 'text-gray-500'
}
```

### 5.3 按项目统计（Projects Tab）
展示内容：
- 项目路径和名称
- 会话数、请求数、令牌数
- 总成本和平均每会话成本
- 路径格式化显示（支持跨平台）

### 5.4 按会话统计（Sessions Tab）
展示内容：
- 会话级别的使用统计
- 项目归属和最后使用时间
- 支持空数据状态显示

### 5.5 时间线图表（Timeline Tab）
特点：
- 自定义纯 CSS/HTML 实现的柱状图
- 响应式设计和悬停交互
- 工具提示显示详细信息
- 支持数据为空的状态处理

```typescript
// 时间线图表实现
const maxCost = Math.max(...stats.by_date.map((d) => d.total_cost), 0)
const halfMaxCost = maxCost / 2

return (
  <div className="relative pl-8 pr-4">
    {/* Y轴标签 */}
    <div className="absolute left-0 top-0 bottom-8 flex flex-col justify-between text-xs text-muted-foreground">
      <span>{formatCurrency(maxCost)}</span>
      <span>{formatCurrency(halfMaxCost)}</span>
      <span>{formatCurrency(0)}</span>
    </div>

    {/* 图表容器 */}
    <div className="flex items-end space-x-2 h-64 border-l border-b border-border pl-4">
      {stats.by_date.slice().reverse().map((day) => {
        const heightPercent = maxCost > 0 ? (day.total_cost / maxCost) * 100 : 0
        
        return (
          <div key={day.date} className="flex-1 h-full flex flex-col items-center justify-end group relative">
            {/* 工具提示 */}
            <div className="absolute bottom-full mb-2 left-1/2 transform -translate-x-1/2 opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none z-10">
              <div className="bg-background border border-border rounded-lg shadow-lg p-3 whitespace-nowrap">
                <p className="text-sm font-semibold">{formattedDate}</p>
                <p className="text-sm text-muted-foreground mt-1">
                  成本: {formatCurrency(day.total_cost)}
                </p>
                <p className="text-xs text-muted-foreground">
                  {formatTokens(day.total_tokens)} 令牌
                </p>
                <p className="text-xs text-muted-foreground">
                  {day.models_used.length} 个模型
                </p>
              </div>
            </div>

            {/* 柱状图条 */}
            <div
              className="w-full bg-[#d97757] hover:opacity-80 transition-opacity rounded-t cursor-pointer"
              style={{ height: `${heightPercent}%` }}
            />

            {/* X轴标签 */}
            <div className="absolute left-1/2 top-full mt-1 -translate-x-1/2 text-xs text-muted-foreground -rotate-45 origin-top-left whitespace-nowrap pointer-events-none">
              {date.toLocaleDateString('zh-CN', { month: 'short', day: 'numeric' })}
            </div>
          </div>
        )
      })}
    </div>
  </div>
)
```

## 6. 用户交互功能

### 6.1 日期范围过滤
支持三种时间范围：
- 全部时间（All Time）
- 最近30天（Last 30 Days）
- 最近7天（Last 7 Days）

实现逻辑：
```typescript
const [selectedDateRange, setSelectedDateRange] = useState<'all' | '7d' | '30d'>('all')

// 日期范围过滤逻辑
if (selectedDateRange === 'all') {
  statsData = await api.getUsageStats()
  sessionData = await api.getSessionStats(undefined, undefined, 'desc')
} else {
  const endDate = new Date()
  const startDate = new Date()
  const days = selectedDateRange === '7d' ? 7 : 30
  startDate.setDate(startDate.getDate() - days)

  const formatDateForApi = (date: Date): string => {
    return date.toISOString().split('T')[0]
  }

  statsData = await api.getUsageStats({
    startDate: formatDateForApi(startDate),
    endDate: formatDateForApi(endDate)
  })
  sessionData = await api.getSessionStats(
    formatDateForApi(startDate),
    formatDateForApi(endDate),
    'desc'
  )
}
```

### 6.2 标签页切换
使用 shadcn/ui 的 Tabs 组件实现：
```typescript
const [activeTab, setActiveTab] = useState('overview')

<Tabs value={activeTab} onValueChange={setActiveTab}>
  <TabsList className="grid w-full grid-cols-5">
    <TabsTrigger value="overview">概览</TabsTrigger>
    <TabsTrigger value="models">按模型</TabsTrigger>
    <TabsTrigger value="projects">按项目</TabsTrigger>
    <TabsTrigger value="sessions">按会话</TabsTrigger>
    <TabsTrigger value="timeline">时间线</TabsTrigger>
  </TabsList>
  
  <TabsContent value="overview">...</TabsContent>
  <TabsContent value="models">...</TabsContent>
  <TabsContent value="projects">...</TabsContent>
  <TabsContent value="sessions">...</TabsContent>
  <TabsContent value="timeline">...</TabsContent>
</Tabs>
```

### 6.3 响应式交互
- **卡片悬停效果**: 使用 `shimmer-hover` 类实现微妙的动画
- **时间线图表交互**: 悬停显示详细工具提示
- **加载状态**: 旋转加载指示器
- **错误处理**: 友好的错误提示和重试按钮

## 7. 数据计算和格式化

### 7.1 货币格式化
```typescript
const formatCurrency = (amount: number): string => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 2,
    maximumFractionDigits: 4
  }).format(amount)
}
```

### 7.2 数字格式化
```typescript
const formatNumber = (num: number): string => {
  return new Intl.NumberFormat('en-US').format(num)
}
```

### 7.3 令牌数格式化
```typescript
const formatTokens = (num: number): string => {
  if (num >= 1_000_000) {
    return `${(num / 1_000_000).toFixed(2)}M`
  } else if (num >= 1_000) {
    return `${(num / 1_000).toFixed(1)}K`
  }
  return formatNumber(num)
}
```

### 7.4 项目路径格式化
```typescript
// /src/renderer/src/lib/utils.ts
export function formatProjectPath(path: string): string {
  if (!path) return ''

  // 家目录模式匹配
  const homePatterns = [
    /^\/Users\/[^/]+/, // macOS
    /^\/home\/[^/]+/, // Linux
    /^C:\\Users\\[^\\]+/i, // Windows
    /^\/root/ // Root user
  ]

  // 将家目录替换为 ~
  let formattedPath = path
  for (const pattern of homePatterns) {
    if (pattern.test(path)) {
      formattedPath = path.replace(pattern, '~')
      break
    }
  }

  // 分割路径
  const parts = formattedPath.split(/[/\\]/)

  // 如果路径足够短，直接返回
  if (parts.length <= 4) {
    return formattedPath
  }

  // 对于长路径，显示首部、省略号和末尾2-3部分
  const firstPart = parts[0]
  const lastParts = parts.slice(-3)

  return `${firstPart}/.../${lastParts.join('/')}`
}

export function getProjectName(path: string): string {
  if (!path) return ''

  const parts = path.split(/[/\\]/)
  return parts[parts.length - 1] || path
}
```

## 8. 国际化支持

### 8.1 i18next 配置
**文件位置**: `/src/renderer/src/i18n/config.ts`

```typescript
// 翻译资源
const resources = {
  en: {
    usageDashboard: enUsageDashboard,
    // ... 其他命名空间
  },
  zh: {
    usageDashboard: zhUsageDashboard,
    // ... 其他命名空间
  }
}

// i18next 初始化
i18n
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    resources,
    fallbackLng: 'en',
    defaultNS: 'common',
    ns: ['common', 'ui', 'settings', 'errors', 'nfo', 'usageDashboard', /* ... */],
    
    detection: {
      order: ['localStorage', 'navigator', 'htmlTag'],
      caches: ['localStorage'],
      lookupLocalStorage: 'claudiatron-language'
    },
    
    interpolation: {
      escapeValue: false // React 已转义值
    },
    
    react: {
      useSuspense: false
    }
  })
```

### 8.2 翻译文件结构
支持英文和中文两种语言，每种语言都有完整的翻译文件：

**English** (`/src/renderer/src/i18n/resources/en/usageDashboard.json`):
```json
{
  "title": "Usage Dashboard",
  "subtitle": "Track your Claude Code usage and costs",
  "dateRange": {
    "allTime": "All Time",
    "last30Days": "Last 30 Days",
    "last7Days": "Last 7 Days"
  },
  "summary": {
    "totalCost": "Total Cost",
    "totalSessions": "Total Sessions",
    "totalTokens": "Total Tokens",
    "avgCostPerRequest": "Avg Cost/Request"
  }
}
```

**中文** (`/src/renderer/src/i18n/resources/zh/usageDashboard.json`):
```json
{
  "title": "使用统计",
  "subtitle": "跟踪您的 Claude Code 使用情况和成本",
  "dateRange": {
    "allTime": "所有时间",
    "last30Days": "最近30天",
    "last7Days": "最近7天"
  },
  "summary": {
    "totalCost": "总花费",
    "totalSessions": "总会话数",
    "totalTokens": "总令牌数",
    "avgCostPerRequest": "平均每次请求成本"
  }
}
```

### 8.3 组件中的使用
```typescript
import { useTranslation } from 'react-i18next'

export const UsageDashboard: React.FC<UsageDashboardProps> = ({ onBack }) => {
  const { t } = useTranslation('usageDashboard')
  
  return (
    <div>
      <h1 className="text-lg font-semibold">{t('title')}</h1>
      <p className="text-xs text-muted-foreground">{t('subtitle')}</p>
      {/* ... 其他使用 t() 函数的组件 */}
    </div>
  )
}
```

## 9. 性能优化策略

### 9.1 组件层面优化

#### 9.1.1 React.useCallback 优化
```typescript
const loadUsageStats = useCallback(async (): Promise<void> => {
  // ... 数据加载逻辑
}, [selectedDateRange, t])  // 只在依赖变化时重新创建函数
```

#### 9.1.2 状态更新优化
- 使用合适的状态结构避免不必要的重渲染
- 错误边界处理防止组件崩溃
- 加载状态管理提供良好的用户体验

### 9.2 数据处理优化

#### 9.2.1 文件读取优化
- 使用 glob 模式高效匹配 JSONL 文件
- 逐行解析避免大文件内存问题
- 错误处理确保单个文件错误不影响整体处理

#### 9.2.2 数据计算优化
- 使用 Map 数据结构提高查找效率
- 一次遍历完成多维度统计计算
- 请求去重避免重复计算

#### 9.2.3 内存管理
```typescript
// 使用 Set 进行高效的去重操作
const uniqueRequestIds = new Set<string>()
const processedRequestIds = new Set<string>()

// 使用 Map 进行高效的分组统计
const modelStats = new Map<string, ModelUsage>()
const dateStats = new Map<string, DailyUsage>()
const projectStats = new Map<string, ProjectUsage>()
```

### 9.3 UI 渲染优化

#### 9.3.1 动画优化
```typescript
// 使用 framer-motion 实现流畅动画
<motion.div
  initial={{ opacity: 0, y: -20 }}
  animate={{ opacity: 1, y: 0 }}
  transition={{ duration: 0.3 }}
>
  {/* 内容 */}
</motion.div>
```

#### 9.3.2 条件渲染优化
```typescript
// 避免不必要的组件渲染
{loading ? (
  <LoadingSpinner />  
) : error ? (
  <ErrorMessage />
) : stats ? (
  <StatsContent />
) : null}
```

#### 9.3.3 列表渲染优化
```typescript
// 为列表项提供稳定的 key
{stats.by_model.map((model) => (
  <div key={model.model} className="space-y-2">
    {/* 模型统计内容 */}
  </div>
))}
```

## 10. 错误处理和边界情况

### 10.1 数据层错误处理
```typescript
// API 调用错误处理
try {
  statsData = await api.getUsageStats(params)
} catch (err) {
  console.error('Failed to load usage stats:', err)
  setError(t('error'))
  return createEmptyStats()  // 返回空数据结构
}

// JSONL 解析错误处理
for (const line of lines) {
  try {
    const json = JSON.parse(line)
    const entry = parseUsageEntry(json, fileProjectPath)
    if (entry) {
      entries.push(entry)
    }
  } catch {
    // 跳过无效的 JSON 行，不中断整个处理流程
  }
}
```

### 10.2 UI 层错误处理
```typescript
// 加载状态
{loading ? (
  <div className="flex items-center justify-center h-full">
    <div className="text-center">
      <Loader2 className="h-8 w-8 animate-spin text-muted-foreground mx-auto mb-4" />
      <p className="text-sm text-muted-foreground">加载中...</p>
    </div>
  </div>
) : error ? (
  // 错误状态
  <div className="flex items-center justify-center h-full">
    <div className="text-center max-w-md">
      <p className="text-sm text-destructive mb-4">{error}</p>
      <Button onClick={loadUsageStats} size="sm">
        重试
      </Button>
    </div>
  </div>
) : stats ? (
  // 正常数据显示
  <StatsDisplay />
) : null}
```

### 10.3 空数据处理
```typescript
// 会话数据为空的处理
{!sessionStats || sessionStats.length === 0 ? (
  <div className="text-center py-8 text-muted-foreground">
    <p>暂无会话数据</p>
  </div>
) : (
  <SessionsList />
)}

// 图表数据为空的处理
{stats.by_date.length > 0 ? (
  <TimelineChart />
) : (
  <div className="text-center py-8 text-sm text-muted-foreground">
    暂无使用数据
  </div>
)}
```

## 11. 数据流架构图

```
用户界面 UsageDashboard
         ↓
API 调用层 api.ts
         ↓
IPC 通信 preload/index.ts
         ↓
主进程处理器 usage.ts
         ↓
文件系统扫描 ~/.claude/projects
         ↓
JSONL 文件解析
         ↓
数据聚合和计算
         ↓
统计结果返回
         ↓
UI 数据展示

日期过滤器 → API 调用层
标签页切换 → 用户界面
国际化系统 → 用户界面
错误处理 → 用户界面
加载状态 → 用户界面
空数据处理 → 用户界面
```

## 12. 关键数据指标说明

### 12.1 核心指标定义

**总花费（美元）**：
- 计算公式：输入成本 + 输出成本 + 缓存写入成本 + 缓存读取成本
- 输入成本 = (输入令牌数 / 1,000,000) × 模型输入单价
- 输出成本 = (输出令牌数 / 1,000,000) × 模型输出单价
- 缓存写入成本 = (缓存写入令牌数 / 1,000,000) × 模型缓存写入单价
- 缓存读取成本 = (缓存读取令牌数 / 1,000,000) × 模型缓存读取单价

**总会话数**：
- 通过唯一的 `session_id` 计数获得
- 来源：JSONL 文件中的会话标识符

**总令牌数**：
- 计算方式：输入令牌 + 输出令牌 + 缓存创建令牌 + 缓存读取令牌
- 所有类型令牌的总和

**平均每次请求成本**：
- 计算公式：总成本 / 总请求数
- 用于评估单次 API 调用的平均成本

### 12.2 令牌详细分类

**输入令牌（Input Tokens）**：
- 用户发送给 Claude 的文本内容转换的令牌数
- 包括提示词、上下文等

**输出令牌（Output Tokens）**：
- Claude 响应生成的文本内容转换的令牌数
- 通常成本是输入令牌的 5 倍

**缓存写入令牌（Cache Creation Tokens）**：
- 首次处理长上下文时写入缓存的令牌数
- 成本通常是输入令牌的 1.25 倍

**缓存读取令牌（Cache Read Tokens）**：
- 从缓存中读取的令牌数
- 成本最低，通常是输入令牌的 0.1-0.3 倍

### 12.3 定价模型（每百万令牌美元计价）

| 模型 | 输入 | 输出 | 缓存写入 | 缓存读取 |
|------|------|------|----------|----------|
| Claude 4 Opus | $15 | $75 | $18.75 | $1.5 |
| Claude 4 Sonnet | $3 | $15 | $3.75 | $0.3 |
| Claude 4 Haiku | $1 | $5 | $1.25 | $0.1 |

## 13. 关键实现细节总结

### 13.1 架构设计亮点
1. **清晰的分层架构**: UI层、API层、IPC层、数据处理层分离明确
2. **类型安全**: 完整的 TypeScript 类型定义覆盖整个数据流
3. **错误恢复**: 多层次的错误处理和用户友好的反馈
4. **性能优化**: 合理的数据结构选择和计算优化

### 13.2 数据处理特色
1. **多数据源聚合**: 扫描整个 `.claude/projects` 目录的所有 JSONL 文件
2. **智能去重**: 基于 `request_id` 的请求去重机制
3. **灵活过滤**: 支持日期范围和项目路径过滤
4. **多维度统计**: 同时按模型、项目、日期、会话等维度进行统计

### 13.3 用户体验优化
1. **响应式设计**: 支持不同屏幕尺寸的适配
2. **交互反馈**: 悬停效果、工具提示、动画过渡
3. **国际化支持**: 完整的中英文翻译
4. **友好的数据展示**: 货币格式、数字缩写、路径简化等

### 13.4 维护性考虑
1. **模块化设计**: 功能拆分清晰，便于维护和扩展
2. **配置化**: 定价模型、UI 文本等均可配置
3. **测试友好**: 纯函数设计便于单元测试
4. **文档完善**: 详细的注释和类型定义

这个使用统计系统展示了现代 Electron 应用在数据处理、用户界面和性能优化方面的最佳实践，为类似项目提供了优秀的参考实现。