# 다중 페르소나 AI 시스템 — 구현 계획

> 기준 문서: `MultiPersonaWorkflowSketch.html`  
> 기준 브랜치: `feat/addpersona`  
> 작성일: 2026-04-15

---

## 1. 현재 구현 상태 파악

### ✅ 이미 구현된 것

| 항목                                 | 파일                                   | 비고                                           |
| ------------------------------------ | -------------------------------------- | ---------------------------------------------- |
| PersonaRecord 모델                   | `Models/PersonaRecord.swift`           | SwiftData @Model                               |
| PersonaType (5종)                    | `Models/SourceSystem.swift`            | work / academic / medical / finance / personal |
| Apple Health 동기화                  | `Services/HealthKitSyncProvider.swift` | 심박, 수면, 걸음수 등                          |
| 캘린더 동기화                        | `Services/EventKitSyncProvider.swift`  | 이벤트 / 미리알림                              |
| 사진 메타데이터 동기화               | `Services/PhotoKitSyncProvider.swift`  | 최근 20장                                      |
| 에코시스템 통합 오케스트레이터       | `Services/EcosystemSyncService.swift`  | 4개 소스 병렬 동기화                           |
| 멀티 에이전트 토론 (백그라운드 자동) | `Services/DebateOrchestrator.swift`    | health ↔ work 2개 도메인 고정                  |
| 토론 트리거 감지                     | `Services/NodeManagerAgent.swift`      | 7일 패턴 분석                                  |
| 토론 상태 배너 UI                    | `Views/DebateStatusBanner.swift`       | 진행 중 표시                                   |
| 토론 결과 패널 UI                    | `Views/DebateStatusBanner.swift`       | 결과 요약 카드                                 |
| 텍스트·파일 입력 모달                | `Views/SmartInputModalView.swift`      | PDF / txt / 이미지                             |
| 페르소나 온보딩                      | `Views/PersonaOnboardingView.swift`    | 최초 선택 화면                                 |
| 그래프 캔버스                        | `Views/GraphCanvasView.swift`          | 노드/엣지 인터랙션                             |
| Context / Origin / Timeline 뷰       | `Views/`                               | 3개 뷰 모드                                    |

### ❌ 스케치 기준 미구현 항목

| 항목                          | 스케치 위치         | 비고                                                                        |
| ----------------------------- | ------------------- | --------------------------------------------------------------------------- |
| 페르소나 타입 미스매치        | ③ 페르소나 에이전트 | 스케치: 건강/학업/금융/취미 vs 현재: work/academic/medical/finance/personal |
| 스크린타임 데이터 소스        | ① 데이터 소스       | FamilyControls API 필요 또는 대체 방안                                      |
| Apple Pay / 금융 데이터 소스  | ① 데이터 소스       | Wallet API 없음 → 수동 입력 또는 PDF 파싱                                   |
| 음성 입력                     | ① 데이터 소스       | Speech framework 미적용                                                     |
| 라우터 에이전트               | ② LLM 분석 엔진     | 페르소나 자동 선택 로직 없음                                                |
| 채팅 진입 전 페르소나 선택 UI | ④ Step A            | 별도 채팅 화면 없음                                                         |
| 고민 입력 채팅 인터페이스     | ④ Step B            | SmartInputModal은 지식 추가 전용                                            |
| 실시간 토론 버블 시각화       | ④ Step C            | 토론 진행 중 대화 UI 없음                                                   |
| 토론 결과 선택지 카드 UI      | ④ Step D            | 현재 결과는 JSON 파싱 요약만                                                |
| 1:1 페르소나 채팅 (토론 후)   | ④ Step E            | 단일 페르소나 대화 기능 없음                                                |
| 자율 토론 후 OS 알림          | 자율 토론 모드      | UserNotifications 미연동                                                    |
| 임의 페르소나 조합 토론       | 자율 토론 모드      | 현재 health+work 조합 고정                                                  |
| 페르소나 간 Tension 시각화    | ③ blob 시각화       | 그래프에서 도메인 간 연결 강조 없음                                         |
| 금융 페르소나 컨텍스트 주입   | ② LLM 분석 엔진     | finance 페르소나가 데이터 미연동                                            |

