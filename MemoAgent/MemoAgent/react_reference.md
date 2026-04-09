```App.tsx
import React, { useCallback, useState, useRef } from 'react'
import '@xyflow/react/dist/style.css'
import { Node } from '@xyflow/react'
import { GlobalNav } from './components/GlobalNav'
import { LeftSidebar } from './components/LeftSidebar'
import { KnowledgeGraph } from './components/KnowledgeGraph'
import { FloatingActions } from './components/FloatingActions'
import { SmartInputModal } from './components/SmartInputModal'
import { DetailDrawer } from './components/DetailDrawer'
import { NodeData } from './data/sampleNodes'
export function App() {
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [isSidebarOpen, setIsSidebarOpen] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')
  const [selectedNodes, setSelectedNodes] = useState<Node<NodeData>[]>([])
  const graphRef = useRef<{
    connectNodes: (nodeIds: string[]) => void
    disconnectNodes: (nodeIds: string[]) => void
  } | null>(null)
  const handleSelectionChange = useCallback((nodes: Node<NodeData>[]) => {
    setSelectedNodes(nodes)
  }, [])
  const handleDeselectNode = useCallback((nodeId: string) => {
    setSelectedNodes((prev) => prev.filter((n) => n.id !== nodeId))
  }, [])
  const handleConnectEdges = useCallback(() => {
    if (selectedNodes.length < 2) return
    graphRef.current?.connectNodes(selectedNodes.map((n) => n.id))
  }, [selectedNodes])
  const handleDisconnectEdges = useCallback(() => {
    if (selectedNodes.length < 2) return
    graphRef.current?.disconnectNodes(selectedNodes.map((n) => n.id))
  }, [selectedNodes])
  const handleExtractPrompt = () => {
    // Drawer opens automatically on multi-select
  }
  return (
    <div className="w-screen h-screen bg-surface-primary overflow-hidden flex flex-col font-sans text-txt-primary transition-colors duration-200">
      <GlobalNav
        onAddDataClick={() => setIsModalOpen(true)}
        searchQuery={searchQuery}
        setSearchQuery={setSearchQuery}
      />

      <div className="flex-1 relative mt-16">
        <LeftSidebar isOpen={isSidebarOpen} setIsOpen={setIsSidebarOpen} />

        <main className="absolute inset-0 z-10">
          <KnowledgeGraph
            ref={graphRef}
            searchQuery={searchQuery}
            onSelectionChange={handleSelectionChange}
          />
        </main>

        <FloatingActions
          selectedCount={selectedNodes.length}
          onConnect={handleConnectEdges}
          onDisconnect={handleDisconnectEdges}
          onExtractPrompt={handleExtractPrompt}
        />

        <DetailDrawer
          selectedNodes={selectedNodes}
          onClose={() => setSelectedNodes([])}
          onDeselectNode={handleDeselectNode}
        />
      </div>

      <SmartInputModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
      />
    </div>
  )
}

```
```components/CustomNode.tsx
import React, { useState, memo } from 'react'
import '@xyflow/react/dist/style.css'
import { Handle, Position, NodeProps } from '@xyflow/react'
import { motion, AnimatePresence } from 'framer-motion'
import {
  FileText,
  File,
  BookOpen,
  MessageSquare,
  Sparkles,
  Hash,
} from 'lucide-react'
import { NodeData } from '../data/sampleNodes'
const typeConfig = {
  memo: {
    color: 'border-cyan-500/30 dark:border-cyan-500/50',
    bg: 'bg-cyan-50 dark:bg-cyan-500/10',
    text: 'text-cyan-600 dark:text-cyan-400',
    icon: FileText,
    glow: 'shadow-cyan-500/20',
    tagBg: 'bg-cyan-100 dark:bg-cyan-950/80',
    tagText: 'text-cyan-700 dark:text-cyan-300',
    tagBorder: 'border-cyan-200 dark:border-cyan-500/20',
  },
  pdf: {
    color: 'border-rose-500/30 dark:border-rose-500/50',
    bg: 'bg-rose-50 dark:bg-rose-500/10',
    text: 'text-rose-600 dark:text-rose-400',
    icon: File,
    glow: 'shadow-rose-500/20',
    tagBg: 'bg-rose-100 dark:bg-rose-950/80',
    tagText: 'text-rose-700 dark:text-rose-300',
    tagBorder: 'border-rose-200 dark:border-rose-500/20',
  },
  diary: {
    color: 'border-amber-500/30 dark:border-amber-500/50',
    bg: 'bg-amber-50 dark:bg-amber-500/10',
    text: 'text-amber-600 dark:text-amber-400',
    icon: BookOpen,
    glow: 'shadow-amber-500/20',
    tagBg: 'bg-amber-100 dark:bg-amber-950/80',
    tagText: 'text-amber-700 dark:text-amber-300',
    tagBorder: 'border-amber-200 dark:border-amber-500/20',
  },
  chat: {
    color: 'border-violet-500/30 dark:border-violet-500/50',
    bg: 'bg-violet-50 dark:bg-violet-500/10',
    text: 'text-violet-600 dark:text-violet-400',
    icon: MessageSquare,
    glow: 'shadow-violet-500/20',
    tagBg: 'bg-violet-100 dark:bg-violet-950/80',
    tagText: 'text-violet-700 dark:text-violet-300',
    tagBorder: 'border-violet-200 dark:border-violet-500/20',
  },
}
export const CustomNode = memo(({ data, selected }: NodeProps<NodeData>) => {
  const [isHovered, setIsHovered] = useState(false)
  const config = typeConfig[data.type] || typeConfig.memo
  const tags = data.tags || []
  const Icon = config.icon
  return (
    <div
      className="relative"
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      <Handle
        type="target"
        position={Position.Top}
        className="w-3 h-3 !bg-surface-tertiary !border-2 !border-border hover:!bg-cyan-500 transition-colors"
      />

      <motion.div
        whileHover={{
          scale: 1.02,
        }}
        className={`
          relative px-4 py-3 rounded-xl border backdrop-blur-sm transition-all duration-200 bg-surface-secondary
          ${config.color}
          ${selected ? `ring-2 ring-offset-2 ring-offset-surface-primary ring-cyan-500 shadow-lg ${config.glow}` : 'shadow-md'}
          ${data.isImportant ? 'w-64' : 'w-56'}
        `}
      >
        {/* Background tint overlay */}
        <div
          className={`absolute inset-0 rounded-xl opacity-50 ${config.bg} pointer-events-none`}
        />

        {data.isImportant && (
          <div className="absolute -top-2 -right-2 bg-surface-elevated border border-border rounded-full p-1 shadow-lg z-10">
            <Sparkles className="w-3 h-3 text-amber-500" />
          </div>
        )}

        <div className="relative z-10 flex items-start gap-3">
          <div
            className={`mt-0.5 p-1.5 rounded-lg bg-surface-tertiary/50 ${config.text}`}
          >
            <Icon className="w-4 h-4" />
          </div>
          <div className="flex-1 min-w-0">
            <h3 className="text-sm font-semibold text-txt-primary leading-tight mb-1 line-clamp-2">
              {data.title}
            </h3>
            <p className="text-xs text-txt-tertiary line-clamp-2 leading-relaxed">
              {data.summary}
            </p>
          </div>
        </div>

        {/* Tags */}
        {tags.length > 0 && (
          <div className="relative z-10 flex flex-wrap gap-1 mt-2.5 pt-2.5 border-t border-border-subtle">
            {tags.slice(0, 3).map((tag) => (
              <span
                key={tag}
                className={`inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded text-[10px] font-medium border ${config.tagBg} ${config.tagText} ${config.tagBorder}`}
              >
                <Hash className="w-2.5 h-2.5 opacity-60" />
                {tag}
              </span>
            ))}
            {tags.length > 3 && (
              <span className="text-[10px] text-txt-muted px-1 py-0.5">
                +{tags.length - 3}
              </span>
            )}
          </div>
        )}
      </motion.div>

      <Handle
        type="source"
        position={Position.Bottom}
        className="w-3 h-3 !bg-surface-tertiary !border-2 !border-border hover:!bg-cyan-500 transition-colors"
      />

      {/* Tooltip */}
      <AnimatePresence>
        {isHovered && !selected && (
          <motion.div
            initial={{
              opacity: 0,
              y: 10,
              scale: 0.95,
            }}
            animate={{
              opacity: 1,
              y: 0,
              scale: 1,
            }}
            exit={{
              opacity: 0,
              y: 10,
              scale: 0.95,
            }}
            transition={{
              duration: 0.15,
            }}
            className="absolute z-50 top-full left-1/2 -translate-x-1/2 mt-4 w-72 p-4 bg-surface-elevated border border-border rounded-xl shadow-2xl pointer-events-none"
          >
            <div className="flex items-center gap-2 mb-2">
              <span
                className={`text-xs font-medium px-2 py-0.5 rounded-full ${config.bg} ${config.text}`}
              >
                {data.type.toUpperCase()}
              </span>
              <span className="text-xs text-txt-muted">{data.date}</span>
            </div>
            <h4 className="text-sm font-bold text-txt-primary mb-2">
              {data.title}
            </h4>
            <p className="text-xs text-txt-secondary leading-relaxed mb-3">
              {data.summary}
            </p>
            {tags.length > 0 && (
              <div className="flex flex-wrap gap-1 pt-2 border-t border-border-subtle">
                {tags.map((tag) => (
                  <span
                    key={tag}
                    className={`inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded text-[10px] font-medium ${config.tagBg} ${config.tagText}`}
                  >
                    <Hash className="w-2.5 h-2.5 opacity-60" />
                    {tag}
                  </span>
                ))}
              </div>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
})

```
```components/DeletableEdge.tsx
import React, { useState } from 'react'
import '@xyflow/react/dist/style.css'
import {
  BaseEdge,
  EdgeLabelRenderer,
  getBezierPath,
  EdgeProps,
} from '@xyflow/react'
import { X } from 'lucide-react'
interface DeletableEdgeProps extends EdgeProps {
  data?: {
    onDelete?: (id: string) => void
  }
}
export function DeletableEdge({
  id,
  sourceX,
  sourceY,
  targetX,
  targetY,
  sourcePosition,
  targetPosition,
  style = {},
  markerEnd,
  selected,
  data,
}: DeletableEdgeProps) {
  const [isHovered, setIsHovered] = useState(false)
  const [edgePath, labelX, labelY] = getBezierPath({
    sourceX,
    sourceY,
    sourcePosition,
    targetX,
    targetY,
    targetPosition,
  })
  const isUserCreated = style?.strokeDasharray === '5,5'
  return (
    <>
      {/* Invisible wider path for easier hover/click */}
      <path
        d={edgePath}
        fill="none"
        stroke="transparent"
        strokeWidth={20}
        onMouseEnter={() => setIsHovered(true)}
        onMouseLeave={() => setIsHovered(false)}
        style={{
          cursor: 'pointer',
        }}
      />
      <BaseEdge
        path={edgePath}
        markerEnd={markerEnd}
        style={{
          ...style,
          stroke: selected
            ? 'var(--color-edge-selected)'
            : isHovered
              ? 'var(--color-edge-hover)'
              : 'var(--color-edge-default)',
          strokeWidth: selected
            ? 3
            : isHovered
              ? Number(style?.strokeWidth || 2) + 1
              : Number(style?.strokeWidth || 2),
          transition: 'stroke 0.2s, stroke-width 0.2s',
        }}
      />
      {(isHovered || selected) && (
        <EdgeLabelRenderer>
          <div
            style={{
              position: 'absolute',
              transform: `translate(-50%, -50%) translate(${labelX}px,${labelY}px)`,
              pointerEvents: 'all',
            }}
            className="nodrag nopan"
            onMouseEnter={() => setIsHovered(true)}
            onMouseLeave={() => setIsHovered(false)}
          >
            <button
              onClick={(e) => {
                e.stopPropagation()
                data?.onDelete?.(id)
              }}
              className="flex items-center gap-1 px-2 py-1 bg-surface-elevated border border-border rounded-lg text-txt-secondary hover:bg-rose-500 hover:border-rose-500 hover:text-white transition-all shadow-lg text-[10px] font-medium"
            >
              <X className="w-3 h-3" />
              삭제
            </button>
            {isUserCreated && (
              <div className="absolute -top-5 left-1/2 -translate-x-1/2 whitespace-nowrap text-[9px] text-txt-muted bg-surface-secondary px-1.5 py-0.5 rounded border border-border">
                수동 연결
              </div>
            )}
          </div>
        </EdgeLabelRenderer>
      )}
    </>
  )
}

```
```components/DetailDrawer.tsx
import React, { useState } from 'react'
import '@xyflow/react/dist/style.css'
import { motion, AnimatePresence } from 'framer-motion'
import {
  X,
  Calendar,
  ChevronDown,
  ChevronUp,
  ExternalLink,
  Sparkles,
  Copy,
  Check,
  FileText,
} from 'lucide-react'
import { Node } from '@xyflow/react'
import { NodeData } from '../data/sampleNodes'
interface DetailDrawerProps {
  selectedNodes: Node<NodeData>[]
  onClose: () => void
  onDeselectNode: (nodeId: string) => void
}
export function DetailDrawer({
  selectedNodes,
  onClose,
  onDeselectNode,
}: DetailDrawerProps) {
  const [isOriginalOpen, setIsOriginalOpen] = useState(false)
  const [promptIntent, setPromptIntent] = useState('')
  const [generatedPrompt, setGeneratedPrompt] = useState('')
  const [isCopied, setIsCopied] = useState(false)
  const isOpen = selectedNodes.length > 0
  const isMulti = selectedNodes.length > 1
  const handleGeneratePrompt = () => {
    const context = selectedNodes
      .map((n) => `- ${n.data.title}: ${n.data.summary}`)
      .join('\n')
    const prompt = `다음 정보를 바탕으로 ${promptIntent || '요약'}해줘.\n\n[컨텍스트]\n${context}\n\n[요청사항]\n${promptIntent || '위 내용을 종합하여 핵심 인사이트를 도출해줘.'}`
    setGeneratedPrompt(prompt)
  }
  const handleCopy = () => {
    navigator.clipboard.writeText(generatedPrompt)
    setIsCopied(true)
    setTimeout(() => setIsCopied(false), 2000)
  }
  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          initial={{
            x: '100%',
            opacity: 0,
          }}
          animate={{
            x: 0,
            opacity: 1,
          }}
          exit={{
            x: '100%',
            opacity: 0,
          }}
          transition={{
            type: 'spring',
            stiffness: 300,
            damping: 30,
          }}
          className="fixed top-16 right-0 bottom-0 w-[400px] bg-surface-secondary border-l border-border z-30 shadow-2xl flex flex-col transition-colors duration-200"
        >
          {/* Header */}
          <div className="flex items-center justify-between p-4 border-b border-border">
            <h2 className="text-sm font-semibold text-txt-primary">
              {isMulti ? '프롬프트 작성 (Prompt Composer)' : '노드 상세 정보'}
            </h2>
            <button
              onClick={onClose}
              className="p-1.5 text-txt-tertiary hover:text-txt-primary hover:bg-surface-tertiary rounded-md transition-colors"
            >
              <X className="w-4 h-4" />
            </button>
          </div>

          {/* Content */}
          <div className="flex-1 overflow-y-auto p-5">
            {!isMulti ? (
              // Single Node View
              <div className="space-y-6">
                <div>
                  <div className="flex items-center gap-2 mb-3">
                    <span className="px-2 py-1 text-xs font-medium rounded bg-cyan-500/10 text-cyan-600 dark:text-cyan-400 border border-cyan-500/20 uppercase">
                      {selectedNodes[0].data.type}
                    </span>
                    <div className="flex items-center gap-1 text-xs text-txt-muted">
                      <Calendar className="w-3 h-3" />
                      {selectedNodes[0].data.date}
                    </div>
                  </div>
                  <h3 className="text-xl font-bold text-txt-primary leading-snug mb-4">
                    {selectedNodes[0].data.title}
                  </h3>

                  <div className="space-y-2">
                    <label className="text-xs font-medium text-txt-tertiary flex items-center gap-1">
                      <Sparkles className="w-3 h-3 text-violet-500 dark:text-violet-400" />
                      AI 요약 (수정 가능)
                    </label>
                    <textarea
                      className="w-full h-32 p-3 bg-surface-input border border-border rounded-xl text-sm text-txt-secondary leading-relaxed focus:outline-none focus:border-cyan-500/50 focus:ring-1 focus:ring-cyan-500/50 resize-none"
                      defaultValue={selectedNodes[0].data.summary}
                    />
                  </div>
                </div>

                <div className="border border-border rounded-xl overflow-hidden bg-surface-elevated">
                  <button
                    onClick={() => setIsOriginalOpen(!isOriginalOpen)}
                    className="w-full flex items-center justify-between p-3 bg-surface-tertiary/50 hover:bg-surface-tertiary transition-colors"
                  >
                    <div className="flex items-center gap-2 text-sm font-medium text-txt-secondary">
                      <FileText className="w-4 h-4 text-txt-tertiary" />
                      원본 보기
                    </div>
                    {isOriginalOpen ? (
                      <ChevronUp className="w-4 h-4 text-txt-tertiary" />
                    ) : (
                      <ChevronDown className="w-4 h-4 text-txt-tertiary" />
                    )}
                  </button>
                  <AnimatePresence>
                    {isOriginalOpen && (
                      <motion.div
                        initial={{
                          height: 0,
                        }}
                        animate={{
                          height: 'auto',
                        }}
                        exit={{
                          height: 0,
                        }}
                        className="overflow-hidden"
                      >
                        <div className="p-4 bg-surface-input text-sm text-txt-tertiary leading-relaxed border-t border-border">
                          {selectedNodes[0].data.originalText}
                          <div className="mt-4 pt-4 border-t border-border-subtle">
                            <button className="flex items-center gap-1.5 text-xs text-cyan-600 dark:text-cyan-400 hover:text-cyan-500 transition-colors">
                              <ExternalLink className="w-3 h-3" />
                              원본 출처로 이동
                            </button>
                          </div>
                        </div>
                      </motion.div>
                    )}
                  </AnimatePresence>
                </div>

                <div className="pt-4 border-t border-border">
                  <button className="w-full py-3 bg-violet-500/10 hover:bg-violet-500/20 text-violet-600 dark:text-violet-400 border border-violet-500/30 rounded-xl text-sm font-medium transition-colors flex items-center justify-center gap-2">
                    <Sparkles className="w-4 h-4" />이 노드를 바탕으로 프롬프트
                    작성
                  </button>
                </div>
              </div>
            ) : (
              // Multi Node View (Prompt Composer)
              <div className="space-y-6">
                <div>
                  <h3 className="text-sm font-medium text-txt-secondary mb-3">
                    선택된 지식 블록:{' '}
                    <span className="text-cyan-500 font-bold">
                      {selectedNodes.length}
                    </span>
                    개
                  </h3>
                  <div className="flex flex-wrap gap-2">
                    {selectedNodes.map((node) => (
                      <div
                        key={node.id}
                        className="flex items-center gap-1.5 px-2.5 py-1.5 bg-surface-tertiary border border-border rounded-lg text-xs text-txt-secondary"
                      >
                        <span className="truncate max-w-[150px]">
                          {node.data.title}
                        </span>
                        <button
                          onClick={() => onDeselectNode(node.id)}
                          className="text-txt-muted hover:text-rose-500 transition-colors"
                        >
                          <X className="w-3 h-3" />
                        </button>
                      </div>
                    ))}
                  </div>
                </div>

                <div className="space-y-3">
                  <label className="text-sm font-medium text-txt-secondary">
                    선택한 정보를 바탕으로 무엇을 할까요?
                  </label>
                  <textarea
                    value={promptIntent}
                    onChange={(e) => setPromptIntent(e.target.value)}
                    placeholder="예: 보고서 초안 작성, 공통점 요약, 카드뉴스 대본 만들기..."
                    className="w-full h-24 p-3 bg-surface-input border border-border rounded-xl text-sm text-txt-primary placeholder-txt-muted focus:outline-none focus:border-violet-500/50 focus:ring-1 focus:ring-violet-500/50 resize-none"
                  />
                  <div className="flex flex-wrap gap-2">
                    {['보고서 초안 작성', '공통점 요약', '블로그 글쓰기'].map(
                      (suggestion) => (
                        <button
                          key={suggestion}
                          onClick={() => setPromptIntent(suggestion)}
                          className="px-3 py-1.5 bg-surface-tertiary hover:bg-surface-elevated border border-transparent hover:border-border text-txt-secondary rounded-full text-xs transition-colors"
                        >
                          {suggestion}
                        </button>
                      ),
                    )}
                  </div>
                </div>

                {!generatedPrompt ? (
                  <button
                    onClick={handleGeneratePrompt}
                    className="w-full py-3 bg-violet-600 hover:bg-violet-500 text-white rounded-xl text-sm font-medium transition-colors flex items-center justify-center gap-2 shadow-lg shadow-violet-500/20"
                  >
                    <Sparkles className="w-4 h-4" />
                    프롬프트 완성
                  </button>
                ) : (
                  <motion.div
                    initial={{
                      opacity: 0,
                      y: 10,
                    }}
                    animate={{
                      opacity: 1,
                      y: 0,
                    }}
                    className="p-4 bg-surface-input border border-violet-500/30 rounded-xl relative group"
                  >
                    <h4 className="text-xs font-medium text-violet-600 dark:text-violet-400 mb-2 flex items-center gap-1.5">
                      <Sparkles className="w-3 h-3" />
                      생성된 프롬프트
                    </h4>
                    <p className="text-sm text-txt-secondary whitespace-pre-wrap leading-relaxed">
                      {generatedPrompt}
                    </p>
                    <button
                      onClick={handleCopy}
                      className="absolute top-3 right-3 p-2 bg-surface-tertiary hover:bg-surface-elevated border border-transparent hover:border-border text-txt-secondary rounded-lg transition-colors flex items-center gap-1.5"
                    >
                      {isCopied ? (
                        <Check className="w-4 h-4 text-green-500" />
                      ) : (
                        <Copy className="w-4 h-4" />
                      )}
                      <span className="text-xs">
                        {isCopied ? '복사됨' : '복사'}
                      </span>
                    </button>
                  </motion.div>
                )}
              </div>
            )}
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}

```
```components/FloatingActions.tsx
import React from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Link, Unlink, Sparkles } from 'lucide-react'
interface FloatingActionsProps {
  selectedCount: number
  onConnect: () => void
  onDisconnect: () => void
  onExtractPrompt: () => void
}
export function FloatingActions({
  selectedCount,
  onConnect,
  onDisconnect,
  onExtractPrompt,
}: FloatingActionsProps) {
  return (
    <AnimatePresence>
      {selectedCount > 1 && (
        <motion.div
          initial={{
            opacity: 0,
            y: 20,
            scale: 0.9,
          }}
          animate={{
            opacity: 1,
            y: 0,
            scale: 1,
          }}
          exit={{
            opacity: 0,
            y: 20,
            scale: 0.9,
          }}
          transition={{
            type: 'spring',
            stiffness: 300,
            damping: 25,
          }}
          className="fixed bottom-8 right-8 z-40 flex items-center gap-2 bg-surface-elevated/90 backdrop-blur-md border border-border p-2 rounded-2xl shadow-2xl transition-colors duration-200"
        >
          <div className="px-3 py-1 border-r border-border">
            <span className="text-sm font-medium text-txt-secondary">
              <span className="text-cyan-500 font-bold">{selectedCount}</span>개
              선택됨
            </span>
          </div>

          <button
            onClick={onConnect}
            className="flex items-center gap-2 px-3 py-2 rounded-xl hover:bg-cyan-500/10 text-txt-primary text-sm font-medium transition-colors group"
            title="선택한 노드들을 연결합니다"
          >
            <Link className="w-4 h-4 text-cyan-500 group-hover:text-cyan-600 dark:group-hover:text-cyan-400" />
            연결
          </button>

          <button
            onClick={onDisconnect}
            className="flex items-center gap-2 px-3 py-2 rounded-xl hover:bg-rose-500/10 text-txt-primary text-sm font-medium transition-colors group"
            title="선택한 노드들 사이의 연결을 끊습니다"
          >
            <Unlink className="w-4 h-4 text-rose-500 group-hover:text-rose-600 dark:group-hover:text-rose-400" />
            끊기
          </button>

          <div className="w-px h-6 bg-border" />

          <button
            onClick={onExtractPrompt}
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-violet-600 hover:bg-violet-500 text-white text-sm font-medium transition-colors shadow-lg shadow-violet-500/20"
          >
            <Sparkles className="w-4 h-4" />
            프롬프트 뽑기
          </button>
        </motion.div>
      )}
    </AnimatePresence>
  )
}

```
```components/GlobalNav.tsx
import React from 'react'
import { Search, Plus, Network, User } from 'lucide-react'
import { ThemeToggle } from './ThemeToggle'
interface GlobalNavProps {
  onAddDataClick: () => void
  searchQuery: string
  setSearchQuery: (query: string) => void
}
export function GlobalNav({
  onAddDataClick,
  searchQuery,
  setSearchQuery,
}: GlobalNavProps) {
  return (
    <header className="fixed top-0 left-0 right-0 h-16 bg-surface-primary/80 backdrop-blur-md border-b border-border z-40 flex items-center justify-between px-6 transition-colors duration-200">
      {/* Logo */}
      <div className="flex items-center gap-2">
        <div className="bg-cyan-500/20 p-1.5 rounded-lg">
          <Network className="w-6 h-6 text-cyan-400" />
        </div>
        <span className="text-xl font-bold tracking-tight text-txt-primary">
          NodeMind
        </span>
      </div>

      {/* Search */}
      <div className="flex-1 max-w-2xl px-8">
        <div className="relative group">
          <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <Search className="h-5 w-5 text-txt-tertiary group-focus-within:text-cyan-500 transition-colors" />
          </div>
          <input
            type="text"
            className="block w-full pl-10 pr-3 py-2 border border-border rounded-xl leading-5 bg-surface-secondary text-txt-primary placeholder-txt-tertiary focus:outline-none focus:bg-surface-primary focus:border-cyan-500/50 focus:ring-1 focus:ring-cyan-500/50 transition-all sm:text-sm"
            placeholder="지식을 검색하세요..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>
      </div>

      {/* Actions */}
      <div className="flex items-center gap-4">
        <ThemeToggle />
        <button
          onClick={onAddDataClick}
          className="flex items-center gap-2 bg-cyan-600 hover:bg-cyan-500 text-white px-4 py-2 rounded-lg font-medium transition-colors shadow-lg shadow-cyan-500/20"
        >
          <Plus className="w-4 h-4" />
          <span>데이터 추가</span>
        </button>
        <button className="w-9 h-9 rounded-full bg-surface-tertiary border border-border flex items-center justify-center hover:bg-surface-secondary transition-colors">
          <User className="w-5 h-5 text-txt-secondary" />
        </button>
      </div>
    </header>
  )
}

```
```components/KnowledgeGraph.tsx
import React, {
  useCallback,
  useMemo,
  forwardRef,
  useImperativeHandle,
  memo,
} from 'react'
import {
  ReactFlow,
  MiniMap,
  Controls,
  Background,
  useNodesState,
  useEdgesState,
  addEdge,
  Connection,
  Edge,
  Node,
  BackgroundVariant,
  SelectionMode,
} from '@xyflow/react'
import '@xyflow/react/dist/style.css'
import { CustomNode } from './CustomNode'
import { DeletableEdge } from './DeletableEdge'
import { initialNodes, initialEdges, NodeData } from '../data/sampleNodes'
interface KnowledgeGraphProps {
  searchQuery: string
  onSelectionChange: (nodes: Node<NodeData>[]) => void
}
export interface KnowledgeGraphHandle {
  connectNodes: (nodeIds: string[]) => void
  disconnectNodes: (nodeIds: string[]) => void
}
const nodeTypes = {
  custom: CustomNode,
}
const edgeTypes = {
  deletable: DeletableEdge,
}
export const KnowledgeGraph = forwardRef<
  KnowledgeGraphHandle,
  KnowledgeGraphProps
>(function KnowledgeGraph({ searchQuery, onSelectionChange }, ref) {
  const [nodes, setNodes, onNodesChange] = useNodesState(initialNodes)
  const [edges, setEdges, onEdgesChange] = useEdgesState(
    initialEdges.map((e) => ({
      ...e,
      type: 'deletable',
    })),
  )
  const handleDeleteEdge = useCallback(
    (edgeId: string) => {
      setEdges((eds) => eds.filter((e) => e.id !== edgeId))
    },
    [setEdges],
  )
  const onConnect = useCallback(
    (params: Connection) =>
      setEdges((eds) =>
        addEdge(
          {
            ...params,
            type: 'deletable',
            animated: true,
            style: {
              strokeWidth: 2,
              strokeDasharray: '5,5',
            },
          },
          eds,
        ),
      ),
    [setEdges],
  )
  // Expose connect/disconnect to parent via ref
  useImperativeHandle(
    ref,
    () => ({
      connectNodes: (nodeIds: string[]) => {
        if (nodeIds.length < 2) return
        setEdges((eds) => {
          let newEdges = [...eds]
          for (let i = 0; i < nodeIds.length - 1; i++) {
            const source = nodeIds[i]
            const target = nodeIds[i + 1]
            const edgeId = `e${source}-${target}-user`
            const exists = newEdges.some(
              (e) =>
                (e.source === source && e.target === target) ||
                (e.source === target && e.target === source),
            )
            if (!exists) {
              newEdges = addEdge(
                {
                  id: edgeId,
                  source,
                  target,
                  type: 'deletable',
                  animated: true,
                  style: {
                    strokeWidth: 2,
                    strokeDasharray: '5,5',
                  },
                },
                newEdges,
              )
            }
          }
          return newEdges
        })
      },
      disconnectNodes: (nodeIds: string[]) => {
        if (nodeIds.length < 2) return
        const idSet = new Set(nodeIds)
        setEdges((eds) =>
          eds.filter((e) => !(idSet.has(e.source) && idSet.has(e.target))),
        )
      },
    }),
    [setEdges],
  )
  const handleSelectionChange = useCallback(
    ({ nodes }: { nodes: Node[] }) => {
      onSelectionChange(nodes as Node<NodeData>[])
    },
    [onSelectionChange],
  )
  // Inject onDelete into edge data
  const edgesWithCallbacks = useMemo(() => {
    return edges.map((edge) => ({
      ...edge,
      data: {
        ...edge.data,
        onDelete: handleDeleteEdge,
      },
    }))
  }, [edges, handleDeleteEdge])
  // Apply search highlight (also searches tags)
  const highlightedNodes = useMemo(() => {
    if (!searchQuery) return nodes
    const query = searchQuery.toLowerCase()
    return nodes.map((node) => {
      const isMatch =
        node.data.title.toLowerCase().includes(query) ||
        node.data.summary.toLowerCase().includes(query) ||
        (node.data.tags || []).some((tag: string) =>
          tag.toLowerCase().includes(query),
        )
      return {
        ...node,
        style: {
          ...node.style,
          opacity: isMatch ? 1 : 0.2,
          filter: isMatch
            ? 'drop-shadow(0 0 15px rgba(6, 182, 212, 0.4))'
            : 'none',
        },
      }
    })
  }, [nodes, searchQuery])
  return (
    <div className="w-full h-full bg-surface-primary transition-colors duration-200">
      <ReactFlow
        nodes={highlightedNodes}
        edges={edgesWithCallbacks}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        onConnect={onConnect}
        onSelectionChange={handleSelectionChange}
        nodeTypes={nodeTypes}
        edgeTypes={edgeTypes}
        fitView
        fitViewOptions={{
          padding: 0.2,
        }}
        selectionMode={SelectionMode.Partial}
        minZoom={0.1}
        maxZoom={2}
        proOptions={{
          hideAttribution: true,
        }}
        defaultEdgeOptions={{
          type: 'deletable',
        }}
      >
        <Background
          variant={BackgroundVariant.Dots}
          gap={24}
          size={1.5}
          color="var(--color-grid-dot)"
        />
        <Controls className="fill-content-secondary" showInteractive={false} />
        <MiniMap
          nodeColor={(node) => {
            switch (node.data?.type) {
              case 'memo':
                return '#06b6d4'
              case 'pdf':
                return '#f43f5e'
              case 'diary':
                return '#f59e0b'
              case 'chat':
                return '#8b5cf6'
              default:
                return '#64748b'
            }
          }}
          maskColor="var(--color-overlay)"
          className="rounded-xl overflow-hidden"
        />
      </ReactFlow>
    </div>
  )
})

```
```components/LeftSidebar.tsx
import React, { useState, memo } from 'react'
import { motion } from 'framer-motion'
import {
  ChevronLeft,
  ChevronRight,
  Layers,
  FileText,
  Clock,
  Filter,
  File,
  MessageSquare,
  BookOpen,
} from 'lucide-react'
interface LeftSidebarProps {
  isOpen: boolean
  setIsOpen: (isOpen: boolean) => void
}
export function LeftSidebar({ isOpen, setIsOpen }: LeftSidebarProps) {
  const [activeView, setActiveView] = useState('context')
  const [filters, setFilters] = useState({
    memo: true,
    pdf: true,
    diary: true,
    chat: true,
  })
  const toggleFilter = (key: keyof typeof filters) => {
    setFilters((prev) => ({
      ...prev,
      [key]: !prev[key],
    }))
  }
  return (
    <>
      <motion.aside
        initial={false}
        animate={{
          width: isOpen ? 240 : 0,
        }}
        className="fixed left-0 top-16 bottom-0 bg-surface-primary/90 backdrop-blur-sm border-r border-border z-30 overflow-hidden flex flex-col transition-colors duration-200"
      >
        <div className="p-4 w-[240px] flex-1 overflow-y-auto">
          {/* View Switcher */}
          <div className="mb-8">
            <h3 className="text-xs font-semibold text-txt-muted uppercase tracking-wider mb-3">
              View Mode
            </h3>
            <div className="space-y-1">
              <ViewButton
                icon={<Layers className="w-4 h-4" />}
                label="Context View"
                isActive={activeView === 'context'}
                onClick={() => setActiveView('context')}
              />
              <ViewButton
                icon={<FileText className="w-4 h-4" />}
                label="Origin View"
                isActive={activeView === 'origin'}
                onClick={() => setActiveView('origin')}
              />
              <ViewButton
                icon={<Clock className="w-4 h-4" />}
                label="Timeline View"
                isActive={activeView === 'timeline'}
                onClick={() => setActiveView('timeline')}
              />
            </div>
          </div>

          {/* Filters */}
          <div>
            <div className="flex items-center gap-2 mb-3">
              <Filter className="w-4 h-4 text-txt-muted" />
              <h3 className="text-xs font-semibold text-txt-muted uppercase tracking-wider">
                Filters
              </h3>
            </div>

            <div className="space-y-2">
              <FilterCheckbox
                label="메모"
                color="bg-cyan-500"
                icon={<FileText className="w-3 h-3 text-cyan-500" />}
                checked={filters.memo}
                onChange={() => toggleFilter('memo')}
              />
              <FilterCheckbox
                label="PDF 문서"
                color="bg-rose-500"
                icon={<File className="w-3 h-3 text-rose-500" />}
                checked={filters.pdf}
                onChange={() => toggleFilter('pdf')}
              />
              <FilterCheckbox
                label="일기/저널"
                color="bg-amber-500"
                icon={<BookOpen className="w-3 h-3 text-amber-500" />}
                checked={filters.diary}
                onChange={() => toggleFilter('diary')}
              />
              <FilterCheckbox
                label="AI 대화"
                color="bg-violet-500"
                icon={<MessageSquare className="w-3 h-3 text-violet-500" />}
                checked={filters.chat}
                onChange={() => toggleFilter('chat')}
              />
            </div>
          </div>
        </div>
      </motion.aside>

      {/* Toggle Button */}
      <motion.button
        initial={false}
        animate={{
          left: isOpen ? 240 : 0,
        }}
        onClick={() => setIsOpen(!isOpen)}
        className="fixed top-20 z-30 bg-surface-tertiary border border-border border-l-0 rounded-r-md p-1.5 text-txt-tertiary hover:text-txt-primary hover:bg-surface-secondary transition-colors shadow-md"
      >
        {isOpen ? (
          <ChevronLeft className="w-4 h-4" />
        ) : (
          <ChevronRight className="w-4 h-4" />
        )}
      </motion.button>
    </>
  )
}
function ViewButton({
  icon,
  label,
  isActive,
  onClick,
}: {
  icon: React.ReactNode
  label: string
  isActive: boolean
  onClick: () => void
}) {
  return (
    <button
      onClick={onClick}
      className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors ${isActive ? 'bg-surface-tertiary text-cyan-500' : 'text-txt-tertiary hover:bg-surface-secondary hover:text-txt-primary'}`}
    >
      {icon}
      {label}
    </button>
  )
}
function FilterCheckbox({
  label,
  color,
  icon,
  checked,
  onChange,
}: {
  label: string
  color: string
  icon: React.ReactNode
  checked: boolean
  onChange: () => void
}) {
  return (
    <label className="flex items-center gap-3 px-2 py-1.5 rounded hover:bg-surface-secondary cursor-pointer group transition-colors">
      <div
        className={`relative flex items-center justify-center w-4 h-4 rounded border ${checked ? 'border-transparent ' + color : 'border-border group-hover:border-txt-muted'}`}
      >
        {checked && (
          <svg
            className="w-3 h-3 text-white absolute"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={3}
              d="M5 13l4 4L19 7"
            />
          </svg>
        )}
      </div>
      <div className="flex items-center gap-2">
        {icon}
        <span
          className={`text-sm ${checked ? 'text-txt-primary' : 'text-txt-muted'}`}
        >
          {label}
        </span>
      </div>
    </label>
  )
}

