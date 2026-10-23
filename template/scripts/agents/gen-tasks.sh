#!/bin/bash
# Regenerate .vscode/tasks.json from the current changes, so that VS Code can start every agent with one
# click (each in its own terminal). Run it again after planning a new change.
#   scripts/agents/gen-tasks.sh
set -euo pipefail
source "$(dirname "$0")/lib.sh"
root="$(main_root)"
changes="$(agent_changes)"
mkdir -p "$root/.vscode"
python3 - "$root/.vscode/tasks.json" $changes <<'PY'
import json, sys
path, names = sys.argv[1], sys.argv[2:]
pres = {"reveal": "always", "panel": "dedicated", "group": "agents", "focus": False}
shared = {"reveal": "always", "panel": "shared", "focus": True}
tasks = [{"label": f"Agent: {n}", "type": "shell", "command": f"scripts/agents/start-agent.sh {n}",
          "problemMatcher": [], "presentation": pres} for n in names]
if names:
    tasks.append({"label": "Agents: start all", "dependsOn": [f"Agent: {n}" for n in names],
                  "dependsOrder": "parallel", "problemMatcher": [],
                  "group": {"kind": "build", "isDefault": True}})  # Cmd+Shift+B starts all agents
tasks += [
    {"label": "Agents: status", "type": "shell", "command": "scripts/agents/status.sh",
     "problemMatcher": [], "presentation": shared},
    {"label": "Agents: merge all into the main branch", "type": "shell", "command": "scripts/agents/merge-all.sh",
     "problemMatcher": [], "presentation": shared},
]
json.dump({"version": "2.0.0", "tasks": tasks}, open(path, "w"), indent=2)
open(path, "a").write("\n")
print("wrote", path, "for:", ", ".join(names) or "(no changes)")
PY
