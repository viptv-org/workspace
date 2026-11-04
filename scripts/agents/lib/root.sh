#!/usr/bin/env bash
# Resolve the viptv-org org root whether this repository is cloned as the org
# root or checked out at <org>/workspace. Source this file; it exports
# ORG_ROOT (the org root) and WS_ROOT (this workspace repository's own root).
ws=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
# A sibling design/ that outranks a missing one here means <org>/workspace.
if [ -d "$ws/../design" ] && [ ! -d "$ws/design" ]; then
    ORG_ROOT=$(CDPATH='' cd -- "$ws/.." && pwd)
else
    ORG_ROOT=$ws
fi
WS_ROOT=$ws
export ORG_ROOT WS_ROOT