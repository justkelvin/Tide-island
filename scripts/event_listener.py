#!/usr/bin/env python3
import sys
import os
import re
import subprocess
import threading
import time

def log_event(category, message, color="\033[1;36m"):
    timestamp = time.strftime("%H:%M:%S")
    reset = "\033[0m"
    print(f"{color}[{timestamp}] [{category}]{reset} {message}", flush=True)

def monitor_dbus():
    cmd = [
        "dbus-monitor",
        "--session",
        "type='method_call',interface='org.freedesktop.Notifications',member='Notify'"
    ]
    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    except Exception as e:
        log_event("DBUS", f"Failed to start dbus-monitor: {e}", "\033[1;31m")
        return

    in_notify = False
    stage = -1
    app_name = ""
    replaces_id = 0
    app_icon = ""
    summary = ""
    body = ""
    image_path = ""
    expecting_image_path = False

    for line in proc.stdout:
        line_str = line.strip()
        if "member=Notify" in line_str:
            in_notify = True
            stage = 0
            app_name = ""
            replaces_id = 0
            app_icon = ""
            summary = ""
            body = ""
            image_path = ""
            expecting_image_path = False
            continue

        if not in_notify:
            continue

        if stage == 0 and line_str.startswith("string \""):
            app_name = line_str[8:-1]
            stage = 1
        elif stage == 1 and line_str.startswith("uint32 "):
            try:
                replaces_id = int(line_str.split()[1])
            except ValueError:
                pass
            stage = 2
        elif stage == 2 and line_str.startswith("string \""):
            app_icon = line_str[8:-1]
            stage = 3
        elif stage == 3 and line_str.startswith("string \""):
            summary = line_str[8:-1]
            stage = 4
        elif stage == 4 and line_str.startswith("string \""):
            body = line_str[8:-1]
            stage = 5
        elif stage == 5:
            if 'string "image-path"' in line_str or 'string "image_path"' in line_str:
                expecting_image_path = True
            elif expecting_image_path and line_str.startswith("string \""):
                image_path = line_str[8:-1]
                expecting_image_path = False
            elif line_str.startswith("int32 "):
                resolved_icon = app_icon or image_path or "(none)"
                log_event(
                    "NOTIFY",
                    f"App: '{app_name}' | Summary: '{summary}' | Body: '{body}' | Icon: '{resolved_icon}' (replaces_id={replaces_id})",
                    "\033[1;32m"
                )
                in_notify = False
                stage = -1

def monitor_udev():
    cmd = [
        "udevadm",
        "monitor",
        "--subsystem-match=power_supply",
        "--subsystem-match=backlight"
    ]
    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    except Exception as e:
        log_event("UDEV", f"Failed to start udevadm monitor: {e}", "\033[1;31m")
        return

    for line in proc.stdout:
        line_str = line.strip()
        if not line_str or line_str.startswith("monitor will print"):
            continue
        if "UDEV" in line_str or "KERNEL" in line_str:
            color = "\033[1;33m" if "power_supply" in line_str else "\033[1;35m"
            log_event("HARDWARE/UDEV", line_str, color)

def monitor_audio():
    cmd = ["pactl", "subscribe"]
    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    except Exception as e:
        log_event("AUDIO", f"Failed to start pactl subscribe: {e}", "\033[1;31m")
        return

    for line in proc.stdout:
        line_str = line.strip()
        if not line_str:
            continue
        if "source" in line_str or "sink" in line_str or "card" in line_str:
            log_event("AUDIO/PIPEWIRE", line_str, "\033[1;34m")

def print_status_snapshot():
    print("\n" + "="*70)
    print(" CURRENT HARDWARE / SYSTEM SNAPSHOT:")
    print("="*70)
    try:
        ac_online = open("/sys/class/power_supply/AC/online").read().strip()
        print(f" * AC Adapter Online: {'YES (1)' if ac_online == '1' else 'NO (0)'}")
    except Exception:
        pass

    try:
        for bat in os.listdir("/sys/class/power_supply"):
            if bat.startswith("BAT"):
                cap = open(f"/sys/class/power_supply/{bat}/capacity").read().strip()
                stat = open(f"/sys/class/power_supply/{bat}/status").read().strip()
                print(f" * Battery ({bat}): {cap}% | Status: {stat}")
    except Exception:
        pass

    try:
        for bl in os.listdir("/sys/class/backlight"):
            cur = open(f"/sys/class/backlight/{bl}/brightness").read().strip()
            mx = open(f"/sys/class/backlight/{bl}/max_brightness").read().strip()
            pct = round(int(cur) / int(mx) * 100)
            print(f" * Backlight ({bl}): {cur}/{mx} ({pct}%)")
    except Exception:
        pass

    try:
        sink_vol = subprocess.check_output(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], text=True).strip()
        print(f" * Audio Output (@DEFAULT_AUDIO_SINK@): {sink_vol}")
    except Exception:
        pass

    try:
        src_vol = subprocess.check_output(["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"], text=True).strip()
        print(f" * Audio Input (@DEFAULT_AUDIO_SOURCE@): {src_vol}")
    except Exception:
        pass

    print("="*70)
    print(" LIVE LISTENER STARTED! Press Ctrl+C to stop.")
    print(" You can now:")
    print("   1. Click brightness up / down keys")
    print("   2. Click microphone mute / unmute button")
    print("   3. Connect / disconnect your charger plug")
    print("="*70 + "\n", flush=True)

def main():
    print_status_snapshot()

    t_dbus = threading.Thread(target=monitor_dbus, daemon=True)
    t_udev = threading.Thread(target=monitor_udev, daemon=True)
    t_audio = threading.Thread(target=monitor_audio, daemon=True)

    t_dbus.start()
    t_udev.start()
    t_audio.start()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nListener stopped.")

if __name__ == "__main__":
    main()
