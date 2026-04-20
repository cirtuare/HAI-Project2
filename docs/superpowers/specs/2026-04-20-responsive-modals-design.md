# Responsive Modals Design

**Date:** 2026-04-20  
**Scope:** Make all hardcoded modal/panel frames responsive using minWidth/maxWidth approach

---

## Problem

10 views have fixed `.frame(width:, height:)` on their root containers. When the window is smaller than the fixed size, modals overflow and don't shrink with the window.

## Approach: minWidth/maxWidth (A)

Replace `frame(width: W, height: H)` with `frame(minWidth: W*0.8, maxWidth: .infinity, minHeight: H*0.8, maxHeight: .infinity)` on each modal's root container.

Small UI elements (icons, circles, dividers) keep their fixed sizes — only top-level containers change.

---

## Changes Per File

| File | Current | New |
|------|---------|-----|
| SmartInputModalView.swift:30 | `width: 860, height: 560` | `minWidth: 680, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity` |
| MultiPersonaChatView.swift:25 | `width: 780, height: 560` | `minWidth: 620, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity` |
| SinglePersonaChatView.swift:29 | `width: 560, height: 620` | `minWidth: 460, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity` |
| LiveDebateView.swift:24 | `width: 660, height: 580` | `minWidth: 520, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity` |
| PersonaOnboardingView.swift:27 | `width: 600, height: 560` | `minWidth: 480, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity` |
| OriginView.swift:281 | `width: 800, height: 600` | `minWidth: 640, maxWidth: .infinity, minHeight: 480, maxHeight: .infinity` |
| NodeTimelineView.swift:272 | `width: 800, height: 600` | `minWidth: 640, maxWidth: .infinity, minHeight: 480, maxHeight: .infinity` |
| DetailInspectorView.swift:841 | `width: 360, height: 700` | `minWidth: 300, maxWidth: 400, minHeight: 500, maxHeight: .infinity` |
| SettingsView.swift:62 | `width: 520` | `minWidth: 420, maxWidth: 580` |
| GraphCanvasView.swift:402 | `width: 1100, height: 700` | `minWidth: 800, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity` |

**Not changing:**
- `DebateStatusBanner.swift:112` — fixed 320px banner, intentional narrow width
- `FloatingActionsView.swift:173` — preview only
- Icon/circle sizes throughout (24×24, 28×28, 6×6 etc.)

---

## Success Criteria

- All modals shrink when window width < modal's original fixed size
- No content clipping at 1024×768 window size
- Layout doesn't break when window is expanded beyond original size
