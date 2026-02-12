# Flutter-specific rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Keep native method names
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep Hive models
-keep class ** implements com.google.gson.TypeAdapterFactory
-keep class ** implements com.google.gson.JsonSerializer
-keep class ** implements com.google.gson.JsonDeserializer

# AudioPlayers
-keep class xyz.luan.audioplayers.** { *; }

# Prevent stripping of native methods used by Flutter
-keep class com.sukoon.launcher.** { *; }
