# @karsa/project-template-minimum

Base template. Every Karsa project includes the minimum's kinds + defaults.

The `src/` tree mirrors install destinations — copying `src/` into the user's machine (after substituting the literal `$KARSA_HOME`, `$PROJECT_HOME`, and `$projectId` segments) gives a working install.

## Source layout

```
src/
  $KARSA_HOME/                              # machine-wide files
    KARSA.md                     # → $KARSA_HOME/KARSA.md
    README.md                            # → $KARSA_HOME/README.md
  $PROJECT_HOME/
    karsa/
      README.md                          # → $PROJECT_HOME/karsa/README.md
      $projectId/
        artifact/
          index.md
          {chat,spec,exec,asset,…}/index.md
          subscriber/
            index.md
            sber_template_*.md.tmpl      # → renamed to sber_<new_ulid>.md with placeholder substitutions
```

## What "minimum" includes

Artifact kinds: **chat, spec, exec, asset, agent-profile, subscriber, event-handler, syslog**.

With these, an operator can talk to an AI engine that can act on their machine. SDLC concepts (PRD, RFC, task, workflow) live in `@karsa/project-template-sdlc`.

## Install rules

The seeder applies these rules when walking `src/`:

| Source file | Behavior |
|---|---|
| `sber_template_*.md.tmpl` | Rendered with fresh `sber_<ulid>` id and `{{PROJECT_ID}}`/`{{NOW}}`/`{{NEW_ULID}}` substitutions. Renamed to `sber_<ulid>.md`. |
| `index.md`, `README.md`, `KARSA.md` | Installed only when absent at the destination (never clobbers operator edits). |
| Other files | Copied with `{{PROJECT_ID}}`, `{{NOW}}`, `__CREATED_AT__` substitutions. |
