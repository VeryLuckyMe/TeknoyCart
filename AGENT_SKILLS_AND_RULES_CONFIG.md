# Antigravity Agent Configuration, Skills & Rules Manual
**Target Purpose:** Complete blueprint to replicate the agent personality, autonomous skill routing, active badging policy, and all 30 installed skills on your main desktop.

---

## 1. Core Rule Files: `AGENTS.md` & `GEMINI.md`
To ensure the AI agent acts with the same personality and autonomous skill dispatching, place identical copies of this rule file in either:
1. **Workspace Root:** `<Your_Project_Root>/AGENTS.md` and `<Your_Project_Root>/GEMINI.md`
2. **Global Config (Applies across all projects):** `C:\Users\<Your_User>\.gemini\config\rules\AGENTS.md`

### Exact Content of `AGENTS.md`:
```markdown
# Autonomous Skill Routing & Execution Policy

## 1. Intent-Based Autonomous Skill Invocation
DO NOT wait for the user to explicitly name a skill or invoke a command.
Whenever the user makes any request—even vague, exploratory, or brief prompts—immediately analyze their underlying technical intent and automatically activate all applicable skills:

| User Intent / Keywords | Automatically Activated Skills |
| :--- | :--- |
| **New features, screens, flows, or creative ideas** (e.g. *"build a screen for..."*, *"how should we do..."*) | `superpowers:brainstorming` + `ui-ux-pro-max` (plus `find-skills` if external libraries are needed) |
| **Animations, micro-interactions, motion, or transitions** (e.g. *"add motion"*, *"make this animate"*, *"smooth transition"*) | `animate` + `improve-animations` + `ui-ux-pro-max` |
| **Icons, SVGs, icon alignment, or touch targets** (e.g. *"fix icon"*, *"center icon"*, *"icon button"*) | `icon-design` + `ui-ux-pro-max` |
| **UI/UX testing, visual inspection, or audit reports** (e.g. *"audit this screen"*, *"test UI and make report"*, *"inspect states"*) | `ui-audit-reporter` + `better-interface` + `better-accessibility` |
| **Component stress-testing or edge-case testing** (e.g. *"break this"*, *"test extreme inputs"*, *"stress test form"*) | `break` + `superpowers:test-driven-development` |
| **Code writing, refactoring, or cleaning up** (e.g. *"write this code"*, *"refactor this"*, *"clean up"*) | `ponytail` (minimal lines, YAGNI) + `superpowers:test-driven-development` |
| **Bugs, crashes, test failures, or errors** (e.g. *"why did this break"*, *"fix error"*, *"test failing"*) | `superpowers:systematic-debugging` + `claude-mem` (check past bug history) |
| **Database, SQL, RLS, or security questions** (e.g. *"check RLS"*, *"migration"*, *"protect columns"*) | `supabase-postgres-best-practices` |
| **Backend API, Spring Boot, or payments** (e.g. *"PayMongo"*, *"order controller"*, *"backend error"*) | `spring-boot-development` |
| **Mobile state, Flutter screens, or widgets** (e.g. *"riverpod"*, *"flutter state"*, *"widget rebuild"*) | `flutter-riverpod-expert` |
| **Testing & quality assurance** (e.g. *"test the web app"*, *"run browser tests"*) | `playwright-pro` + `superpowers:verification-before-completion` |
| **Unfamiliar tasks or missing capabilities** (e.g. *"how do I do X"*, *"find a tool for X"*) | `find-skills` |

---

## 2. Mandatory Skill Badging in Every Response
EVERY response you give MUST begin with a prominent skill badge header listing which skills were activated for that prompt:

> 🛠️ **Active Skills Applied:** `[skill-1]`, `[skill-2]`  
> *Routing Rationale: Brief 1-line reason why these skills were selected based on the user's intent.*

Never omit this badge. It ensures total transparency and proves which expert frameworks were utilized.
```

---

## 2. Directory Structure on Your Main Desktop
On your main desktop, your project directory should look like this:

```text
TeknoyCart_Project/
├── AGENTS.md                          <-- Root rule file
├── GEMINI.md                          <-- Root rule file
├── SESSION_HANDOVER_AND_CHANGELOG.md  <-- This session log
├── AGENT_SKILLS_AND_RULES_CONFIG.md   <-- This manual
│
├── .agents/
│   ├── plugins/
│   │   └── superpowers/
│   │       └── plugin.json
│   └── skills/                        <-- Copy all 30 skill folders here!
│       ├── animate/
│       ├── better-accessibility/
│       ├── better-interface/
│       ├── brainstorming/
│       ├── break/
│       ├── claude-mem/
│       ├── diagnosing-superpowers/
│       ├── dispatching-parallel-agents/
│       ├── executing-plans/
│       ├── find-skills/
│       ├── finishing-a-development-branch/
│       ├── flutter-riverpod-expert/
│       ├── icon-design/
│       ├── improve-animations/
│       ├── playwright-pro/
│       ├── ponytail/
│       ├── receiving-code-review/
│       ├── requesting-code-review/
│       ├── spring-boot-development/
│       ├── subagent-driven-development/
│       ├── supabase-postgres-best-practices/
│       ├── systematic-debugging/
│       ├── test-driven-development/
│       ├── ui-audit-reporter/
│       ├── using-git-worktrees/
│       ├── using-superpowers/
│       ├── verification-before-completion/
│       ├── web-design-guidelines/
│       ├── writing-plans/
│       └── writing-skills/
│
└── TeknoyCart/                        <-- Your Flutter project
    └── ...
```

