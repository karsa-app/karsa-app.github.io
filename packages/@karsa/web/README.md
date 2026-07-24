# @karsa/web

The Karsa web UI — the single-page app the daemon serves at `/`. A React + Vite bundle that talks to the daemon's HTTP API on the same origin.

## Install

Ships as the `karsa-web.tar.gz` artifact (`kind: web` in the registry). The installer downloads it, verifies its sha256, and extracts it to:

```
$KARSA_HOME/packages/@karsa/web/dist
```

The daemon reads that directory fresh on each request, so swapping the files is a zero-downtime upgrade — no server restart (`spec_01KVE4X4BM2A` §6.5 tier 1).

## Build

```bash
npm ci          # in web/ (and ui/ for the shared design system)
npm run build   # → web/dist (minified, sourcemap: false)
```

The release tool (`deno task release`) runs this and tars `web/dist` into `karsa-web.tar.gz`.

## Requires

`karsa >= 0.1.0` (the daemon that serves it).
