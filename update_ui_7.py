import sys

file_path = r'd:\UnHuman\Apps\Hello Chat\hellochat\lib\features\rooms\presentation\widgets\youtube_room_player.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add _showVolumeSlider to state
state_target = '''class _YouTubeRoomPlayerState extends ConsumerState<YouTubeRoomPlayer> {'''
state_replacement = '''class _YouTubeRoomPlayerState extends ConsumerState<YouTubeRoomPlayer> {
  bool _showVolumeSlider = false;'''

if state_target in content:
    content = content.replace(state_target, state_replacement, 1)

# Add volume button to Stack
stack_target = '''            // 🛑 Elegant Close Button (Owner only, positioned safely in top-left to avoid blocking native YouTube controls)
            if (_isOwner)
              Positioned(
                top: 12,
                left: 12,'''
                
stack_replacement = '''            // 🔊 Volume Control Button (Top Right, Owner only)
            if (_isOwner)
              Positioned(
                top: 12,
                right: 12,
                child: Row(
                  children: [
                    if (_showVolumeSlider)
                      Container(
                        width: 100,
                        height: 32,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                        ),
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          ),
                          child: Slider(
                            value: widget.room.youtubeVolume.toDouble(),
                            min: 0,
                            max: 100,
                            activeColor: Colors.white,
                            inactiveColor: Colors.white24,
                            onChanged: (val) {
                              if (_controller != null) {
                                _controller!.setVolume(val.toInt());
                                _roomService.updateRoomSettings(widget.room.roomId, {
                                  'youtubeVolume': val.toInt(),
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showVolumeSlider = !_showVolumeSlider;
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: Icon(
                          widget.room.youtubeVolume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 🛑 Elegant Close Button (Owner only, positioned safely in top-left to avoid blocking native YouTube controls)
            if (_isOwner)
              Positioned(
                top: 12,
                left: 12,'''

if stack_target in content:
    content = content.replace(stack_target, stack_replacement)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done")
else:
    print("Stack target not found")
