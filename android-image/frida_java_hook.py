#!/usr/bin/env python3
"""
frida_java_hook.py - Frida 17 Java-bridge helper.

Frida 17 removed the Java/ObjC bridges from the core agent. frida-tools still
ships them; this loads the Java bridge and exposes `Java` to your script.

Usage:
    # attach to a running app and run an inline snippet
    frida_java_hook.py --attach com.example.app --code 'Java.perform(() => send(Java.vm.version))'

    # spawn an app, hook TextView.setText, print hits for 10s
    frida_java_hook.py --spawn com.example.app --hook-textview

    # attach and run a local script file
    frida_java_hook.py --attach com.example.app --file myscript.js
"""
import argparse
import pathlib
import sys
import time

import frida


def java_prelude() -> str:
    import frida_tools
    bridge = pathlib.Path(frida_tools.__file__).parent / "bridges" / "java.js"
    src = bridge.read_text(encoding="utf-8")
    return (
        "(function () {\n"
        + src
        + "\nObject.defineProperty(globalThis, 'Java', { value: bridge });\n})();\n"
    )


TEXTVIEW_HOOK = """
Java.perform(function () {
    var hits = 0;
    var TV = Java.use('android.widget.TextView');
    TV.setText.overload('java.lang.CharSequence').implementation = function (t) {
        hits++;
        if (hits <= 20) {
            var s = t ? t.toString() : '';
            send({event: 'setText', n: hits, text: s.substring(0, Math.min(80, s.length))});
        }
        return this.setText(t);
    };
    send({event: 'ready', vm: Java.vm.name, classes: Java.enumerateLoadedClassesSync().length});
});
"""


def find_pid(device, ident):
    if ident.isdigit():
        return int(ident)
    for p in device.enumerate_processes():
        if p.name == ident or p.identifier == ident:
            return p.pid
    for p in device.enumerate_applications():
        if p.identifier == ident or p.name == ident:
            return p.pid
    raise SystemExit(f"target not found: {ident}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--spawn", metavar="PKG")
    ap.add_argument("--attach", metavar="PKG_OR_PID")
    ap.add_argument("--file", metavar="SCRIPT.JS")
    ap.add_argument("--code", metavar="JS")
    ap.add_argument("--hook-textview", action="store_true")
    ap.add_argument("--seconds", type=int, default=10)
    args = ap.parse_args()

    dev = frida.get_usb_device(timeout=15)

    if args.spawn:
        pid = dev.spawn([args.spawn])
        mode = "spawn"
    elif args.attach:
        pid = find_pid(dev, args.attach)
        mode = "attach"
    else:
        ap.error("need --spawn or --attach")

    session = dev.attach(pid)
    body = args.code or (TEXTVIEW_HOOK if args.hook_textview else "send('no script provided');")
    if args.file:
        body = pathlib.Path(args.file).read_text()
    script = session.create_script(java_prelude() + body)
    script.on("message", lambda m, d: print("[msg]", m.get("payload", m)))
    script.load()
    if mode == "spawn":
        dev.resume(pid)
    time.sleep(args.seconds)
    session.detach()


if __name__ == "__main__":
    sys.exit(main())
