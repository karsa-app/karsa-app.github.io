# @karsa/api

The Karsa daemon. HTTP + SSE on `:3100`, scheduler + subscriber dispatch, exec lifecycle, artifact CRUD.

## Develop

```
deno task dev      # watch mode from repo root
deno test          # 521+ tests
```

## Build

```
deno task build    # cd api && deno task build → ../bin/karsa
```

Bundles `project-template-minimum/`, `project-template-sdlc/` via `--include`.

## Layout

```
src/
  main.ts           daemon entry
  server.ts         HTTP + SSE
  scheduler.ts     event loop, subscriber dispatch
  daemon_jobs.ts   periodic + startup job registry
  exec.ts          exec manifest + log writers
  exec_log_pager.ts cursor-paginated log reader
  exec_recovery.ts  reconcile + dead-PID detector
  project.ts       project registry, template-aware seeding
  subscriber_runtime.ts  matcher + dispatch
  kind_registry.ts  per-project artifact kind discovery
  engines/          claude_code, codex wrappers
  handlers/         eh_coordinator, eh_worker, eh_system, eh_chat_progress, eh_db_indexer
  schemas/          core artifact JSON schemas (chat, exec, asset, …)
  validate/         loaders + frontmatter/body validators
  cli/              one-off scripts (work-log)
```

## Tasks

See `deno.json` for an inline comment on each; run via `deno task --filter @karsa/api <task>`.

- `dev` — run `karsa-server` from source (`--watch`, `--home $KARSA_HOME`); pair with a tmp home + `--port` to test in isolation.
- `test` — this package's suite.
- `build` — compile the `karsa-server` binary (`bin/karsa-server`).
- `work-log` — refresh the work log.

For a full local dist, use the root `deno task build` (server → cli → web).
