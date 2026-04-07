// SampleData.swift
// MemoAgent — Phase 1: Mock Data
//
// A 1-to-1 port of data/sampleNodes.ts.
// All Korean strings are preserved verbatim.
// Positions are taken directly from the React source.

import Foundation

// MARK: - Sample Nodes

let sampleNodes: [GraphNode] = [
    GraphNode(
        id: "1",
        title: "PKM 시스템 설계 원칙",
        summary: "개인 지식 관리 시스템은 정보의 수집보다 연결과 검색에 초점을 맞춰야 한다. 인지 부하를 줄이는 UI가 핵심.",
        type: .memo,
        date: "2023-10-24",
        originalText: "최근 제텔카스텐과 세컨드 브레인 방법론을 공부하면서 느낀 점은, 결국 도구보다 프로세스가 중요하다는 것이다. 하지만 좋은 도구는 그 프로세스를 마찰 없이 실행하게 해준다. PKM 시스템 설계 시 가장 중요한 원칙은 정보의 단순한 축적이 아니라, 정보 간의 유기적인 연결을 돕고 필요할 때 즉시 꺼내 쓸 수 있는 검색성을 확보하는 것이다. 특히 시각적인 그래프 뷰는 뇌의 연상 작용을 모방하여 직관적인 탐색을 돕는다.",
        isImportant: true,
        tags: ["PKM", "설계원칙", "UI/UX"],
        position: CGPoint(x: 0, y: 0)
    ),
    GraphNode(
        id: "2",
        title: "제텔카스텐 방법론 요약",
        summary: "독일의 사회학자 니클라스 루만이 고안한 메모 상자 기법. 원자화된 메모와 상호 연결이 특징.",
        type: .pdf,
        date: "2023-10-20",
        originalText: "[PDF 발췌] 제텔카스텐(Zettelkasten)은 독일어로 \"메모 상자\"를 뜻한다. 이 시스템의 핵심은 각 메모가 하나의 독립적인 아이디어(원자성)를 담고 있으며, 메모들끼리 고유 번호를 통해 거미줄처럼 연결된다는 점이다. 이를 통해 예상치 못한 아이디어의 결합을 유도하고 창의적인 글쓰기를 가능하게 한다.",
        isImportant: false,
        tags: ["제텔카스텐", "메모법", "루만"],
        position: CGPoint(x: 250, y: -100)
    ),
    GraphNode(
        id: "3",
        title: "AI 기반 지식 추출 프롬프트",
        summary: "긴 텍스트에서 핵심 개념과 엔티티를 추출하여 JSON 형태로 반환하도록 지시하는 프롬프트 템플릿.",
        type: .chat,
        date: "2023-10-25",
        originalText: "User: 다음 텍스트에서 주요 개념, 인물, 날짜를 추출하고 이들 간의 관계를 JSON 배열로 만들어줘.\n\nAI: 네, 요청하신 텍스트를 분석하여 다음과 같은 JSON 구조로 추출했습니다.\n```json\n{\n  \"entities\": [...],\n  \"relationships\": [...]\n}\n```\n이 구조를 활용하면 지식 그래프의 노드와 엣지를 자동 생성하는 데 유용할 것입니다.",
        isImportant: true,
        tags: ["프롬프트", "NER", "JSON"],
        position: CGPoint(x: -200, y: 150)
    ),
    GraphNode(
        id: "4",
        title: "인지 부하 최소화 UI/UX",
        summary: "복잡한 데이터를 다룰 때 사용자의 피로도를 줄이기 위한 다크 모드, 점진적 정보 공개(Progressive Disclosure) 기법.",
        type: .memo,
        date: "2023-10-26",
        originalText: "데이터 밀도가 높은 애플리케이션 화면을 설계할 때는 인지 부하 관리가 최우선이다. 한 번에 모든 정보를 보여주기보다는, 사용자의 상호작용(Hover, Click)에 따라 점진적으로 상세 정보를 노출하는 Progressive Disclosure 패턴을 적극 활용해야 한다. 또한 다크 모드는 장시간 화면을 보는 사용자의 눈 피로를 덜어주고, 데이터 시각화 요소(차트, 그래프 노드)의 색상을 더 선명하게 대비시키는 효과가 있다.",
        isImportant: false,
        tags: ["인지부하", "다크모드", "Progressive Disclosure"],
        position: CGPoint(x: 300, y: 150)
    ),
    GraphNode(
        id: "5",
        title: "세컨드 브레인 구축기",
        summary: "옵시디언을 활용한 나만의 세컨드 브레인 구축 경험담. 폴더 구조보다 태그와 링크 위주의 정리.",
        type: .diary,
        date: "2023-10-22",
        originalText: "오늘은 주말을 맞아 옵시디언 볼트를 대대적으로 정리했다. 기존의 복잡한 폴더 계층 구조를 과감히 버리고, PARA(Projects, Areas, Resources, Archives) 방법론을 느슨하게 적용했다. 대신 태그와 백링크를 적극적으로 활용하여 정보가 자연스럽게 연결되도록 유도했다. 아직 익숙해지려면 시간이 필요하겠지만, 정보를 찾는 속도가 훨씬 빨라진 느낌이다.",
        isImportant: false,
        tags: ["옵시디언", "PARA", "세컨드브레인"],
        position: CGPoint(x: 500, y: 0)
    ),
    GraphNode(
        id: "6",
        title: "LLM 컨텍스트 윈도우 한계",
        summary: "현재 LLM의 컨텍스트 윈도우 제한으로 인해 대규모 지식 베이스를 한 번에 처리하기 어려움. RAG 도입 필요.",
        type: .pdf,
        date: "2023-10-21",
        originalText: "[논문 리뷰] 대규모 언어 모델(LLM)은 놀라운 성능을 보이지만, 입력받을 수 있는 토큰 수(Context Window)에 제한이 있다. 따라서 방대한 개인 지식 베이스 전체를 프롬프트에 넣는 것은 불가능하다. 이를 해결하기 위해 검색 증강 생성(RAG, Retrieval-Augmented Generation) 기술이 필수적이다. 사용자의 질문과 관련된 문서 조각(Chunk)만 벡터 DB에서 검색하여 프롬프트에 주입하는 방식이다.",
        isImportant: false,
        tags: ["LLM", "컨텍스트윈도우", "RAG"],
        position: CGPoint(x: -150, y: -200)
    ),
    GraphNode(
        id: "7",
        title: "RAG 아키텍처 초안",
        summary: "문서 임베딩, 벡터 스토어(Pinecone), 시맨틱 검색을 결합한 RAG 시스템 파이프라인 설계.",
        type: .memo,
        date: "2023-10-26",
        originalText: "RAG 파이프라인 설계 초안:\n1. 데이터 수집: 노션, PDF, 로컬 마크다운 파일\n2. 청킹(Chunking): 의미 단위로 텍스트 분할 (약 500~1000 토큰)\n3. 임베딩: OpenAI text-embedding-3-small 모델 사용\n4. 저장: Pinecone 벡터 데이터베이스\n5. 검색: 사용자 쿼리 임베딩 후 코사인 유사도 기반 Top-K 검색\n6. 생성: 검색된 컨텍스트를 LLM에 주입하여 답변 생성",
        isImportant: true,
        tags: ["RAG", "임베딩", "Pinecone"],
        position: CGPoint(x: -350, y: -50)
    ),
    GraphNode(
        id: "8",
        title: "Framer Motion 애니메이션 팁",
        summary: "React에서 자연스러운 UI 트랜지션을 구현하기 위한 Framer Motion의 spring 애니메이션 설정값.",
        type: .memo,
        date: "2023-10-27",
        originalText: "UI 애니메이션은 너무 빠르지도, 너무 느리지도 않아야 한다. Framer Motion에서 가장 자연스러운 느낌을 주는 spring 설정은 보통 stiffness: 300, damping: 30 정도이다. 모달이 뜰 때나 사이드바가 열릴 때 이 값을 기본으로 사용하고, 상황에 따라 미세 조정하는 것이 좋다. 특히 layout 애니메이션을 활용하면 리스트 아이템이 추가/삭제될 때 주변 요소들이 부드럽게 밀려나는 효과를 쉽게 구현할 수 있다.",
        isImportant: false,
        tags: ["Framer Motion", "애니메이션", "React"],
        position: CGPoint(x: 100, y: 250)
    ),
    GraphNode(
        id: "9",
        title: "벡터 DB 비교 분석",
        summary: "Pinecone, Milvus, Qdrant, ChromaDB 등 주요 벡터 데이터베이스의 장단점 및 가격 비교.",
        type: .pdf,
        date: "2023-10-18",
        originalText: "[리포트 요약]\n- Pinecone: 완전 관리형 SaaS, 설정이 쉽지만 비용이 다소 높음.\n- Milvus: 오픈소스, 대규모 스케일링에 적합, 운영 복잡도 높음.\n- Qdrant: Rust 기반, 빠르고 가벼움, 로컬 및 클라우드 지원.\n- ChromaDB: 로컬 개발 및 프로토타이핑에 최적화, 사용이 매우 간편함.\n초기 프로젝트에는 ChromaDB로 시작하고, 프로덕션 전환 시 Pinecone이나 Qdrant 클라우드로 마이그레이션하는 전략을 추천한다.",
        isImportant: false,
        tags: ["벡터DB", "Pinecone", "ChromaDB"],
        position: CGPoint(x: -400, y: 200)
    ),
    GraphNode(
        id: "10",
        title: "그래프 데이터 시각화 라이브러리",
        summary: "React Flow, D3.js, Cytoscape.js 비교. React 생태계에서는 React Flow(@xyflow/react)가 가장 적합함.",
        type: .chat,
        date: "2023-10-23",
        originalText: "User: React 프로젝트에서 노드와 엣지로 구성된 인터랙티브 그래프를 그리려고 해. 어떤 라이브러리가 좋을까?\n\nAI: React 환경이라면 단연코 **React Flow (@xyflow/react)**를 추천합니다.\n이유:\n1. React 컴포넌트 기반으로 커스텀 노드를 만들기 매우 쉽습니다.\n2. 줌, 팬, 드래그 등 필수 인터랙션이 내장되어 있습니다.\n3. 상태 관리가 직관적입니다.\nD3.js는 너무 로우레벨이고, Cytoscape.js는 강력하지만 React와의 통합이 다소 번거로울 수 있습니다.",
        isImportant: false,
        tags: ["시각화", "React Flow", "D3.js"],
        position: CGPoint(x: 200, y: -250)
    ),
]

