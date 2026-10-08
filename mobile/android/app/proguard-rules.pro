# Flutter engine and embedding
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# speech_to_text uses platform recognition services reached reflectively
-keep class android.speech.** { *; }

# flutter_secure_storage
-keep class androidx.security.crypto.** { *; }

# Suppress warnings for optional Play Core classes the engine references but
# this app does not use (deferred components).
-dontwarn com.google.android.play.core.**
