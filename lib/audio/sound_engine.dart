/// Plays music and effects without decoding a file on every tap.
abstract class SoundEngine {
  void unlock();

  /// [asset] is an AssetSource path, such as `audio/sfx/ui_tap.mp3`.
  void playEffect(String asset);

  /// Loop [asset], or stop the music when [asset] is null.
  void setMusic(String? asset);

  /// Loop [asset] quietly, or stop it.
  void setAmbience(bool on, String asset);

  void dispose();
}