// MARK: - Sample Edges

/// A 1-to-1 port of `initialEdges` from sampleNodes.ts.
/// The `strokeDasharray: '5,5'` edges are mapped to `isUserCreated: true`.
let sampleEdges: [GraphEdge] = [
    GraphEdge(
        id: "e1-2", sourceID: "1", targetID: "2",
        style: EdgeStyle(strokeWidth: 2, animated: true, isUserCreated: false)
    ),
    GraphEdge(
        id: "e1-4", sourceID: "1", targetID: "4",
        style: EdgeStyle(strokeWidth: 3, animated: false, isUserCreated: false)
    ),
    GraphEdge(
        id: "e2-5", sourceID: "2", targetID: "5",
        style: EdgeStyle(strokeWidth: 1, animated: false, isUserCreated: false)
    ),
    GraphEdge(
        id: "e1-3", sourceID: "1", targetID: "3",
        style: EdgeStyle(strokeWidth: 2, animated: true, isUserCreated: true)
    ),
    GraphEdge(
        id: "e3-6", sourceID: "3", targetID: "6",
        style: EdgeStyle(strokeWidth: 2, animated: false, isUserCreated: false)
    ),
    GraphEdge(
        id: "e6-7", sourceID: "6", targetID: "7",
        style: EdgeStyle(strokeWidth: 3, animated: true, isUserCreated: false)
    ),
    GraphEdge(
        id: "e7-9", sourceID: "7", targetID: "9",
        style: EdgeStyle(strokeWidth: 2, animated: false, isUserCreated: false)
    ),
    GraphEdge(
        id: "e4-8", sourceID: "4", targetID: "8",
        style: EdgeStyle(strokeWidth: 1, animated: true, isUserCreated: true)
    ),
    GraphEdge(
        id: "e1-10", sourceID: "1", targetID: "10",
        style: EdgeStyle(strokeWidth: 2, animated: false, isUserCreated: false)
    ),
]
