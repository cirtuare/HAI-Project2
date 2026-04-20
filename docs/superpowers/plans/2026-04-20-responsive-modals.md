# Responsive Modals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all hardcoded modal/panel frame sizes with min/max responsive frames so they shrink with the window.

**Architecture:** Each modal's root `.frame(width: W, height: H)` becomes `.frame(minWidth: ~0.8W, maxWidth: .infinity, minHeight: ~0.8H, maxHeight: .infinity)`. Small icon/circle elements keep fixed sizes. DetailInspectorView and SettingsView get a maxWidth cap since they're narrow panels.

**Tech Stack:** SwiftUI (macOS), Xcode

---

## Files Modified

- `MemoAgent/MemoAgent/Views/SmartInputModalView.swift` — line 30
- `MemoAgent/MemoAgent/Views/MultiPersonaChatView.swift` — line 25
- `MemoAgent/MemoAgent/Views/SinglePersonaChatView.swift` — line 29
- `MemoAgent/MemoAgent/Views/LiveDebateView.swift` — line 24
- `MemoAgent/MemoAgent/Views/PersonaOnboardingView.swift` — line 27
- `MemoAgent/MemoAgent/Views/OriginView.swift` — line 281
- `MemoAgent/MemoAgent/Views/NodeTimelineView.swift` — line 272
- `MemoAgent/MemoAgent/Views/DetailInspectorView.swift` — line 841
- `MemoAgent/MemoAgent/Views/SettingsView.swift` — line 62
- `MemoAgent/MemoAgent/Views/GraphCanvasView.swift` — line 402

---

### Task 1: SmartInputModalView

**Files:**
- Modify: `MemoAgent/MemoAgent/Views/SmartInputModalView.swift:30`

- [ ] **Step 1: Apply responsive frame**

Find:
```swift
.frame(width: 860, height: 560)
```
Replace with:
```swift
.frame(minWidth: 680, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity)
```

- [ ] **Step 2: Build and verify**

In Xcode: `Cmd+B`
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add MemoAgent/MemoAgent/Views/SmartInputModalView.swift
git commit -m "feat: make SmartInputModal responsive"
```

---

### Task 2: MultiPersonaChatView

**Files:**
- Modify: `MemoAgent/MemoAgent/Views/MultiPersonaChatView.swift:25`

- [ ] **Step 1: Apply responsive frame**

Find:
```swift
.frame(width: 780, height: 560)
```
Replace with:
```swift
.frame(minWidth: 620, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity)
```

- [ ] **Step 2: Build and verify**

In Xcode: `Cmd+B`
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add MemoAgent/MemoAgent/Views/MultiPersonaChatView.swift
git commit -m "feat: make MultiPersonaChatView responsive"
```

---

### Task 3: SinglePersonaChatView

**Files:**
- Modify: `MemoAgent/MemoAgent/Views/SinglePersonaChatView.swift:29`

- [ ] **Step 1: Apply responsive frame**

Find:
```swift
.frame(width: 560, height: 620)
```
Replace with:
```swift
.frame(minWidth: 460, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
```

- [ ] **Step 2: Build and verify**

In Xcode: `Cmd+B`
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add MemoAgent/MemoAgent/Views/SinglePersonaChatView.swift
git commit -m "feat: make SinglePersonaChatView responsive"
```

---

### Task 4: LiveDebateView

**Files:**
- Modify: `MemoAgent/MemoAgent/Views/LiveDebateView.swift:24`

- [ ] **Step 1: Apply responsive frame**

Find:
```swift
.frame(width: 660, height: 580)
```
Replace with:
```swift
.frame(minWidth: 520, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity)
```

- [ ] **Step 2: Build and verify**

In Xcode: `Cmd+B`
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add MemoAgent/MemoAgent/Views/LiveDebateView.swift
git commit -m "feat: make LiveDebateView responsive"
```

---

### Task 5: PersonaOnboardingView

