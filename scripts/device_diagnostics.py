import subprocess
import sys

ADB = r"C:\Users\Lenovo\AppData\Local\Android\Sdk\platform-tools\adb.exe"

def run_cmd(args):
    try:
        res = subprocess.run([ADB] + args, capture_output=True, text=True, timeout=8, errors="replace")
        return res.stdout.strip()
    except Exception as e:
        return f"ERROR: {e}"

print("=== LIVE DEVICE DIAGNOSTICS ===", flush=True)
devices = run_cmd(["devices"])
print(f"Device:\n{devices}", flush=True)

pid = run_cmd(["shell", "pidof", "com.example.hellochat"])
print(f"PID: {pid}", flush=True)

if pid and pid.isdigit():
    threads = run_cmd(["shell", f"cat /proc/{pid}/status"])
    for l in threads.splitlines():
        if "Threads:" in l or "VmSize:" in l or "VmRSS:" in l:
            print(f"Status: {l.strip()}", flush=True)

    fds = run_cmd(["shell", f"ls /proc/{pid}/fd"])
    fd_count = len([x for x in fds.split() if x])
    print(f"Open FDs: {fd_count}", flush=True)

    mem = run_cmd(["shell", "dumpsys", "meminfo", pid])
    for l in mem.splitlines():
        if any(k in l for k in ["TOTAL PSS:", "TOTAL:", "Native Heap", "Dalvik Heap", "Graphics:", "GL mtrack:"]):
            print(f"Mem: {l.strip()}", flush=True)

    gfx = run_cmd(["shell", "dumpsys", "gfxinfo", "com.example.hellochat"])
    for l in gfx.splitlines():
        if any(k in l for k in ["Total frames rendered:", "Janky frames:", "50th percentile:", "90th percentile:", "95th percentile:", "99th percentile:"]):
            print(f"Gfx: {l.strip()}", flush=True)
print("=== END DIAGNOSTICS ===", flush=True)
