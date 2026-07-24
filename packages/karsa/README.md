# @karsa/cli

The `karsa` command. Dispatches subcommands; calling `karsa` with no args prints a status dashboard.

```
karsa                    Status dashboard
karsa start              Start the daemon (foreground)
karsa install            Extract bundled packages into $KARSA_HOME
karsa version            Print version
karsa help               Help text
```

## Build

```bash
deno task --filter "@karsa/cli" build   # → bin/karsa
```

`@karsa/cli` imports `runDaemon` from `@karsa/api`, so the resulting binary bundles both the dispatcher and the daemon — one binary, multiple subcommands. Project templates ride along via `deno compile --include`.

## Implementation

- `src/main.ts` — argument parser + dispatch
- `src/commands/start.ts` — calls `runDaemon({ port })` from `@karsa/api`
- `src/commands/status.ts` — probes `/health`, lists projects from `projects.yaml`
- `src/commands/install.ts` — extracts bundled packages (TODO)
- `src/commands/version.ts` — prints version
- `src/commands/help.ts` — help text

Per [`spec_01KSRG8EFTG6`](../karsa/proj_01KPRM7ZKC20/artifact/spec/spec_01KSRG8EFTG6_karsa-cli-binary.md).

## Tasks

See `deno.json` for an inline comment on each; run via `deno task --filter @karsa/cli <task>`.

- `dev` — run the `karsa` CLI from source; append the subcommand after the task (`… dev doctor`). Set `KARSA_HOME` + `KARSA_PORT` to point it at a dev daemon.
- `build` — compile the `karsa` launcher binary (`bin/karsa`). It spawns `karsa-server`, so build that too (`@karsa/api build`) or use the root `deno task build`.
