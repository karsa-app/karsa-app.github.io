# @karsa/project-template-productive

The **new default** Karsa project template: a standalone **two-agent reconciler task system** (spec_01KXKN88BDFF). A **sibling** of `@karsa/project-template-minimum` — it does **not** extend it.

## What it provides

- **Two agent profiles** — `profile_tmpl_planner` (turns goals into tasks) + `profile_tmpl_worker` (a reconciler that executes the most-eligible task). These are the templates' **vanity ids**; the installer mints real `profile_<ULID>` ids and rewrites all references via a temp map (spec_01KSTPW19N8R §2.4).
- **Two defining subscribers** — planner→task-CRUD, and task/exec-events→worker-reconcile. Task updates flow back to the chat.
- The **`task`** collection (the durable backlog) + the full base collections (chat/spec/exec/file/syslog/agent-profile/subscriber/event-handler).
- The **`fn`** collection + agent-CLI wrapper fns as **creation-templates** under `fn/templates/` (currently `claude_code`) — the engine→fn migration. Instantiating one mints a `fn_<ULID>` + a `slug` and (via the fn-bundle installer) co-installs the paired `eh_`/`subr_` wired to that minted id.

## Layout

```
src/$PROJECT_HOME/karsa/$projectId/artifact/
└── fn/
    ├── index.md                     ← the fn collection doc
    └── templates/
        └── claude_code/             ← the agent-CLI wrapper creation-template
            ├── index.md             ← fn descriptor (placeholders: {{ID}}/{{SLUG}}/{{NAME}}/{{NOW}})
            └── handler.ts           ← the wrapper (WIP — wraps the `claude` CLI, §7.2)
```

Built-in creation-templates resolve from the template chain (`resolveTemplateChain("productive")` → `["productive", "minimum"]`); a project created with `template: "productive"` can instantiate them.

## Status

WIP. The `claude_code` handler is a stub — the real CLI wrapping (stream-json → UDS yields) and the eh_/subr_ bundle installer are the next increments (spec_01KXM4XP2586 §7.2).
