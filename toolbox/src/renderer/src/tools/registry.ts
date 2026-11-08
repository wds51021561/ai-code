import { Send, type LucideIcon } from 'lucide-react'
import { lazy, type ComponentType, type LazyExoticComponent } from 'react'

export interface ToolDefinition {
  id: string
  title: string
  description: string
  icon: LucideIcon
  component: LazyExoticComponent<ComponentType>
}

/**
 * Add a new tool by creating a folder under `tools/` and registering it here.
 * The top navigation tabs are generated from this list.
 */
export const TOOLS: ToolDefinition[] = [
  {
    id: 'api-client',
    title: '接口请求',
    description: 'HTTP API 调试、环境变量与请求扩展',
    icon: Send,
    component: lazy(() => import('./api-client'))
  }
]
