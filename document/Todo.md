# Project: Persona-Node Integration

## 📌 Metadata
- **Last Updated:** 2026-04-16 (updated)
- **Current Sprint:** 
- **Target Files:** 

## 📋 Task Backlog
| ID   | Status    | Priority | Task Description                                                                                                                      | Target Files                                                                                                                                                                                                  |
| :--- | :-------- | :------: | :------------------------------------------------------------------------------------------------------------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1    | `Done`    |   High   | 노드별 담당 페르소나 명시 및 시각화 기능 추가                                                                                         | NodeCardView.swift, GraphCanvasView.swift                                                                                                                                                                     |
| 1A   | `Done`    |   Low    | 단일 노드 내 다중 페르소나 공유 로직 구현                                                                                             | GraphNode.swift, NodeRecord.swift, GraphViewModel.swift, NodeCardView.swift, DetailInspectorView.swift, GraphCanvasView.swift, EdgeLayerView.swift, LeftSidebarView.swift, +sync providers                    |
| 1B   | `Done`    |   High   | 노드별 담당 페르소나 사용자 수동 지정 기능 추가                                                                                       | DetailInspectorView.swift, GraphViewModel.swift                                                                                                                                                               |
| 2    | `Done`    |   Med    | 페르소나 사용자 수동 추가/수정/삭제 기능 구현                                                                                         | LeftSidebarView.swift, PersonaEditSheet.swift, GraphViewModel.swift                                                                                                                                           |
| 3    | `Done`    |   Med    | 데이터 추가 시 담당 페르소나 사용자 수동 지정 기능 추가                                                                               | SmartInputModalView.swift, GraphViewModel.swift                                                                                                                                                               |
| 4    | `Done`    | Critical | 노드별 상세 정보 UI에서 담당 페르소나 선택 시 체크박스 내 체크 표시가 제대로 표시되지 않는 오류 수정                                  | GraphViewModel.swift, DetailInspectorView.swift                                                                                                                                                               |
| 5    | `Done`    |   Med    | 페르소나 유형에 "기타" 추가                                                                                                           | SourceSystem.swift                                                                                                                                                                                            |
| 6    | `Done`    |   High   | 유형별로 한 개의 페르소나만 만들 수 있는 제약 해제 (ex: "취미" 유형의 페르소나로 "포켓몬스터", "넷플릭스" 등을 각각 추가할 수 있도록) | PersonaEditSheet.swift                                                                                                                                                                                        |
| 7    | `Done`    |   High   | 프로그램이 LLM을 호출할 때 사용하는 프롬프트들을 /MemoAgent/MemoAgent/Assets/prompts.json으로 이동하기                                | Assets/prompts.json, Services/PromptStore.swift, SourceSystem.swift, DebateOrchestrator.swift, NodeManagerAgent.swift, PersonaRouter.swift, AIProviderManager.swift, GraphViewModel.swift, SettingsView.swift |
| 8    | `Done`    |   Med    | 고민 대화창에서 참여 페르소나 목록에 페르소나 분류가 아니라 이름이 뜨도록 수정                                                        | MultiPersonaChatView.swift                                                                                                                                                                                    |
| 9    | `Done`    |   High   | 고민 대화창에서 페르소나 하나를 선택하면 같은 분류의 페르소나가 모두 선택되는 현상 수정                                               | MultiPersonaChatView.swift, GraphViewModel.swift                                                                                                                                                              |
| 10   | `Done`    | Critical | 지식 입력 창 우측 상단의 X 버튼을 누르면 노드마인드 프로그램 윈도우가 통째로 닫히는 현상 수정                                         | SmartInputModalView.swift                                                                                                                                                                                     |
| 11   | `Done`    |   Med    | 컨텍스트 뷰에서 특정 페르소나의 담당 노드만을 보기로 선택했을 때 담당 페르소나가 없는 노드도 보이는 현상 수정                         | GraphViewModel.swift                                                                                                                                                                                          |
| 12   | `Done`    |   High   | 사용자가 페르소나를 지정하지 않았을 때 새로 생성되는 노드의 페르소나가 자동 지정되지 않는 현상 수정                                   | GraphViewModel.swift                                                                                                                                                                                          |
| 13   | `Done`    |   High   | 새로운 노드가 기존의 관련 노드와 곧바로 연결되지 않는 현상 수정                                                                       | GraphViewModel.swift                                                                                                                                                                                          |
| 14   | `Done`    |   Med    | 새로운 Edge에 관계 설명이 자동으로 작성되지 않는 현상 수정                                                                            | GraphViewModel.swift, Assets/prompts.json, Services/PromptStore.swift                                                                                                                                         |
| 15   | `Done`    |   High   | 고민/질문을 던졌을 때 선택된 페르소나들이 각자 자기 할 말만 하고 페르소나끼리의 토론을 하지는 않는 현상 수정                          | GraphViewModel.swift, Assets/prompts.json, Services/PromptStore.swift                                                                                                                                         |
| 16   | `Done`    |   High   | prompts.json을 yaml로 변경                                                                                                            | Assets/prompts.json, Services/PromptStore.swift, SourceSystem.swift, DebateOrchestrator.swift, NodeManagerAgent.swift, PersonaRouter.swift, AIProviderManager.swift, GraphViewModel.swift, SettingsView.swift |

