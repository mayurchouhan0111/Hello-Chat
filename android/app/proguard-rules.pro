# Stripe Push Provisioning missing classes workaround
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.reactnativestripesdk.pushprovisioning.**

# Optional: Add any other missing classes if they appear
-dontwarn com.stripe.android.**
-keep class com.stripe.android.** { *; }