```
```components/SmartInputModal.tsx
import React, { useEffect, useState, memo } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import {
  X,
  UploadCloud,
  FileText,
  Sparkles,
  ArrowRight,
  CheckCircle2,
} from 'lucide-react'
interface SmartInputModalProps {
  isOpen: boolean
  onClose: () => void
}
export function SmartInputModal({ isOpen, onClose }: SmartInputModalProps) {
  const [activeTab, setActiveTab] = useState<'text' | 'file'>('text')
  const [isProcessing, setIsProcessing] = useState(false)
  const [processStep, setProcessStep] = useState(0) // 0: idle, 1: extracting, 2: chunking, 3: done
  // Reset state when modal opens
  useEffect(() => {
    if (isOpen) {
      setIsProcessing(false)
      setProcessStep(0)
    }
  }, [isOpen])
  const handleStartAnalysis = () => {
    setIsProcessing(true)
    setProcessStep(1)
    // Simulate AI processing steps
    setTimeout(() => setProcessStep(2), 1500)
    setTimeout(() => setProcessStep(3), 3500)
  }
  if (!isOpen) return null
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-surface-primary/80 backdrop-blur-sm transition-colors duration-200">
      <motion.div
        initial={{
          opacity: 0,
          scale: 0.95,
          y: 20,
        }}
        animate={{
          opacity: 1,
          scale: 1,
          y: 0,
        }}
        exit={{
          opacity: 0,
          scale: 0.95,
          y: 20,
        }}
        className="w-full max-w-5xl bg-surface-elevated border border-border rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]"
      >
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-border">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-cyan-500/10 rounded-lg">
              <Sparkles className="w-5 h-5 text-cyan-500" />
            </div>
            <h2 className="text-lg font-semibold text-txt-primary">
              새로운 지식 추가
            </h2>
          </div>
          <button
            onClick={onClose}
            className="p-2 text-txt-tertiary hover:text-txt-primary hover:bg-surface-secondary rounded-lg transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="flex flex-1 overflow-hidden">
          {/* Left Column: Input */}
          <div className="w-1/2 border-r border-border p-6 flex flex-col bg-surface-secondary/50">
            <div className="flex bg-surface-tertiary p-1 rounded-lg mb-6">
              <button
                onClick={() => setActiveTab('text')}
                className={`flex-1 py-2 text-sm font-medium rounded-md transition-colors ${activeTab === 'text' ? 'bg-surface-elevated text-txt-primary shadow-sm' : 'text-txt-tertiary hover:text-txt-secondary'}`}
              >
                텍스트 입력
              </button>
              <button
                onClick={() => setActiveTab('file')}
                className={`flex-1 py-2 text-sm font-medium rounded-md transition-colors ${activeTab === 'file' ? 'bg-surface-elevated text-txt-primary shadow-sm' : 'text-txt-tertiary hover:text-txt-secondary'}`}
              >
                파일 업로드
              </button>
            </div>

            <div className="flex-1 flex flex-col">
              {activeTab === 'text' ? (
                <div className="flex flex-col h-full gap-4">
                  <input
                    type="text"
                    placeholder="제목을 입력하세요"
                    className="w-full px-4 py-3 bg-surface-input border border-border rounded-xl text-txt-primary placeholder-txt-tertiary focus:outline-none focus:border-cyan-500/50 focus:ring-1 focus:ring-cyan-500/50 transition-all"
                  />
                  <textarea
                    placeholder="여기에 내용을 입력하거나 붙여넣으세요..."
                    className="w-full flex-1 px-4 py-3 bg-surface-input border border-border rounded-xl text-txt-primary placeholder-txt-tertiary focus:outline-none focus:border-cyan-500/50 focus:ring-1 focus:ring-cyan-500/50 transition-all resize-none"
                  />
                </div>
              ) : (
                <div className="flex-1 flex flex-col items-center justify-center border-2 border-dashed border-border rounded-xl bg-surface-input/50 hover:bg-surface-tertiary/50 transition-colors cursor-pointer group">
                  <div className="p-4 bg-surface-tertiary rounded-full mb-4 group-hover:scale-110 transition-transform">
                    <UploadCloud className="w-8 h-8 text-cyan-500" />
                  </div>
                  <p className="text-txt-secondary font-medium mb-2">
                    파일을 여기에 끌어다 놓으세요
                  </p>
                  <p className="text-txt-muted text-sm">
                    PDF, Word, TXT 지원 (최대 50MB)
                  </p>
                  <button className="mt-6 px-4 py-2 bg-surface-tertiary text-txt-secondary rounded-lg text-sm font-medium hover:bg-surface-secondary transition-colors border border-border">
                    파일 찾아보기
                  </button>
                </div>
              )}
            </div>

            <button
              onClick={handleStartAnalysis}
              disabled={isProcessing}
              className="mt-6 w-full py-3 bg-cyan-600 hover:bg-cyan-500 disabled:bg-surface-tertiary disabled:text-txt-tertiary text-white rounded-xl font-medium transition-colors flex items-center justify-center gap-2"
            >
              {isProcessing ? (
                <>
                  <motion.div
                    animate={{
                      rotate: 360,
                    }}
                    transition={{
                      duration: 2,
                      repeat: Infinity,
                      ease: 'linear',
                    }}
                  >
                    <Sparkles className="w-5 h-5" />
                  </motion.div>
                  AI 분석 중...
                </>
              ) : (
                <>
                  분석 시작
                  <ArrowRight className="w-5 h-5" />
                </>
              )}
            </button>
          </div>

          {/* Right Column: AI Processing */}
          <div className="w-1/2 p-6 bg-surface-primary flex flex-col relative overflow-hidden">
            {!isProcessing ? (
              <div className="flex-1 flex flex-col items-center justify-center text-txt-muted">
                <NetworkIcon className="w-16 h-16 mb-4 opacity-20" />
                <p>AI 분석 결과가 여기에 표시됩니다</p>
              </div>
            ) : (
              <div className="flex-1 flex flex-col">
                <div className="mb-6">
                  <h3 className="text-sm font-medium text-txt-tertiary mb-2">
                    처리 현황
                  </h3>
                  <div className="flex items-center gap-2 text-sm">
                    <StatusBadge
                      active={processStep >= 1}
                      done={processStep > 1}
                      label="텍스트 추출"
                    />
                    <div
                      className={`h-[1px] w-8 ${processStep >= 2 ? 'bg-cyan-500' : 'bg-border'}`}
                    />
                    <StatusBadge
                      active={processStep >= 2}
                      done={processStep > 2}
                      label="의미 단위 분할"
                    />
                    <div
                      className={`h-[1px] w-8 ${processStep >= 3 ? 'bg-cyan-500' : 'bg-border'}`}
                    />
                    <StatusBadge
                      active={processStep >= 3}
                      done={processStep >= 3}
                      label="노드 생성"
                    />
                  </div>
                </div>

                <div className="flex-1 overflow-y-auto pr-2 space-y-4">
                  <AnimatePresence>
                    {processStep >= 2 && (
                      <>
                        <ProcessingNode
                          delay={0}
                          title="AI 모델의 한계와 RAG"
                          type="pdf"
                        />
                        <ProcessingNode
                          delay={0.5}
                          title="벡터 데이터베이스의 역할"
                          type="memo"
                        />
                        <ProcessingNode
                          delay={1.0}
                          title="시맨틱 검색 구현 방식"
                          type="memo"
                        />
                      </>
                    )}
                  </AnimatePresence>
                </div>

                <AnimatePresence>
                  {processStep === 3 && (
                    <motion.div
                      initial={{
                        opacity: 0,
                        y: 20,
                      }}
                      animate={{
                        opacity: 1,
                        y: 0,
                      }}
                      className="mt-6 pt-6 border-t border-border"
                    >
                      <div className="flex items-center justify-between mb-4">
                        <p className="text-sm text-txt-secondary">
                          <span className="text-cyan-500 font-bold">3개</span>의
                          새로운 지식 노드가 발견되었습니다.
                        </p>
                      </div>
                      <button
                        onClick={onClose}
                        className="w-full py-3 bg-cyan-600 hover:bg-cyan-500 text-white rounded-xl font-medium transition-colors flex items-center justify-center gap-2 shadow-lg shadow-cyan-500/20"
                      >
                        <CheckCircle2 className="w-5 h-5" />
                        그래프에 저장하기
                      </button>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            )}
          </div>
        </div>
      </motion.div>
    </div>
  )
}
function StatusBadge({
  active,
  done,
  label,
}: {
  active: boolean
  done: boolean
  label: string
}) {
  return (
    <div
      className={`flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium transition-colors ${done ? 'bg-cyan-500/20 text-cyan-600 dark:text-cyan-400 border border-cyan-500/30' : active ? 'bg-surface-tertiary text-txt-primary border border-border animate-pulse' : 'bg-surface-secondary text-txt-muted border border-border-subtle'}`}
    >
      {done && <CheckCircle2 className="w-3 h-3" />}
      {label}
    </div>
  )
}
function ProcessingNode({
  delay,
  title,
  type,
}: {
  delay: number
  title: string
  type: string
}) {
  return (
    <motion.div
      initial={{
        opacity: 0,
        x: -20,
      }}
      animate={{
        opacity: 1,
        x: 0,
      }}
      transition={{
        delay,
        type: 'spring',
        stiffness: 200,
        damping: 20,
      }}
      className="p-4 bg-surface-tertiary/50 border border-border rounded-xl flex items-start gap-3"
    >
      <div
        className={`p-2 rounded-lg ${type === 'pdf' ? 'bg-rose-500/20 text-rose-600 dark:text-rose-400' : 'bg-cyan-500/20 text-cyan-600 dark:text-cyan-400'}`}
      >
        <FileText className="w-4 h-4" />
      </div>
      <div>
        <h4 className="text-sm font-medium text-txt-primary mb-1">{title}</h4>
        <div className="h-2 w-32 bg-surface-secondary rounded-full overflow-hidden border border-border-subtle">
          <motion.div
            initial={{
              width: 0,
            }}
            animate={{
              width: '100%',
            }}
            transition={{
              delay: delay + 0.2,
              duration: 0.8,
            }}
            className="h-full bg-cyan-500"
          />
        </div>
      </div>
    </motion.div>
  )
}
function NetworkIcon(props: any) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      {...props}
    >
      <rect x="16" y="16" width="6" height="6" rx="1" />
      <rect x="2" y="16" width="6" height="6" rx="1" />
      <rect x="9" y="2" width="6" height="6" rx="1" />
      <path d="M5 16v-3a4 4 0 0 1 4-4h6a4 4 0 0 1 4 4v3" />
      <path d="M12 8v4" />
    </svg>
  )
}