---

## 2. 단계별 구현 계획

---

### Phase 1 — 페르소나 타입 정렬 및 데이터 모델 확장 (완료)

> **목표**: 스케치의 4개 페르소나(건강/학업/금융/취미)에 맞게 기반 모델을 정비한다.

#### 1-1. `PersonaType` 수정 (`Models/SourceSystem.swift`) (완료)

- `medical` → `health` (rawValue: `"Health"`)로 변경, `localizedName` = `"건강"`
- `personal` → `hobby` (rawValue: `"Hobby"`)로 변경, `localizedName` = `"취미"`
- `work` 유지 → `localizedName` = `"업무"` (학업 보조 용도로 남김)
- 각 페르소나 색상 체계를 스케치와 동일하게 맞춤
  - 건강: `#1D9E75` (teal)
  - 학업: `#7F77DD` (purple)
  - 금융: `#EF9F27` (amber)
  - 취미: `#D85A30` (coral)
- `relevantHealthTypes` 내 `medical` → `health` 케이스 대응
- `EventKitSyncProvider.filteredCalendars(for:)` 내 `medical` → `health` 케이스 대응
- **주의**: `MigrationService`에 rawValue 마이그레이션 로직 추가 (`"Medical"` → `"Health"`, `"Personal"` → `"Hobby"`)

#### 1-2. `SourceSystem` 확장 (`Models/SourceSystem.swift`) (완료)

- `screenTime` 케이스 추가
- `finance` 케이스 추가 (수동 입력/파싱 기반)

#### 1-3. `ChatRecord` 모델 신규 추가 (`Models/ChatRecord.swift`) (완료)

```
@Model ChatSession
  - id: String
  - title: String
  - selectedPersonaTypes: [String]   // PersonaType rawValues
  - createdAt: Date
  - linkedDebateRecordID: String?
  - messages: [ChatMessage]          // SwiftData에서는 @Relationship
```

```
@Model ChatMessage
  - id: String
  - sessionID: String
  - role: String           // "user" | "persona" | "system"
  - personaTypeRaw: String?
  - content: String
  - timestamp: Date
```

- `ModelContainer` 등록 목록에 `ChatSession.self`, `ChatMessage.self` 추가 (`MemoAgentApp.swift`)

#### 1-4. `FinanceEntry` 모델 신규 추가 (`Models/FinanceEntry.swift`) (완료)

```
@Model FinanceEntry
  - id: String
  - amount: Double
  - category: String
  - note: String
  - date: Date
  - sourceRaw: String     // "manual" | "pdf" | "text"
```

- Apple Pay API는 공개 접근 불가이므로 수동 입력 + PDF 명세서 파싱 방식 채택

---

### Phase 2 — 데이터 소스 확장 (완료)

> **목표**: 스크린타임·금융 데이터를 추가하고 기존 에코시스템 동기화를 금융/취미 페르소나에 연결한다.

#### 2-1. `ScreenTimeSyncProvider` 신규 추가 (`Services/ScreenTimeSyncProvider.swift`) (완료)

- **방식 A**: `DeviceActivity` (FamilyControls) — iOS 전용, macOS 제한적
- **방식 B (채택)**: `UsageReportParser` — 스크린타임 주간 리포트 텍스트 직접 파싱
  - `SmartInputModalView`에 "스크린타임 리포트 붙여넣기" 탭 추가
  - 파싱된 데이터 → `NodeRecord` (type: `.healthMetric`, source: `.screenTime`) 저장
- `EcosystemSyncService`에 `syncScreenTime(persona:viewModel:)` 함수 추가
- `건강(health)` 페르소나에 스크린타임 컨텍스트 주입

#### 2-2. `FinanceSyncProvider` 신규 추가 (`Services/FinanceSyncProvider.swift`) (완료)

- **방식**: 사용자가 카드 명세서 PDF / 텍스트 붙여넣기 → 파싱
  - `SmartInputModalView`에 "지출 내역 추가" 탭 추가
  - LLM 또는 정규식 파싱으로 날짜·금액·카테고리 추출
  - 추출 결과 → `FinanceEntry` + `NodeRecord` (type: `.memo`, source: `.finance`) 저장
