package com.example.flutterskilltest

import android.app.Application
import com.flutterskill.FlutterSkillBridge

class TestApp : Application() {
    override fun onCreate() {
        super.onCreate()
        FlutterSkillBridge.start(this, appName = "FlutterSkillTestApp")
    }
}