```
```components/ThemeToggle.tsx
import React, { useEffect, useState } from 'react'
import { motion } from 'framer-motion'
import { Sun, Moon } from 'lucide-react'
export function ThemeToggle() {
  const [isDark, setIsDark] = useState(true)
  useEffect(() => {
    // Check local storage or system preference on mount
    const savedTheme = localStorage.getItem('nodemind-theme')
    const prefersDark = window.matchMedia(
      '(prefers-color-scheme: dark)',
    ).matches
    const shouldBeDark = savedTheme === 'dark' || (!savedTheme && prefersDark)
    setIsDark(shouldBeDark)
    if (shouldBeDark) {
      document.documentElement.classList.add('dark')
    } else {
      document.documentElement.classList.remove('dark')
    }
  }, [])
  const toggleTheme = () => {
    const newIsDark = !isDark
    setIsDark(newIsDark)
    if (newIsDark) {
      document.documentElement.classList.add('dark')
      localStorage.setItem('nodemind-theme', 'dark')
    } else {
      document.documentElement.classList.remove('dark')
      localStorage.setItem('nodemind-theme', 'light')
    }
  }
  return (
    <button
      onClick={toggleTheme}
      className="relative w-9 h-9 rounded-full bg-surface-tertiary border border-border flex items-center justify-center hover:bg-surface-secondary transition-colors overflow-hidden"
      aria-label="Toggle theme"
    >
      <motion.div
        initial={false}
        animate={{
          y: isDark ? 0 : -30,
          opacity: isDark ? 1 : 0,
        }}
        transition={{
          duration: 0.3,
          ease: 'easeInOut',
        }}
        className="absolute"
      >
        <Moon className="w-4 h-4 text-txt-secondary" />
      </motion.div>
      <motion.div
        initial={false}
        animate={{
          y: isDark ? 30 : 0,
          opacity: isDark ? 0 : 1,
        }}
        transition={{
          duration: 0.3,
          ease: 'easeInOut',
        }}
        className="absolute"
      >
        <Sun className="w-4 h-4 text-amber-500" />
      </motion.div>
    </button>
  )
}

