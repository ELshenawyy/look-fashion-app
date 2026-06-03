# ── Flutter ──────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ── Firebase Core ─────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── Firebase Auth ─────────────────────────────────────────────────────────
-keep class com.google.firebase.auth.** { *; }
-keepclassmembers class com.google.firebase.auth.** { *; }

# ── Firebase Firestore ────────────────────────────────────────────────────
-keep class com.google.firebase.firestore.** { *; }
-keepclassmembers class com.google.firebase.firestore.** { *; }

# ── Firebase Storage ──────────────────────────────────────────────────────
-keep class com.google.firebase.storage.** { *; }

# ── Firebase App Check / Play Integrity ───────────────────────────────────
-keep class com.google.firebase.appcheck.** { *; }
-keep class com.google.android.play.core.integrity.** { *; }
-dontwarn com.google.android.play.core.**

# ── Firebase Messaging (FCM) ──────────────────────────────────────────────
-keep class com.google.firebase.messaging.** { *; }

# ── GetIt / Dependency Injection ─────────────────────────────────────────
-keep class ** implements com.google.firebase.** { *; }

# ── Kotlin ────────────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**

# ── Gson / JSON serialization ─────────────────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**

# ── General — منع حذف أي class يستخدم reflection ─────────────────────────
-keepattributes EnclosingMethod
-keepattributes InnerClasses
