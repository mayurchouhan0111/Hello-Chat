with open("lib/features/rooms/presentation/screens/live_room_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
    
for i, line in enumerate(lines):
    if "_buildGlassOverlay" in line:
        print(f"Line {i+1}: {line.strip()}")