- `EcosystemSyncService`에 `syncFinance(persona:viewModel:)` 함수 추가
- `금융(finance)` 페르소나의 `systemPromptContext`에 현재 예산 요약 동적 주입

#### 2-3. `PhotoKitSyncProvider` 취미 페르소나 연결 (완료)

- `filteredPhotos(for:)` 함수 — `hobby` 페르소나 시 전체 앨범 접근, 위치·시간 메타데이터 강조

---

### Phase 3 — 라우터 에이전트 구현 (완료)

> **목표**: 사용자 입력을 분석해 관련 페르소나를 자동 선택하는 라우터를 만든다.

#### 3-1. `PersonaRouter` 서비스 신규 추가 (`Services/PersonaRouter.swift`) (완료)

```swift
actor PersonaRouter {
    // 입력 텍스트 → 관련 PersonaType 배열 반환 (복수 가능)
    func route(query: String, availablePersonas: [PersonaRecord]) async -> [PersonaType]
}
```

- Apple Intelligence 가능 시: `LanguageModelSession` 활용
- 폴백: 키워드 매핑 (예: "예산", "지출" → finance / "수면", "운동" → health)
- `GraphViewModel`에 `suggestedPersonas: [PersonaType]` 프로퍼티 추가

#### 3-2. 데이터 노드 임계값 기반 자동 페르소나 분화 (완료)

- `NodeManagerAgent.run(context:viewModel:)` 내부에 임계값 체크 로직 추가
  - 페르소나별 노드 수 ≥ 10 → 해당 페르소나가 없으면 자동 생성 제안 (배너 알림)
- `GraphViewModel`에 `pendingPersonaSuggestion: PersonaType?` 프로퍼티 추가

---

### Phase 4 — 채팅 인터페이스 구현 (완료)

> **목표**: 스케치 Step A~B에 해당하는 "고민 던지기" 채팅 화면과 Step E의 1:1 페르소나 채팅을 구현한다.

#### 4-1. `MultiPersonaChatView` 신규 추가 (`Views/MultiPersonaChatView.swift`) (완료)

- **레이아웃**: 2단 구성
  - 좌측: 페르소나 선택 패널 (현재 활성 페르소나 카드 + 토글)
  - 우측: 텍스트 입력 + 전송 버튼
- **Step A**: 진입 시 PersonaRouter가 활성 페르소나를 자동 추천, 사용자가 추가/제거 가능
- **Step B**: 사용자 입력 → `ChatSession` 생성 → 선택된 페르소나들에게 컨텍스트와 함께 전달
- "토론 시작" 버튼 → `DebateOrchestrator.startDebate()` 수동 트리거 (아래 5-1과 연동)
- `ContentView` 툴바에 채팅 진입 버튼 추가 (`ToolbarContent.swift`)

#### 4-2. `GraphViewModel` 채팅 연동 (완료)

```swift
// GraphViewModel에 추가
var activeChatSession: ChatSession? = nil
func startChatSession(query: String, personas: [PersonaType]) async
func sendChatMessage(_ text: String, asPersona: PersonaType?) async
```

- `ChatSession`, `ChatMessage` SwiftData CRUD 메서드 추가

#### 4-3. `SinglePersonaChatView` 신규 추가 (`Views/SinglePersonaChatView.swift`) (완료)

- 스케치 Step E: 토론 완료 후 특정 페르소나와 1:1 대화
- 헤더에 선택 페르소나 색상/아이콘 표시
- 해당 페르소나의 `systemPromptContext` + 도메인 노드 컨텍스트를 LLM 프롬프트에 주입
- `DebateResultPanel` 하단 "금융 페르소나와 계속 →" 버튼에서 진입

---

### Phase 5 — 토론 시스템 개선 (완료)

> **목표**: 자동 트리거에만 의존하던 토론 시스템을 사용자 직접 트리거·실시간 시각화·임의 페르소나 조합으로 확장한다.

#### 5-1. `DebateOrchestrator` 수동 트리거 경로 추가 (완료)