```
```data/sampleNodes.ts
import { Node, Edge } from '@xyflow/react'

export type NodeType = 'memo' | 'pdf' | 'diary' | 'chat'

export interface NodeData extends Record<string, unknown> {
  title: string
  summary: string
  type: NodeType
  date: string
  originalText: string
  isImportant?: boolean
  tags: string[]
}

export const initialNodes: Node<NodeData>[] = [
  {
    id: '1',
    type: 'custom',
    position: { x: 0, y: 0 },
    data: {
      title: 'PKM 시스템 설계 원칙',
      summary:
        '개인 지식 관리 시스템은 정보의 수집보다 연결과 검색에 초점을 맞춰야 한다. 인지 부하를 줄이는 UI가 핵심.',
      type: 'memo',
      date: '2023-10-24',
      originalText:
        '최근 제텔카스텐과 세컨드 브레인 방법론을 공부하면서 느낀 점은, 결국 도구보다 프로세스가 중요하다는 것이다. 하지만 좋은 도구는 그 프로세스를 마찰 없이 실행하게 해준다. PKM 시스템 설계 시 가장 중요한 원칙은 정보의 단순한 축적이 아니라, 정보 간의 유기적인 연결을 돕고 필요할 때 즉시 꺼내 쓸 수 있는 검색성을 확보하는 것이다. 특히 시각적인 그래프 뷰는 뇌의 연상 작용을 모방하여 직관적인 탐색을 돕는다.',
      isImportant: true,
      tags: ['PKM', '설계원칙', 'UI/UX'],
    },
  },
  {
    id: '2',
    type: 'custom',
    position: { x: 250, y: -100 },
    data: {
      title: '제텔카스텐 방법론 요약',
      summary:
        '독일의 사회학자 니클라스 루만이 고안한 메모 상자 기법. 원자화된 메모와 상호 연결이 특징.',
      type: 'pdf',
      date: '2023-10-20',
      originalText:
        '[PDF 발췌] 제텔카스텐(Zettelkasten)은 독일어로 "메모 상자"를 뜻한다. 이 시스템의 핵심은 각 메모가 하나의 독립적인 아이디어(원자성)를 담고 있으며, 메모들끼리 고유 번호를 통해 거미줄처럼 연결된다는 점이다. 이를 통해 예상치 못한 아이디어의 결합을 유도하고 창의적인 글쓰기를 가능하게 한다.',
      tags: ['제텔카스텐', '메모법', '루만'],
    },
  },
  {
    id: '3',
    type: 'custom',
    position: { x: -200, y: 150 },
    data: {
      title: 'AI 기반 지식 추출 프롬프트',
      summary:
        '긴 텍스트에서 핵심 개념과 엔티티를 추출하여 JSON 형태로 반환하도록 지시하는 프롬프트 템플릿.',
      type: 'chat',
      date: '2023-10-25',
      originalText:
        'User: 다음 텍스트에서 주요 개념, 인물, 날짜를 추출하고 이들 간의 관계를 JSON 배열로 만들어줘. \n\nAI: 네, 요청하신 텍스트를 분석하여 다음과 같은 JSON 구조로 추출했습니다. \n```json\n{\n  "entities": [...],\n  "relationships": [...]\n}\n```\n이 구조를 활용하면 지식 그래프의 노드와 엣지를 자동 생성하는 데 유용할 것입니다.',
      isImportant: true,
      tags: ['프롬프트', 'NER', 'JSON'],
    },
  },
  {
    id: '4',
    type: 'custom',
    position: { x: 300, y: 150 },
    data: {
      title: '인지 부하 최소화 UI/UX',
      summary:
        '복잡한 데이터를 다룰 때 사용자의 피로도를 줄이기 위한 다크 모드, 점진적 정보 공개(Progressive Disclosure) 기법.',
      type: 'memo',
      date: '2023-10-26',
      originalText:
        '데이터 밀도가 높은 애플리케이션 화면을 설계할 때는 인지 부하 관리가 최우선이다. 한 번에 모든 정보를 보여주기보다는, 사용자의 상호작용(Hover, Click)에 따라 점진적으로 상세 정보를 노출하는 Progressive Disclosure 패턴을 적극 활용해야 한다. 또한 다크 모드는 장시간 화면을 보는 사용자의 눈 피로를 덜어주고, 데이터 시각화 요소(차트, 그래프 노드)의 색상을 더 선명하게 대비시키는 효과가 있다.',
      tags: ['인지부하', '다크모드', 'Progressive Disclosure'],
    },
  },
  {
    id: '5',
    type: 'custom',
    position: { x: 500, y: 0 },
    data: {
      title: '세컨드 브레인 구축기',
      summary:
        '옵시디언을 활용한 나만의 세컨드 브레인 구축 경험담. 폴더 구조보다 태그와 링크 위주의 정리.',
      type: 'diary',
      date: '2023-10-22',
      originalText:
        '오늘은 주말을 맞아 옵시디언 볼트를 대대적으로 정리했다. 기존의 복잡한 폴더 계층 구조를 과감히 버리고, PARA(Projects, Areas, Resources, Archives) 방법론을 느슨하게 적용했다. 대신 태그와 백링크를 적극적으로 활용하여 정보가 자연스럽게 연결되도록 유도했다. 아직 익숙해지려면 시간이 필요하겠지만, 정보를 찾는 속도가 훨씬 빨라진 느낌이다.',
      tags: ['옵시디언', 'PARA', '세컨드브레인'],
    },
  },
  {
    id: '6',
    type: 'custom',
    position: { x: -150, y: -200 },
    data: {
      title: 'LLM 컨텍스트 윈도우 한계',
      summary:
        '현재 LLM의 컨텍스트 윈도우 제한으로 인해 대규모 지식 베이스를 한 번에 처리하기 어려움. RAG 도입 필요.',
      type: 'pdf',
      date: '2023-10-21',
      originalText:
        '[논문 리뷰] 대규모 언어 모델(LLM)은 놀라운 성능을 보이지만, 입력받을 수 있는 토큰 수(Context Window)에 제한이 있다. 따라서 방대한 개인 지식 베이스 전체를 프롬프트에 넣는 것은 불가능하다. 이를 해결하기 위해 검색 증강 생성(RAG, Retrieval-Augmented Generation) 기술이 필수적이다. 사용자의 질문과 관련된 문서 조각(Chunk)만 벡터 DB에서 검색하여 프롬프트에 주입하는 방식이다.',
      tags: ['LLM', '컨텍스트윈도우', 'RAG'],
    },
  },
  {
    id: '7',
    type: 'custom',
    position: { x: -350, y: -50 },
    data: {
      title: 'RAG 아키텍처 초안',
      summary:
        '문서 임베딩, 벡터 스토어(Pinecone), 시맨틱 검색을 결합한 RAG 시스템 파이프라인 설계.',
      type: 'memo',
      date: '2023-10-26',
      originalText:
        'RAG 파이프라인 설계 초안:\n1. 데이터 수집: 노션, PDF, 로컬 마크다운 파일\n2. 청킹(Chunking): 의미 단위로 텍스트 분할 (약 500~1000 토큰)\n3. 임베딩: OpenAI text-embedding-3-small 모델 사용\n4. 저장: Pinecone 벡터 데이터베이스\n5. 검색: 사용자 쿼리 임베딩 후 코사인 유사도 기반 Top-K 검색\n6. 생성: 검색된 컨텍스트를 LLM에 주입하여 답변 생성',
      isImportant: true,
      tags: ['RAG', '임베딩', 'Pinecone'],
    },
  },
  {
    id: '8',
    type: 'custom',
    position: { x: 100, y: 250 },
    data: {
      title: 'Framer Motion 애니메이션 팁',
      summary:
        'React에서 자연스러운 UI 트랜지션을 구현하기 위한 Framer Motion의 spring 애니메이션 설정값.',
      type: 'memo',
      date: '2023-10-27',
      originalText:
        'UI 애니메이션은 너무 빠르지도, 너무 느리지도 않아야 한다. Framer Motion에서 가장 자연스러운 느낌을 주는 spring 설정은 보통 stiffness: 300, damping: 30 정도이다. 모달이 뜰 때나 사이드바가 열릴 때 이 값을 기본으로 사용하고, 상황에 따라 미세 조정하는 것이 좋다. 특히 layout 애니메이션을 활용하면 리스트 아이템이 추가/삭제될 때 주변 요소들이 부드럽게 밀려나는 효과를 쉽게 구현할 수 있다.',
      tags: ['Framer Motion', '애니메이션', 'React'],
    },
  },
  {
    id: '9',
    type: 'custom',
    position: { x: -400, y: 200 },
    data: {
      title: '벡터 DB 비교 분석',
      summary:
        'Pinecone, Milvus, Qdrant, ChromaDB 등 주요 벡터 데이터베이스의 장단점 및 가격 비교.',
      type: 'pdf',
      date: '2023-10-18',
      originalText:
        '[리포트 요약] \n- Pinecone: 완전 관리형 SaaS, 설정이 쉽지만 비용이 다소 높음.\n- Milvus: 오픈소스, 대규모 스케일링에 적합, 운영 복잡도 높음.\n- Qdrant: Rust 기반, 빠르고 가벼움, 로컬 및 클라우드 지원.\n- ChromaDB: 로컬 개발 및 프로토타이핑에 최적화, 사용이 매우 간편함.\n초기 프로젝트에는 ChromaDB로 시작하고, 프로덕션 전환 시 Pinecone이나 Qdrant 클라우드로 마이그레이션하는 전략을 추천한다.',
      tags: ['벡터DB', 'Pinecone', 'ChromaDB'],
    },
  },
  {
    id: '10',
    type: 'custom',
    position: { x: 200, y: -250 },
    data: {
      title: '그래프 데이터 시각화 라이브러리',
      summary:
        'React Flow, D3.js, Cytoscape.js 비교. React 생태계에서는 React Flow(@xyflow/react)가 가장 적합함.',
      type: 'chat',
      date: '2023-10-23',
      originalText:
        'User: React 프로젝트에서 노드와 엣지로 구성된 인터랙티브 그래프를 그리려고 해. 어떤 라이브러리가 좋을까?\n\nAI: React 환경이라면 단연코 **React Flow (@xyflow/react)**를 추천합니다. \n이유:\n1. React 컴포넌트 기반으로 커스텀 노드를 만들기 매우 쉽습니다.\n2. 줌, 팬, 드래그 등 필수 인터랙션이 내장되어 있습니다.\n3. 상태 관리가 직관적입니다.\nD3.js는 너무 로우레벨이고, Cytoscape.js는 강력하지만 React와의 통합이 다소 번거로울 수 있습니다.',
      tags: ['시각화', 'React Flow', 'D3.js'],
    },
  },
]

