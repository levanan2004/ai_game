import 'sound_engine.dart';

SoundEngine createSoundEngine() => _SilentEngine();

class _SilentEngine implements SoundEngine {
  @override
  void dispose() {}

  @override
  void playEffect(String asset) {}

  @override
  void setAmbience(bool on, String asset) {}

  @override
  void setMusic(String? asset) {}

  @override
  void unlock() {}
}
