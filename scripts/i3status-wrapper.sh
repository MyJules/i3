#!/usr/bin/env python3
import subprocess
import sys
import json
import ctypes
import ctypes.util
import threading
import time
import os
import signal

_lib = ctypes.util.find_library('X11')
_x11 = ctypes.CDLL(_lib) if _lib else None

if _x11:
    class _XkbStateRec(ctypes.Structure):
        _fields_ = [
            ('group',              ctypes.c_ubyte),
            ('locked_group',       ctypes.c_ubyte),
            ('base_group',         ctypes.c_ushort),
            ('latched_group',      ctypes.c_ushort),
            ('mods',               ctypes.c_ubyte),
            ('base_mods',          ctypes.c_ubyte),
            ('latched_mods',       ctypes.c_ubyte),
            ('locked_mods',        ctypes.c_ubyte),
            ('compat_state',       ctypes.c_ubyte),
            ('grab_mods',          ctypes.c_ubyte),
            ('compat_grab_mods',   ctypes.c_ubyte),
            ('lookup_mods',        ctypes.c_ubyte),
            ('compat_lookup_mods', ctypes.c_ubyte),
            ('ptr_buttons',        ctypes.c_ushort),
        ]
    _x11.XOpenDisplay.restype   = ctypes.c_void_p
    _x11.XOpenDisplay.argtypes  = [ctypes.c_char_p]
    _x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    _x11.XkbGetState.restype    = ctypes.c_int
    _x11.XkbGetState.argtypes   = [ctypes.c_void_p, ctypes.c_uint, ctypes.POINTER(_XkbStateRec)]

LAYOUTS = ['US', 'RU', 'UA']

def get_layout():
    if _x11:
        try:
            dpy = _x11.XOpenDisplay(None)
            if dpy:
                state = _XkbStateRec()
                _x11.XkbGetState(dpy, 0x0100, ctypes.byref(state))
                _x11.XCloseDisplay(dpy)
                idx = state.group
                if 0 <= idx < len(LAYOUTS):
                    return LAYOUTS[idx]
        except Exception:
            pass
    return '??'

def kbd_block():
    return {
        "name":      "kbd",
        "full_text": f"  {get_layout()}",
        "color":     "#03dac6",
        "markup":    "none"
    }

proc = subprocess.Popen(
    ['i3status', '--config', '/home/amudryk/.config/i3status/config'],
    stdout=subprocess.PIPE, text=True
)

def layout_watcher():
    """Poll layout every 100ms; on change, poke i3status to emit a new line."""
    current = get_layout()
    while proc.poll() is None:
        time.sleep(0.1)
        new = get_layout()
        if new != current:
            current = new
            os.kill(proc.pid, signal.SIGUSR1)

t = threading.Thread(target=layout_watcher, daemon=True)
t.start()

# Pass through version header
print(proc.stdout.readline(), end='', flush=True)  # {"version":1}
print(proc.stdout.readline(), end='', flush=True)  # [

first = True
for line in proc.stdout:
    line = line.strip().lstrip(',')
    try:
        blocks = json.loads(line)
        blocks.insert(-1, kbd_block())
        prefix = '' if first else ','
        print(prefix + json.dumps(blocks), flush=True)
        first = False
    except json.JSONDecodeError:
        print(line, flush=True)