export const initialEdges: Edge[] = [
  {
    id: 'e1-2',
    source: '1',
    target: '2',
    animated: true,
    style: { strokeWidth: 2, stroke: '#475569' },
  },
  {
    id: 'e1-4',
    source: '1',
    target: '4',
    animated: false,
    style: { strokeWidth: 3, stroke: '#64748b' },
  },
  {
    id: 'e2-5',
    source: '2',
    target: '5',
    animated: false,
    style: { strokeWidth: 1, stroke: '#334155' },
  },
  {
    id: 'e1-3',
    source: '1',
    target: '3',
    animated: true,
    style: { strokeWidth: 2, stroke: '#475569', strokeDasharray: '5,5' },
  },
  {
    id: 'e3-6',
    source: '3',
    target: '6',
    animated: false,
    style: { strokeWidth: 2, stroke: '#475569' },
  },
  {
    id: 'e6-7',
    source: '6',
    target: '7',
    animated: true,
    style: { strokeWidth: 3, stroke: '#64748b' },
  },
  {
    id: 'e7-9',
    source: '7',
    target: '9',
    animated: false,
    style: { strokeWidth: 2, stroke: '#475569' },
  },
  {
    id: 'e4-8',
    source: '4',
    target: '8',
    animated: true,
    style: { strokeWidth: 1, stroke: '#334155', strokeDasharray: '5,5' },
  },
  {
    id: 'e1-10',
    source: '1',
    target: '10',
    animated: false,
    style: { strokeWidth: 2, stroke: '#475569' },
  },
]

