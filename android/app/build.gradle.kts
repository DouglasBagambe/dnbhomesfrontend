import java.util.Properties
import java.io.FileInputStream
import java.net.URI
import java.util.Base64

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystoreFile = rootProject.file("key.properties")
if (keystoreFile.exists()) {
    keystoreProperties.load(FileInputStream(keystoreFile))
}

android {
    namespace = "com.nilebitlabs.dnbhomes"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    defaultConfig {
        applicationId = "com.nilebitlabs.dnbhomes"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }
    signingConfigs {
        create("release") {
            if (keystoreFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
    flavorDimensions += "environment"
    productFlavors {
        create("development") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Homes Dev")
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "Homes Staging")
        }
        create("production") {
            dimension = "environment"
            resValue("string", "app_name", "Homes")
        }
    }
    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            if (keystoreFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}
flutter { source = "../.." }
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // shared_preferences' older DataStore binary has misaligned 16 KB RELRO segments.
    implementation("androidx.datastore:datastore-preferences:1.2.1")
}

// This runs even for direct Gradle/CI invocations, before any release task executes.
gradle.taskGraph.whenReady {
    // Flutter prepares sibling debug variants even during development builds.
    // Gate the requested product, not those incidental preparation tasks.
    val requested = gradle.startParameter.taskNames.map { it.substringAfterLast(":") }
    val production = requested.any { it.contains("Production", ignoreCase = true) || it in listOf("assemble", "bundle", "build", "assembleRelease", "bundleRelease", "assembleDebug") } && allTasks.any { it.project == project && it.name.contains("Production") }
    val release = allTasks.any { it.project == project && it.name.contains("ProductionRelease") }
    if (production) {
        val defines = (project.findProperty("dart-defines") as? String ?: "").split(",").filter { it.isNotBlank() }.associate {
            val pair = String(Base64.getDecoder().decode(it)).split("=", limit = 2)
            pair[0] to pair.getOrElse(1) { "" }
        }
        check(defines["HOMES_ENV"] == "production") { "Production flavor requires HOMES_ENV=production" }
        val uri = runCatching { URI(defines["HOMES_API_URL"] ?: "") }.getOrNull()
        val host = uri?.host.orEmpty().lowercase()
        val localValidation = System.getenv("HOMES_BUILD_PROFILE") == "local"
        val loopback = host in listOf("localhost", "127.0.0.1", "[::1]")
        val reserved = !host.contains(".") || host.matches(Regex("[0-9.]+")) || host.contains(":") || host.matches(Regex(".*\\.(invalid|test|local|localhost|example)$")) || host.matches(Regex("(^|.*\\.)example\\.(com|net|org)$"))
        check(uri != null && uri.userInfo == null && uri.query == null && uri.fragment == null && uri.path == "/api/v1" &&
            (if (localValidation) loopback && uri.scheme in listOf("http", "https") else uri.scheme == "https" && !reserved)) {
            "Production requires an explicit public HTTPS HOMES_API_URL ending /api/v1; placeholder/local defaults are forbidden"
        }
        if (localValidation) {
            check(!keystoreFile.exists() && defines["HOMES_BUILD_VALIDATION"] == "true") { "Local production validation must be explicitly marked and unsigned" }
        }
        if (release && !localValidation) {
            check(keystoreFile.exists()) { "Production release requires android/key.properties and a real upload keystore; use the documented local unsigned validation profile for QA" }
            for (key in listOf("storeFile", "storePassword", "keyAlias", "keyPassword")) check(!keystoreProperties.getProperty(key).isNullOrBlank()) { "Missing signing property: $key" }
            check(file(keystoreProperties.getProperty("storeFile")).isFile) { "Upload keystore does not exist" }
        }
    }
}
