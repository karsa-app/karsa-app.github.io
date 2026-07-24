# @karsa/doc

The Karsa manual — the single, maintained reference for **agents and humans** working inside a Karsa project.

This is **not** Karsa's internal spec collection (those stay dev-facing under `karsa/proj_*/artifact/spec/`). `doc`'s audience is the **user and the agent working inside a project**: how to use Karsa, how to upgrade, how to build a Karsa app, and what *not* to do.

## Three audiences, one source

- **Engines / agents — direct filesystem.** Seeded to `$KARSA_HOME/doc/`. An engine reads `index.md`, then the relevant `doc_*.md`, straight off disk. `$KARSA_HOME` is already in the engine env, so the manual replaces bulk "how Karsa works" prose in per-engine system prompts.
- **Humans — the web UI.** The daemon serves `$KARSA_HOME/doc/*` read-only; `@karsa/web` renders it machine-level at `/doc` (doc home) and `/doc/<id>` (per topic), reusing the shared markdown + frontmatter renderers.
- **Public — SEO.** `@karsa/landing-web` pulls the released bundle at build time and statically pre-renders each topic to `karsa.app/doc/*` for crawlers.

## Shape

```
src/
  index.md                      # frontmatter index (ordered topic list) + doc-home body
  doc_using-karsa.md
  doc_upgrading.md
  doc_building-a-karsa-app.md
  doc_anti-patterns.md
```

Each `doc_*.md` carries frontmatter: `title`, `summary`, `order`, and an optional `audience: internal`.

## Release + stripping

`deno task build` produces the shipped bundle (`src/` → `dist/`) and **strips internal content**:

- Any file with `audience: internal` in its frontmatter is dropped entirely.
- Any fenced region between `<!-- audience:internal -->` and `<!-- /audience:internal -->` is removed from a file's body.

So the public + user-facing bundle never leaks Karsa-internal detail. The bundle is versioned (`kind: doc`), listed in the registry, and seeded/updated into `$KARSA_HOME/doc` on install + upgrade (reconcile policy: `replace` — users read these, they don't edit them).
