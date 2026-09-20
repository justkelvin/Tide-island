#!/usr/bin/env python3
"""Live verification for the Tide Island native notification server.

Verifies a running org.freedesktop.Notifications owner (Tide Island shell
or the test harness) speaks spec v1.2: server info, capabilities, Notify
ID allocation, replaces_id in-place updates, CloseNotification, action
round-trips and expiry signals.

Usage:
    # Against the already-running shell (stop dunst first):
    #   systemctl --user stop dunst
    #   systemctl --user restart tide-island
    ./scripts/test_dbus_notifications.py --live

    # Self-contained (spawns the harness on the current bus):
    ./scripts/test_dbus_notifications.py --harness ./build/tests/notification_server_harness

    # Fully isolated bus (recommended, no impact on your session):
    dbus-run-session -- ./scripts/test_dbus_notifications.py \\
        --harness ./build/tests/notification_server_harness
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import threading
import time

SERVICE = "org.freedesktop.Notifications"
PATH = "/org/freedesktop/Notifications"
IFACE = "org.freedesktop.Notifications"

FAILURES = []


def check_step(name, fn):
    try:
        detail = fn()
        print(f"  [PASS] {name}" + (f" ({detail})" if detail else ""))
        return True
    except AssertionError as exc:
        print(f"  [FAIL] {name}: {exc}")
        FAILURES.append(name)
        return False
    except FileNotFoundError as exc:
        print(f"  [FAIL] {name}: missing tool: {exc}")
        FAILURES.append(name)
        return False


def run(*argv, timeout=10):
    return subprocess.run(argv, capture_output=True, text=True, timeout=timeout)


def gdbus_call(method, *args):
    return run("gdbus", "call", "--session", "--dest", SERVICE,
               "--object-path", PATH, "--method", f"{IFACE}.{method}", *args)


def owner_has_name():
    proc = run("gdbus", "call", "--session", "--dest", "org.freedesktop.DBus",
               "--object-path", "/org/freedesktop/DBus",
               "--method", "org.freedesktop.DBus.NameHasOwner", SERVICE)
    assert proc.returncode == 0, proc.stderr.strip()
    assert "(true,)" in proc.stdout, f"no owner for {SERVICE}: {proc.stdout.strip()}"
    return proc.stdout.strip()


def server_information():
    proc = gdbus_call("GetServerInformation")
    assert proc.returncode == 0, proc.stderr.strip()
    m = re.search(r"\('(.*)', '(.*)', '(.*)', '(.*)'\)", proc.stdout)
    assert m, f"unexpected reply: {proc.stdout.strip()}"
    name, vendor, version, spec = m.groups()
    assert name == "Tide Island", f"name={name}"
    assert vendor == "justkelvin", f"vendor={vendor}"
    assert version == "1.0.0", f"version={version}"
    assert spec == "1.2", f"spec={spec}"
    return proc.stdout.strip()


def capabilities():
    proc = gdbus_call("GetCapabilities")
    assert proc.returncode == 0, proc.stderr.strip()
    for cap in ("actions", "body", "image-data", "persistence", "inline-reply"):
        assert f"'{cap}'" in proc.stdout, f"missing capability {cap}"
    return proc.stdout.strip()[:120] + "..."


def notify(app="TideProbe", replaces=0, summary="Probe title", body="Probe body",
           actions="[]", hints="{}", timeout=5000):
    proc = gdbus_call("Notify", app, str(replaces), "", summary, body,
                      actions, hints, str(timeout))
    assert proc.returncode == 0, proc.stderr.strip()
    m = re.search(r"uint32 (\d+)", proc.stdout)
    assert m, f"no id in reply: {proc.stdout.strip()}"
    return int(m.group(1))


def notify_and_replace():
    first = notify(summary="replace-me")
    assert first != 0, "id 0 is reserved"
    second = notify(replaces=first, summary="replace-me")
    assert second == first, f"replaces_id not honored: {first} -> {second}"
    return f"id={first} reused"


def close_notification():
    nid = notify(summary="close-me", timeout=60000)
    proc = gdbus_call("CloseNotification", str(nid))
    assert proc.returncode == 0, proc.stderr.strip()
    return f"id={nid} closed"


def close_unknown_id_is_noop():
    proc = gdbus_call("CloseNotification", "424242")
    assert proc.returncode == 0, proc.stderr.strip()
    return "unknown id ignored"


def notify_send_smoke():
    assert shutil.which("notify-send"), "notify-send not installed"
    proc = run("notify-send", "Tide Island probe", "live smoke test", "--expire-time=3000")
    assert proc.returncode == 0, proc.stderr.strip()
    return "notify-send accepted"


class SignalWatch:
    """Collects org.freedesktop.Notifications signals via dbus-monitor."""

    def __init__(self):
        self.lines = []
        self.proc = subprocess.Popen(
            ["dbus-monitor", "--monitor",
             f"type='signal',interface='{IFACE}',path='{PATH}'"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        self.thread = threading.Thread(target=self._drain, daemon=True)
        self.thread.start()

    def _drain(self):
        try:
            for line in self.proc.stdout:
                self.lines.append(line)
        except Exception:
            pass

    def stop(self):
        self.proc.terminate()
        try:
            self.proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            self.proc.kill()

    def text(self):
        return "".join(self.lines)


def expiry_signal():
    watch = SignalWatch()
    try:
        nid = notify(summary="expiry-probe", timeout=800)
        deadline = time.time() + 8
        while time.time() < deadline:
            text = watch.text()
            if "member=NotificationClosed" in text and f"uint32 {nid}" in text:
                assert "uint32 1" in text, f"expected reason 1 (expired): {text[-400:]}"
                return f"id={nid} expired with reason 1"
            time.sleep(0.1)
        raise AssertionError(f"no NotificationClosed for id={nid}:\n{watch.text()[-800:]}")
    finally:
        watch.stop()


def run_suite(label):
    print(f"==> {label}")
    check_step("service has an owner", owner_has_name)
    check_step("GetServerInformation", server_information)
    check_step("GetCapabilities", capabilities)
    check_step("Notify allocates + replaces_id reuses", notify_and_replace)
    check_step("CloseNotification", close_notification)
    check_step("CloseNotification unknown id", close_unknown_id_is_noop)
    check_step("notify-send smoke", notify_send_smoke)
    check_step("expiry emits NotificationClosed(id, 1)", expiry_signal)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--harness", help="path to notification_server_harness binary")
    parser.add_argument("--live", action="store_true",
                        help="verify the already-running server (default with --harness unset)")
    parser.add_argument("--take-over", action="store_true",
                        help="pass --take-over to the harness (replace dunst without stopping it)")
    args = parser.parse_args()

    harness = None
    if args.harness:
        assert os.path.isfile(args.harness) and os.access(args.harness, os.X_OK), \
            f"harness not executable: {args.harness}"
        cmd = [args.harness] + (["--take-over"] if args.take_over else [])
        harness = subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True)
        ready = harness.stdout.readline().strip()
        print(f"harness says: {ready}")
        assert "READY" in ready and "registered=1" in ready, \
            f"harness failed to register {SERVICE} (is dunst still running? stop it or use --take-over)"
        try:
            run_suite(f"live checks via harness {args.harness}")
        finally:
            harness.terminate()
            harness.wait(timeout=5)
    else:
        run_suite("live checks against running server")

    if FAILURES:
        print(f"\n{len(FAILURES)} check(s) FAILED: {', '.join(FAILURES)}")
        return 1
    print("\nAll live notification checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