- `DebateTrigger`에 `selectedPersonaTypes: [PersonaType]` 필드 추가
- `startDebate(trigger:)` 함수 오버로드: 사용자가 선택한 페르소나 조합으로 토론 가능
- `SpecialistRole` 열거형 확장: `health`, `work` 외에 `finance`, `hobby`, `academic` 추가
  - 각 role에 해당 `systemPrompt`, `rebuttalPrompt` 작성

#### 5-2. 실시간 토론 시각화 (`LiveDebateView`) 신규 추가 (`Views/LiveDebateView.swift`) (완료)

- 스케치 Step C: 채팅 버블 형태 실시간 대화 표시
- `DebateOrchestrator`에 `onTurnCompleted: ((AgentTurn) -> Void)?` 콜백 추가
  - 각 라운드 턴이 완료될 때마다 MainActor에서 콜백 호출
- `GraphViewModel`에 `liveDebateTurns: [AgentTurn]` 프로퍼티 추가
- 각 AgentTurn을 페르소나 색상 버블로 렌더링
- 좌(건강/학업) / 우(금융/취미) 배치 — 스케치 bubble-row 구조

#### 5-3. `DebateResultPanel` 개선 (완료)

- 스케치 Step D: "결론이 아닌 선택지" 형태 강조
- 각 페르소나의 입장 요약을 별도 카드로 분리 (현재는 rootCause 하나만)
- 하단에 "○○ 페르소나와 계속 대화 →" 버튼 추가 (Phase 4-3 연동)
- 긴급도 배지 유지

---

### Phase 6 — 자율 토론 모드 완성 (완료)

> **목표**: 백그라운드 자율 토론 완료 시 macOS 알림을 보내고, 스케줄 기반 분석을 추가한다.

#### 6-1. `UserNotifications` 연동 (`MemoAgentApp.swift` / `Services/NotificationService.swift`) (완료)

- `NotificationService` 신규 추가
  ```swift
  final class NotificationService {
      static let shared = NotificationService()
      func requestPermission() async
      func sendDebateCompletionNotification(summary: String)
  }
  ```
- `MemoAgentApp.applicationDidFinishLaunching`에서 권한 요청
- `DebateOrchestrator.startDebate()` 완료 시 `NotificationService.sendDebateCompletionNotification()` 호출

#### 6-2. 패턴 감지 조건 확장 (`Services/NodeManagerAgent.swift`) (완료)

- 현재: health ↔ work 조합만 감지
- 추가: finance ↔ hobby, health ↔ finance 등 조합별 패턴 시그니처 정의
- `detectCrossDomainPattern(context:)` 함수에 다중 도메인 패턴 케이스 추가

#### 6-3. 스케줄 기반 자율 분석 (`Services/NodeManagerAgent.swift`) (완료)

- 매일 오전 8시 분석 실행 (BackgroundTask 또는 앱 포그라운드 진입 시 시간 체크)
- 주간 페르소나 인사이트 노드 자동 생성 (현재 `runPatternDetectionIfNeeded` 임계값 24시간 → 조정 가능)

---

### Phase 7 — UI/UX 개선 (완료)

> **목표**: 스케치의 시각 언어(색상 체계, 필터, Tension 시각화)를 앱 전반에 적용한다.

#### 7-1. 페르소나 필터 색상 체계 통일 (`Views/LeftSidebarView.swift`) (완료)

- 현재 cyan/violet/rose/green/amber 색상 → 스케치 4색 체계로 변경
  - teal(`#1D9E75`), purple(`#7F77DD`), amber(`#EF9F27`), coral(`#D85A30`)
- 사이드바 필터 섹션에 페르소나 색상 도트 + 이름 표시 (스케치 Filter 섹션 구조)
- 필터 토글 시 해당 페르소나 노드만 캔버스에 표시

#### 7-2. 페르소나 간 Tension 시각화 (`Views/EdgeLayerView.swift`) (완료)

- 서로 다른 페르소나 소속 노드를 연결하는 엣지: 점선 스타일 + 페르소나 컬러 그라디언트
- 캔버스 상단에 현재 활성 페르소나들의 blob 미니 시각화 (스케치 SVG 참조)
  - `GraphCanvasView` 오버레이로 페르소나 타원 4개를 반투명하게 표시