**Files:**
- Modify: `MemoAgent/MemoAgent/Views/PersonaOnboardingView.swift:27`

- [ ] **Step 1: Apply responsive frame**

Find:
```swift
.frame(width: 600, height: 560)
```
Replace with:
```swift
.frame(minWidth: 480, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity)
```

- [ ] **Step 2: Build and verify**

In Xcode: `Cmd+B`
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add MemoAgent/MemoAgent/Views/PersonaOnboardingView.swift
git commit -m "feat: make PersonaOnboardingView responsive"
```

---

### Task 6: OriginView

**Files:**
- Modify: `MemoAgent/MemoAgent/Views/OriginView.swift:281`

- [ ] **Step 1: Apply responsive frame**

Find:
```swift
.frame(width: 800, height: 600)
```
Replace with:
```swift
.frame(minWidth: 640, maxWidth: .infinity, minHeight: 480, maxHeight: .infinity)
```

- [ ] **Step 2: Build and verify**

In Xcode: `Cmd+B`
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add MemoAgent/MemoAgent/Views/OriginView.swift
git commit -m "feat: make OriginView responsive"
```

---

### Task 7: NodeTimelineView

**Files:**
- Modify: `MemoAgent/MemoAgent/Views/NodeTimelineView.swift:272`

- [ ] **Step 1: Apply responsive frame**

Find:
```swift
.frame(width: 800, height: 600)
```
Replace with:
```swift
.frame(minWidth: 640, maxWidth: .infinity, minHeight: 480, maxHeight: .infinity)
```

- [ ] **Step 2: Build and verify**

In Xcode: `Cmd+B`
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add MemoAgent/MemoAgent/Views/NodeTimelineView.swift
git commit -m "feat: make NodeTimelineView responsive"
```

---

### Task 8: DetailInspectorView

**Files:**
- Modify: `MemoAgent/MemoAgent/Views/DetailInspectorView.swift:841`

- [ ] **Step 1: Apply responsive frame**

Find:
```swift
.frame(width: 360, height: 700)
```
Replace with:
```swift
.frame(minWidth: 300, maxWidth: 400, minHeight: 500, maxHeight: .infinity)
```

Note: `maxWidth: 400` is intentional — this is a narrow side inspector panel.

- [ ] **Step 2: Build and verify**

In Xcode: `Cmd+B`
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add MemoAgent/MemoAgent/Views/DetailInspectorView.swift
git commit -m "feat: make DetailInspectorView responsive"
```

---

### Task 9: SettingsView

**Files:**
- Modify: `MemoAgent/MemoAgent/Views/SettingsView.swift:62`

- [ ] **Step 1: Apply responsive frame**

Find:
```swift
.frame(width: 520)
```
Replace with:
```swift
.frame(minWidth: 420, maxWidth: 580)
```

- [ ] **Step 2: Build and verify**

In Xcode: `Cmd+B`
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add MemoAgent/MemoAgent/Views/SettingsView.swift
git commit -m "feat: make SettingsView responsive"
```

---

### Task 10: GraphCanvasView

**Files:**
- Modify: `MemoAgent/MemoAgent/Views/GraphCanvasView.swift:402`

- [ ] **Step 1: Apply responsive frame**

Find:
```swift
.frame(width: 1100, height: 700)
```
Replace with:
```swift
.frame(minWidth: 800, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
```

- [ ] **Step 2: Build and verify**

In Xcode: `Cmd+B`
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add MemoAgent/MemoAgent/Views/GraphCanvasView.swift
git commit -m "feat: make GraphCanvasView responsive"
```

---

### Task 11: Final Smoke Test

- [ ] **Step 1: Run the app and resize the window**

Launch the app. Drag the window to be narrower than 1024px wide. Open each modal and verify it resizes with the window and no content is clipped.

- [ ] **Step 2: Final commit**

```bash
git add .
git commit -m "feat: all modals now responsive (minWidth/maxWidth approach)"
```
