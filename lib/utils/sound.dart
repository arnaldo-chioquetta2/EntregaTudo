import 'package:audioplayers/audioplayers.dart';

// 1.3.9 Fornecedor recebe aviso pelo App sobre a venda

final AudioPlayer _player = AudioPlayer();

Future<void> tocarSomVenda() async {
  try {
    await _player.play(
      AssetSource('audio/Voz.mp3'),
      volume: 1.0,
    );
  } catch (e) {
    print('Erro ao tocar som de venda: $e');
  }
}