#### 7-3. `ContentView` 진입점 정비 (`ContentView.swift` / `ToolbarContent.swift`) (완료)

- 툴바에 "💬 페르소나 채팅" 버튼 추가 → `MultiPersonaChatView` 시트 표시
- 자율 토론 진행 중 상태 배너 위치를 중앙 상단으로 조정 (현재 위치 확인 필요)

---

## 3. 구현 우선순위 요약

| 우선순위 | Phase          | 핵심 이유                                    |
| -------- | -------------- | -------------------------------------------- |
| 🔴 즉시  | Phase 1        | PersonaType 미스매치가 이후 모든 기능에 영향 |
| 🔴 즉시  | Phase 4-1, 4-2 | 스케치의 핵심 사용자 흐름 (Step A·B)         |
| 🟠 단기  | Phase 5-1, 5-2 | 토론 UX 완성 (Step C)                        |
| 🟠 단기  | Phase 5-3, 4-3 | 결과 공유 및 1:1 채팅 (Step D·E)             |
| 🟡 중기  | Phase 3        | 라우터 에이전트 (자동화 품질 향상)           |
| 🟡 중기  | Phase 2        | 금융·스크린타임 데이터 소스                  |
| 🟢 장기  | Phase 6        | 자율 토론 완성도 및 알림                     |
| 🟢 장기  | Phase 7        | 시각 개선 (기능 완성 후)                     |

---

## 4. 파일 변경 영향도 요약

| 파일                                    | 변경 유형                             | 관련 Phase |
| --------------------------------------- | ------------------------------------- | ---------- |
| `Models/SourceSystem.swift`             | 수정 (PersonaType 케이스 변경 + 색상) | 1-1, 1-2   |
| `Services/MigrationService.swift`       | 수정 (rawValue 마이그레이션 추가)     | 1-1        |
| `Models/ChatRecord.swift`               | **신규**                              | 1-3        |
| `Models/FinanceEntry.swift`             | **신규**                              | 1-4        |
| `MemoAgentApp.swift`                    | 수정 (ModelContainer 등록 추가)       | 1-3, 1-4   |
| `Services/ScreenTimeSyncProvider.swift` | **신규**                              | 2-1        |
| `Services/FinanceSyncProvider.swift`    | **신규**                              | 2-2        |
| `Services/EcosystemSyncService.swift`   | 수정 (동기화 소스 추가)               | 2-1, 2-2   |
| `Services/PersonaRouter.swift`          | **신규**                              | 3-1        |
| `Services/NodeManagerAgent.swift`       | 수정 (임계값 분화, 패턴 조건 확장)    | 3-2, 6-2   |

| `Services/DebateOr
chestrator.swift` | 수정 (수동 트리거, 다중 페르소나, 콜백) | 5-1, 5-2 |
| `Services/NotificationService.swift` | **신규** | 6-1 |
| `ViewModels/GraphViewModel.swift` | 수정 (채팅 세션, 라우터 연동, live turns) | 4-2, 5-2 |
| `Views/MultiPersonaChatView.swift` | **신규** | 4-1 |
| `Views/SinglePersonaChatView.swift` | **신규** | 4-3 |
| `Views/LiveDebateView.swift` | **신규** | 5-2 |
| `Views/DebateStatusBanner.swift` | 수정 (결과 패널 개선, 1:1 진입 버튼) | 5-3 |
| `Views/LeftSidebarView.swift` | 수정 (필터 색상 체계 변경) | 7-1 |
| `Views/EdgeLayerView.swift` | 수정 (크로스 페르소나 엣지 스타일) | 7-2 |
| `Views/GraphCanvasView.swift` | 수정 (blob 오버레이 추가) | 7-2 |
| `Views/ToolbarContent.swift` | 수정 (채팅 버튼 추가) | 7-3 |
| `Views/SmartInputModalView.swift` | 수정 (스크린타임/금융 입력 탭) | 2-1, 2-2 |
| `Views/PersonaOnboardingView.swift` | 수정 (새 PersonaType 반영) | 1-1 |
