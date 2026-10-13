import subprocess
import time

ADB = r"C:\Users\Lenovo\AppData\Local\Android\Sdk\platform-tools\adb.exe"
DEVICE = "1374223603000CJ"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE] + args
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return res.stdout.strip()

def tap(x, y):
    run_adb(["shell", "input", "tap", str(x), str(y)])

def back():
    run_adb(["shell", "input", "keyevent", "4"])

def screenshot(name="test_device_screen.png"):
    run_adb(["shell", "screencap", "-p", "/sdcard/screen.png"])
    run_adb(["pull", "/sdcard/screen.png", name])

if __name__ == "__main__":
    back()
    time.sleep(1)
    screenshot()
    print("Back pressed and screenshot captured.")
