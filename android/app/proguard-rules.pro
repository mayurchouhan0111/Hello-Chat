# ── Stripe Push Provisioning ──────────────────────────────────────────────────
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.reactnativestripesdk.pushprovisioning.**
-dontwarn com.stripe.android.**
-keep class com.stripe.android.** { *; }

# ── Agora RTC SDK (JNI callbacks & reflection) ──────────────────────────────
-keep class io.agora.** { *; }
-dontwarn io.agora.**
-keepclassmembers class io.agora.** { *; }

# ── Firebase (all modules) ───────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.firebase.iid.** { *; }
-keep class com.google.firebase.messaging.** { *; }

# ── Google Play Services (Auth, etc.) ────────────────────────────────────────
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ── Facebook SDK (flutter_facebook_auth) ─────────────────────────────────────
-keep class com.facebook.** { *; }
-dontwarn com.facebook.**
-keepclassmembers class com.facebook.** { *; }

# ── Flutter engine & plugins ─────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
-keep class io.flutter.plugins.** { *; }

# ── SVGA Player Flutter (reflection-based parsing) ───────────────────────────
-keep class com.opensource.svgaplayer.** { *; }
-dontwarn com.opensource.svgaplayer.**

# ── Lottie animations ────────────────────────────────────────────────────────
-keep class com.airbnb.lottie.** { *; }
-dontwarn com.airbnb.lottie.**
-keep class com.github.penfeizhou.android.animation.** { *; }
-dontwarn com.github.penfeizhou.android.animation.**

# ── Image loading (cached_network_image / flutter_cache_manager) ──────────────
-keep class com.bumptech.glide.** { *; }
-dontwarn com.bumptech.glide.**

# ── Kotlin / Kotlinx ─────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-dontwarn kotlin.**
-keep class kotlinx.** { *; }
-dontwarn kotlinx.**

# ── OkHttp / Dio networking ──────────────────────────────────────────────────
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-keep class okio.** { *; }
-dontwarn okio.**

# ── General Android / Java ───────────────────────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes Exceptions
-keepattributes InnerClasses,EnclosingMethod

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep Parcelable classes
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
