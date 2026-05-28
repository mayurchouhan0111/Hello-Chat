import sys

file_path = r'd:\UnHuman\Apps\Hello Chat\hellochat\lib\features\rooms\presentation\widgets\gift_panel.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

target = '''    // Filter to show Host + Anyone on Seats + Target User (exclude current user - no self-gifting)
    final recipients = participants.where((p) => 
      (p.role == 'host' || p.seatIndex != -1 || p.uid == widget.targetUid) && p.uid != currentUserUid
    ).toList();'''

replacement = '''    // Filter to show Host + Anyone on Seats + Target User (exclude current user - no self-gifting)
    final recipients = participants.where((p) => 
      (p.role == 'host' || p.seatIndex != -1 || p.uid == widget.targetUid) && p.uid != currentUserUid
    ).toList();

    // Move selected target to the front of the list so they are immediately visible
    if (_selectedTargetUid != null) {
      final selectedIndex = recipients.indexWhere((p) => p.uid == _selectedTargetUid);
      if (selectedIndex > 0) {
        final selectedUser = recipients.removeAt(selectedIndex);
        recipients.insert(0, selectedUser);
      }
    }'''

if target in content:
    content = content.replace(target, replacement)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done")
else:
    print("Target not found")