```
```index.css
/* @import url() FONT IMPORTS MUST ALWAYS BE AT THE VERY TOP OF THIS FILE, ABOVE THE TAILWIND IMPORTS — DO NOT DELETE THIS COMMENT */
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');

/* CRITICAL: THE FOLLOWING TAILWIND IMPORTS MUST NEVER BE DELETED OR REORDERED — DO NOT DELETE THIS COMMENT */
@import 'tailwindcss/base';
@import 'tailwindcss/components';
@import 'tailwindcss/utilities';

/* END TAILWIND IMPORTS — ALL OTHER CSS MUST GO BELOW THIS LINE */

:root {
  /* Light Mode Variables */
  --color-bg-primary: #f8fafc; /* slate-50 */
  --color-bg-secondary: #ffffff;
  --color-bg-tertiary: #f1f5f9; /* slate-100 */
  --color-bg-elevated: #ffffff;
  --color-bg-input: #ffffff;
  --color-border: #e2e8f0; /* slate-200 */
  --color-border-subtle: #f1f5f9; /* slate-100 */
  --color-text-primary: #0f172a; /* slate-900 */
  --color-text-secondary: #475569; /* slate-600 */
  --color-text-tertiary: #94a3b8; /* slate-400 */
  --color-text-muted: #64748b; /* slate-500 */
  --color-grid-dot: #cbd5e1; /* slate-300 */
  --color-overlay: rgba(255, 255, 255, 0.8);
  --color-edge-default: #94a3b8; /* slate-400 */
  --color-edge-hover: #475569; /* slate-600 */
  --color-edge-selected: #06b6d4; /* cyan-500 */
}
.dark {
  /* Dark Mode Variables */
  --color-bg-primary: #020617; /* slate-950 */
  --color-bg-secondary: #0f172a; /* slate-900 */
  --color-bg-tertiary: #1e293b; /* slate-800 */
  --color-bg-elevated: #1e293b; /* slate-800 */
  --color-bg-input: #020617; /* slate-950 */
  --color-border: #334155; /* slate-700 */
  --color-border-subtle: #1e293b; /* slate-800 */
  --color-text-primary: #f1f5f9; /* slate-100 */
  --color-text-secondary: #cbd5e1; /* slate-300 */
  --color-text-tertiary: #94a3b8; /* slate-400 */
  --color-text-muted: #64748b; /* slate-500 */
  --color-grid-dot: #1e293b; /* slate-800 */
  --color-overlay: rgba(2, 6, 23, 0.8);
  --color-edge-default: #475569; /* slate-600 */
  --color-edge-hover: #64748b; /* slate-500 */
  --color-edge-selected: #06b6d4; /* cyan-500 */
}
@layer base {
  html {
    @apply transition-colors duration-200;
  }
  body {
    @apply bg-surface-primary text-txt-primary font-sans overflow-hidden transition-colors duration-200;
  }
}
/* Custom styles for @xyflow/react */
.react-flow__pane {
  background-color: transparent;
}
/* Light mode ReactFlow controls */
.react-flow__controls button {
  background-color: var(--color-bg-secondary) !important;
  border-color: var(--color-border) !important;
  color: var(--color-text-secondary) !important;
  border-bottom: 1px solid var(--color-border) !important;
  transition: all 0.2s;
}
.react-flow__controls button:hover {
  background-color: var(--color-bg-tertiary) !important;
}
.react-flow__minimap {
  background-color: var(--color-bg-secondary) !important;
  border: 1px solid var(--color-border) !important;
}
.react-flow__minimap-mask {
  fill: var(--color-overlay) !important;
}
.react-flow__minimap-node {
  fill: #38bdf8 !important;
}
/* Custom scrollbar */
::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}
::-webkit-scrollbar-track {
  background: var(--color-bg-secondary); 
}
::-webkit-scrollbar-thumb {
  background: var(--color-border); 
  border-radius: 4px;
}
::-webkit-scrollbar-thumb:hover {
  background: var(--color-text-muted); 
}

```
```index.tsx
import "./index.css";
import React from "react";
import { render } from "react-dom";
import { App } from "./App";

render(<App />, document.getElementById("root"));

```
```tailwind.config.js


/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'class',
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
    "./*.{js,ts,jsx,tsx}",
    "./components/**/*.{js,ts,jsx,tsx}"
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
      },
      colors: {
        surface: {
          primary: 'var(--color-bg-primary)',
          secondary: 'var(--color-bg-secondary)',
          tertiary: 'var(--color-bg-tertiary)',
          elevated: 'var(--color-bg-elevated)',
          input: 'var(--color-bg-input)',
        },
        border: {
          DEFAULT: 'var(--color-border)',
          subtle: 'var(--color-border-subtle)',
        },
        txt: {
          primary: 'var(--color-text-primary)',
          secondary: 'var(--color-text-secondary)',
          tertiary: 'var(--color-text-tertiary)',
          muted: 'var(--color-text-muted)',
        }
      },
      animation: {
        'flow': 'flow 2s linear infinite',
      },
      keyframes: {
        flow: {
          '0%': { strokeDashoffset: '24' },
          '100%': { strokeDashoffset: '0' },
        }
      }
    },
  },
  plugins: [],
}


```