---

## 3. Catalog of the 30 Installed Skills

| # | Skill Name | Primary Responsibility & Framework |
| :---: | :--- | :--- |
| 1 | **`animate`** | High-performance, polished UI animations using Emil Kowalski's motion principles (≤300ms budgets, spring physics). |
| 2 | **`better-accessibility`** | WCAG 2.2 accessibility audits: keyboard focus, screen-reader semantics, form labels, and touch targets. |
| 3 | **`better-interface`** | Holistic UI review across typography, color palettes, visual hierarchy, and polish. |
| 4 | **`brainstorming`** | Structured ideation before building new screens, creative flows, or architecture designs. |
| 5 | **`break`** | Stress-testing UI components with extreme edge cases (5000-char strings, negative prices, network drops). |
| 6 | **`claude-mem`** | Cross-session memory and context persistence (captures bug history, project invariants, and milestones). |
| 7 | **`diagnosing-superpowers`** | Diagnostic engine for evaluating agent execution quality, tool timeouts, and session traces. |
| 8 | **`dispatching-parallel-agents`**| Spawning concurrent subagents for independent workstreams without shared state. |
| 9 | **`executing-plans`** | Disciplined execution of multi-step implementation plans. |
| 10 | **`find-skills`** | Discovering and installing new capabilities and community skills on demand. |
| 11 | **`finishing-a-development-branch`** | Worktree integration, git branch cleanup, and pull request finalization. |
| 12 | **`flutter-riverpod-expert`** | Best practices for Flutter & Riverpod: `AsyncNotifier`, selective widget rebuilds, and state isolation. |
| 13 | **`icon-design`** | Harmonizing icon systems (24x24 viewBoxes, optical centering, 44x44px touch targets). |
| 14 | **`improve-animations`** | Motion audits: diagnosing layout thrashing, incorrect easing curves, and frame drops. |
| 15 | **`playwright-pro`** | End-to-end (E2E) automated browser testing with resilient selectors and auto-waiting assertions. |
| 16 | **`ponytail`** | Eliminates code bloat and prevents over-engineering ("The best code is the code you never wrote"). |
| 17 | **`receiving-code-review`** | Evaluating code review feedback with technical verification rather than blind acceptance. |
| 18 | **`requesting-code-review`** | Verification checklists before merging code or declaring features complete. |
| 19 | **`spring-boot-development`** | Java 17 & Spring Boot 3 REST API design, RFC 7807 problem details, and webhook verification. |
| 20 | **`subagent-driven-development`**| Orchestrating subagents to implement modular feature tasks in parallel. |
| 21 | **`supabase-postgres-best-practices`**| Database schema hardening: Row-Level Security (RLS), ACID transaction locks, and query index tuning. |
| 22 | **`systematic-debugging`** | 4-phase root-cause debugging: hypothesis generation, test isolation, and minimal regression fixes. |
| 23 | **`test-driven-development`** | Strict Red-Green-Refactor testing workflows before touching production code. |
| 24 | **`ui-audit-reporter`** | Comprehensive 6-state UI auditing (Default, Focus/Hover, Shimmer, Empty, Error, Narrow Viewport). |
| 25 | **`using-git-worktrees`** | Clean workspace isolation using Git worktrees for major refactors. |
| 26 | **`using-superpowers`** | Establishes autonomous skill invocation prior to generating responses. |
| 27 | **`verification-before-completion`**| Demands command execution evidence (logs, exit codes) before claiming tasks are complete. |
| 28 | **`web-design-guidelines`** | Modern design tokens, dynamic dark mode, and responsive layout grids. |
| 29 | **`writing-plans`** | Blueprinting multi-step architectural specs before writing code. |
| 30 | **`writing-skills`** | Meta-skill for creating and testing new agent skills. |
| 31 | **`flutter-production-readiness`** | Pre-deployment hardening: global crash boundaries, offline resilience, image cache limits, and release stripping. |
| 32 | **`performance-benchmark-profiling`** | Academic performance metrics generator: response time latency, API throughput, frame rates (60 FPS), and error rates. |
| 33 | **`system-architecture-gap-auditor`** | Marketplace domain auditor: identifies missing e-commerce workflows, dead-end states, fraud vulnerabilities, and capstone gaps. |
| 34 | **`mobile-release-divergence-auditor`** | Specializes in detecting bugs that work on localhost/Chrome/emulator but fail or crash in release APKs on physical Android devices. |

---

## 4. How to Sync to Your Main Desktop Next Week
1. **Pull Code Changes:**
   ```bash
   git pull origin main
   ```
2. **Copy the `.agents/` folder:**
   Copy the entire `.agents/` directory from this laptop to your main desktop's project folder (`TeknoyCart_Project/.agents`).
3. **Copy `AGENTS.md` and `GEMINI.md`:**
   Ensure `AGENTS.md` and `GEMINI.md` are in your project root on your desktop.
4. **Enjoy Instant Autonomous Badging & Skills:**
   Once in place, Antigravity on your main desktop will automatically route tasks to these exact skills and prepend the `🛠️ Active Skills Applied:` badge on every response!
