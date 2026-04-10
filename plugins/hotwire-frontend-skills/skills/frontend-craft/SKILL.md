---
name: frontend-craft
description: >-
  Entry skill for broad or ambiguous Hotwire frontend requests.
  Triages problems, applies common principles, and routes to specialist skills.
  Use for Rails frontend, Hotwire frontend, Turbo, Stimulus, frontend architecture,
  page layout, component architecture, or when the request spans multiple concerns
  and is not clearly scoped to navigation, streams, controllers, forms, media, or native.
allowed-tools: Read, Grep, Glob, Task, mcp__context7__resolve-library-id, mcp__context7__query-docs
---

# Frontend Craft — Gateway

Triage incoming Hotwire frontend requests, apply cross-cutting principles, and route to the right specialist skill. This skill owns no implementation cookbook — each specialist carries its own.

## Routing Table

| Request Pattern | Route To |
|---|---|
| URL, history, frame navigation, Drive caching, rendering lifecycle, view transitions, page-refresh morphing | `turbo-navigation-rendering` |
| Turbo Streams, broadcasting, stream morphing, optimistic state, real-time sync via broadcasting | `turbo-streams` |
| Stimulus controller design, lifecycle, DOM behavior, browser APIs | `stimulus-controllers` |
| Form submission, validation, autosave, inline edit, submit UX | `hotwire-forms` |
| Media playback, gallery, upload preview, rich content integrations | `media-content` |
| Native bridge, web/native boundary, path configuration | `hotwire-native` |
| Broad or ambiguous frontend request | Stay here — apply principles below, then route |

## Core Workflow

### Step 1: Classify the Problem

Determine the primary domain: navigation/rendering, streams/state sync, controller behavior, forms/submission, media UX, or native bridge. If the request clearly maps to one domain, route immediately.

### Step 2: Apply Common Principles

Before routing, check whether these cross-cutting principles apply:

1. **Prefer built-in Turbo semantics first.** Use `data-turbo-*` attributes, frame `src`, and stream actions before reaching for custom JavaScript.
2. **Decide ownership first.** Every UI change must have a clear owner: a URL (Drive), a frame ID (Frames), or a stream target (Streams). Ambiguous ownership causes bugs.
3. **Avoid fixed timeouts as proxy for completion.** Listen for lifecycle events (`turbo:load`, `turbo:submit-end`, `turbo:before-stream-render`) instead of `setTimeout`.
4. **Validate back/forward/refresh behavior.** Every navigation pattern must work correctly when the user presses back, forward, or refresh.
5. **Preserve focus and perceived continuity.** Form rerenders must restore focus/caret/selection. Frame updates must not disrupt scroll position.
6. **Design for idempotency and retry.** Stream actions and form submissions must be safe to replay without duplication or corruption.
7. **Separate browser event concerns from Turbo lifecycle concerns.** DOM events (click, input, resize) and Turbo events (turbo:load, turbo:before-cache) serve different purposes — do not conflate them.

> **Documentation accuracy:** When specific API code is needed, use context7 (`resolve-library-id` → `query-docs`) to fetch the latest official documentation. Core patterns and architectural guidance in this skill are version-stable, but specific method signatures and configuration formats should be verified against current docs.

### Step 3: Resolve Overlap

When a request spans multiple skills, assign a lead skill:

| Overlap | Lead | Support |
|---|---|---|
| Form inside a lazy-loaded frame | `hotwire-forms` | `turbo-navigation-rendering` |
| Stream-driven form validation | `hotwire-forms` | `turbo-streams` |
| Media upload with progress indicator | `media-content` | `hotwire-forms` |
| Optimistic UI with stream reconciliation | `turbo-streams` | `turbo-navigation-rendering` |
| Controller coordinating frame navigation | `turbo-navigation-rendering` | `stimulus-controllers` |
| Bridge component with form submission | `hotwire-native` | `hotwire-forms` |
| CSS architecture for controller-driven UI | `stimulus-controllers` | (reference only) |
| Page-refresh morphing (`<meta name="turbo-refresh-method" content="morph">`) | `turbo-navigation-rendering` | `turbo-streams` |
| Stream-action morphing (`turbo_stream.replace method: :morph`) | `turbo-streams` | `turbo-navigation-rendering` |
| View transitions during page navigation (Drive visits, frame navigation) | `turbo-navigation-rendering` | `turbo-streams` |
| View transitions triggered by stream updates (list animations, item add/remove) | `turbo-streams` | `turbo-navigation-rendering` |

Rule: the skill that owns the hardest constraint (correctness, data integrity, platform boundary) leads.

### Routing Examples

| User Request | Classification | Route |
|---|---|---|
| "Add a modal that lets users edit their profile inline" | Form + frame boundary | Lead: `hotwire-forms`, Support: `turbo-navigation-rendering` |
| "Make the notification count update in real-time across tabs" | Real-time + cross-tab sync | `turbo-streams` |
| "Add a carousel for product images with swipe gestures" | Media rendering + library integration | `media-content` |

### Step 4: Route to Specialist

Hand off to the identified specialist skill by invoking it directly. Pass along any context from Step 2 (applicable principles) and Step 3 (lead/support assignment). The specialist will load its own references, handbook, and examples as needed. For multi-skill requests, invoke the lead skill — it will escalate to the support skill when needed.

### Step 5: Escalate Out of Scope

| Signal | Action |
|---|---|
| Request requires server-side model/controller changes | Escalate to backend — outside this plugin's scope |
| Request requires native platform APIs beyond bridge components | Route to `hotwire-native` |
| Request is about deployment, CI, or infrastructure | Outside this plugin's scope |
| Request is about non-Hotwire JavaScript frameworks | Outside this plugin's scope |

## Escalation Criteria

This plugin covers the **Hotwire frontend layer**: Turbo Drive, Turbo Frames, Turbo Streams, Stimulus, and view-layer patterns (CSS, transitions, media). It does not cover:

- Rails backend architecture (models, controllers, jobs, concerns)
- Database design or migrations
- API design beyond Turbo Stream responses
- Non-Hotwire JavaScript frameworks (React, Vue, etc.)
- Infrastructure, deployment, or DevOps
