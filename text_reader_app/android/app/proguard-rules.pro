# Flutter specific ProGuard rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class androidx.lifecycle.** { *; }

# VibeVoice TTS specific rules
-keep class com.vibevoice.** { *; }

# Keep annotations
-keepattributes *Annotation*

# For native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep setters in Views
-keepclassmembers public class * extends android.view.View {
    void set*(***);
    *** get*();
}