---

## 🛠 Technical Requirements

---

## 📜 History
- **2026-04-16:** Initial backlog created by User.
- **2026-04-16:** Task 1, 1B 완료 — 노드 카드 페르소나 시각화(하단 좌측 컬러 dot) + 인스펙터 페르소나 수동 지정 메뉴 구현.
- **2026-04-16:** Task 2 완료 — PersonaEditSheet(추가/이름변경) + LeftSidebarView 헤더 "+" 버튼 + 우클릭 컨텍스트 메뉴(이름 변경/삭제) 구현.
- **2026-04-16:** Task 3 완료 — SmartInputModal 좌측 컬럼 하단 페르소나 피커 추가, commitModalNodes/commitScreenTimeReport/commitFinanceStatement에 수동 지정 반영.
- **2026-04-16:** Task 1A 완료 — personaID: String? → personaIDs: [String] 전환. NodeRecord 구버전 호환 유지, GraphNode Codable 레거시 폴백, VM add/removePersona 추가, Inspector 다중 선택 토글 UI, NodeCard 다중 dot 시각화.
- **2026-04-16:** Task 4, 5, 6 추가
- **2026-04-16:** Task 4 완료 — @Observable 중첩 변이 미감지 버그 수정. assignPersona/addPersona/removePersona/deletePersona에서 nodes[idx] 직접 교체 패턴 적용. DetailInspectorView에서 isAssigned를 vm.nodes에서 직접 조회하도록 변경.
- **2026-04-16:** Task 5 완료 — PersonaType에 .other("기타") 케이스 추가. icon: ellipsis.circle.fill, accentHex: #64748b.
- **2026-04-16:** Task 6 완료 — PersonaEditSheet에서 alreadyExists 제약 제거. 같은 유형 이미 존재 시 이름 입력 필수, 배지를 "추가됨" → 기존 개수 표시로 변경. 그리드 2열→3열.
- **2026-04-20:** Task 10 완료 — SmartInputModalView X 버튼에서 dismiss() 제거. 뷰가 .sheet가 아닌 .overlay로 표시되므로 dismiss()가 환경 체인을 타고 올라가 윈도우를 닫는 원인이었음. vm.isAddModalPresented = false만으로 충분.
- **2026-04-20:** Task 8, 9 완료 — chatSelectedPersonaTypes: Set<PersonaType> → chatSelectedPersonaIDs: Set<String>으로 전환. 이제 페르소나 개별 ID로 선택 상태를 관리하므로 같은 유형 페르소나들이 독립적으로 선택됨. 페르소나 카드에 유형명 대신 persona.name 표시.
- **2026-04-20:** Task 7 완료 — Assets/prompts.json 생성 (22개 프롬프트), Services/PromptStore.swift 추가. Swift 소스 8개 파일의 모든 LLM 프롬프트 리터럴을 PromptStore 호출로 교체. 동적 치환이 필요한 템플릿({personaName}, {domainLabel})은 prompt(for:replacing:with:) 메서드로 처리.
- **2026-04-20:** Task 12 완료 — commitModalNodes()에서 modalSelectedPersonaID가 nil일 때 activePersona → personas.first 순으로 폴백하여 자동 지정.
- **2026-04-20:** Task 13, 14 완료 — autoLinkToExisting(): 태그 겹침 기반으로 새 노드를 기존 관련 노드 최대 2개에 자동 연결, 공유 태그를 레이블로 사용. generateEdgeRelationship(): 사용자가 수동으로 Edge 생성 시 비동기 LLM 호출로 2~4단어 한국어 관계 설명 자동 생성 후 업데이트.
- **2026-04-20:** Task 15 완료 — generatePersonaResponses()를 2라운드 구조로 재편. Round 1: 각 페르소나가 독립적으로 병렬 응답. Round 2(2개 이상 선택 시): 각 페르소나가 다른 페르소나들의 Round 1 응답을 읽고 반응·반론·보완. persona_cross_response 프롬프트 추가.
- **2026-04-20:** Task 11 완료 — visibleNodes에서 isGlobal(personaIDs.isEmpty) 조건 제거. 페르소나 필터 활성화 시 해당 페르소나에 명시적으로 지정된 노드만 표시하도록 수정.
- **2026-04-20:** Task 16 완료 — Assets/prompts.yaml 생성. 모든 프롬프트를 | 블록 스칼라 형식으로 변환 (섹션별 주석 포함). PromptStore.swift의 JSONDecoder 로직을 자체 구현 YAML 파서로 교체 (외부 의존성 없음). prompts.json은 번들에 유지되나 더 이상 로드되지 않음.