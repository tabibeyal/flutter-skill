pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "FlutterSkillTestApp"
include(":app")
include(":flutterskill-sdk")
project(":flutterskill-sdk").projectDir = file("../../../sdks/android")
