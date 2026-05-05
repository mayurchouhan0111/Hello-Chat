import 'package:flutter/material.dart';
import 'package:pod_player/pod_player.dart';

void main() {
  final controller = PodPlayerController(playVideoFrom: PlayVideoFrom.youtube('test'));
  PodVideoPlayer(
    controller: controller,
    // overlay: Container(), // error - The named parameter 'overlay' isn't defined.
    // customOverlay: Container(), 
    // overlayBuilder: (context) => Container(),
    // videoOverlay: Container(),
  );
}
