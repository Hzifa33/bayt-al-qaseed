# Flutter & Embedding
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# SQLite3 native FFI library (sqlite3_flutter_libs)
-keep class eu.simonbinder.sqlite3_flutter_libs.** { *; }
-dontwarn eu.simonbinder.sqlite3_flutter_libs.**

# Share Plus & FileProvider
-keep class dev.fluttercommunity.plus.share.** { *; }
-keep class androidx.core.content.FileProvider { *; }

# XZ / LZMA2 pure-Java streaming decompressor
-keep class org.tukaani.xz.** { *; }

# Keep native methods intact
-keepclasseswithmembernames class * {
    native <methods>;
}
