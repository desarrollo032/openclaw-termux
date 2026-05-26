package com.nxg.openclawproot.handlers

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

interface BaseHandler {
    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result): Boolean
}
