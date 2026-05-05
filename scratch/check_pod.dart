import 'package:pod_player/pod_player.dart';

void main() {
  final controller = PodPlayerController(playVideoFrom: PlayVideoFrom.youtube('test'));
  print(controller.videoPlayerController);
}
