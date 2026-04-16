# Project: Persona-Node Integration

## 📌 Metadata
- **Last Updated:** 2026-04-16 (updated)
- **Current Sprint:** 
- **Target Files:** 

## 📋 Task Backlog
| ID   | Status    | Priority | Task Description                                                                                                                      | Target Files                                                                                                                                                                               |
| :--- | :-------- | :------: | :------------------------------------------------------------------------------------------------------------------------------------ | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | `Done`    |   High   | 노드별 담당 페르소나 명시 및 시각화 기능 추가                                                                                         | NodeCardView.swift, GraphCanvasView.swift                                                                                                                                                  |
| 1A   | `Done`    |   Low    | 단일 노드 내 다중 페르소나 공유 로직 구현                                                                                             | GraphNode.swift, NodeRecord.swift, GraphViewModel.swift, NodeCardView.swift, DetailInspectorView.swift, GraphCanvasView.swift, EdgeLayerView.swift, LeftSidebarView.swift, +sync providers |
| 1B   | `Done`    |   High   | 노드별 담당 페르소나 사용자 수동 지정 기능 추가                                                                                       | DetailInspectorView.swift, GraphViewModel.swift                                                                                                                                            |
| 2    | `Done`    |   Med    | 페르소나 사용자 수동 추가/수정/삭제 기능 구현                                                                                         | LeftSidebarView.swift, PersonaEditSheet.swift, GraphViewModel.swift                                                                                                                        |
| 3    | `Done`    |   Med    | 데이터 추가 시 담당 페르소나 사용자 수동 지정 기능 추가                                                                               | SmartInputModalView.swift, GraphViewModel.swift                                                                                                                                            |
| 4    | `Pending` | Critical | 노드별 담당 페르소나 선택 시 체크 표시가 제대로 표시되지 않는 오류 수정                                                               |
| 5    | `Pending` |   Med    | 페르소나 유형에 "기타" 추가                                                                                                           |
| 6    | `Pending` |   High   | 유형별로 한 개의 페르소나만 만들 수 있는 제약 해제 (ex: "취미" 유형의 페르소나로 "포켓몬스터", "넷플릭스" 등을 각각 추가할 수 있도록) |

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