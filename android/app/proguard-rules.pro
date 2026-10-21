# uCrop (Image Cropper) configuration
-dontwarn com.yalantis.ucrop**
-keep class com.yalantis.ucrop** { *; }
-keep interface androidx.lifecycle.** { *; }

# OkHttp3 (referenced by uCrop)
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Okio (referenced by OkHttp3)
-dontwarn okio.**
-keep class okio.** { *; }
-keep interface okio.** { *; }

# SLF4J
-dontwarn org.slf4j.**