#!/usr/bin/env python3
"""Per-window IBus language memory for i3."""

import json
import subprocess

def ibus_get():
    try:
        r = subprocess.run(["ibus", "engine"], capture_output=True, text=True, timeout=2)
        return r.stdout.strip() or "xkb:us::eng"
    except Exception:
        return "xkb:us::eng"

def ibus_set(engine):
    try:
        subprocess.run(["ibus", "engine", engine], capture_output=True, timeout=2)
    except Exception:
        pass

def focused_window_id():
    try:
        r = subprocess.run(["i3-msg", "-t", "get_tree"], capture_output=True, text=True, timeout=2)
        def find_focused(node):
            if node.get("focused"):
                return node["id"]
            for child in node.get("nodes", []) + node.get("floating_nodes", []):
                found = find_focused(child)
                if found is not None:
                    return found
            return None
        return find_focused(json.loads(r.stdout))
    except Exception:
        return None

default_engine = ibus_get()
engines: dict[int, str] = {}
current_id = focused_window_id()

proc = subprocess.Popen(
    ["i3-msg", "-t", "subscribe", "-m", '["window"]'],
    stdout=subprocess.PIPE,
    text=True,
    bufsize=1,
)

for raw in proc.stdout:
    raw = raw.strip()
    if not raw:
        continue
    try:
        event = json.loads(raw)
    except json.JSONDecodeError:
        continue

    if event.get("change") != "focus":
        continue

    new_id = event["container"]["id"]
    if new_id == current_id:
        continue

    # Save engine for the window losing focus
    if current_id is not None:
        engines[current_id] = ibus_get()

    # Restore engine for the window gaining focus
    ibus_set(engines.get(new_id, default_engine))
    current_id = new_id
