package com.imexglobalintl.unbrick

import android.content.Context
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

data class TutorReply(val feedback: String, val question: String, val gloss: String, val verdict: String)

object DeviceId {
    private val pattern = Regex("^[A-Za-z0-9_-]{8,80}$")
    private const val badEmulatorId = "9774d56d682e549c"

    fun get(context: Context): String {
        val prefs = context.getSharedPreferences("unbrick.device", Context.MODE_PRIVATE)
        val existing = prefs.getString("id", null)
        if (existing != null && existing.matches(pattern)) return existing
        val androidId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
        val id = if (androidId != null && androidId != badEmulatorId && androidId.matches(pattern)) {
            androidId
        } else {
            UUID.randomUUID().toString()
        }
        prefs.edit().putString("id", id).apply()
        return id
    }
}

class TutorClient(private val base: String, private val token: String, private val device: String) {
    val configured: Boolean get() = base.startsWith("https://") && token.isNotEmpty()

    fun tutor(system: String, turns: List<Pair<String, String>>): TutorReply {
        val messages = JSONArray()
        for ((role, content) in turns) {
            messages.put(JSONObject().put("role", role).put("content", content))
        }
        val body = JSONObject()
            .put("task", "tutor")
            .put("system", system)
            .put("messages", messages)
            .put("effort", "low")
        val url = URL(base.trimEnd('/') + "/v1/task")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 20_000
            readTimeout = 90_000
            doOutput = true
            setRequestProperty("content-type", "application/json")
            setRequestProperty("X-Unbrick-Token", token)
            setRequestProperty("X-Unbrick-Device", device)
        }
        conn.outputStream.use { it.write(body.toString().toByteArray()) }
        val code = conn.responseCode
        val stream = if (code in 200..299) conn.inputStream else conn.errorStream
        val text = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
        val json = if (text.isBlank()) JSONObject() else JSONObject(text)
        if (code == 429) error(json.optJSONObject("error")?.optString("message") ?: "Too many requests.")
        if (code !in 200..299) error(json.optJSONObject("error")?.optString("message") ?: "Tutor failed ($code).")
        return TutorReply(
            feedback = json.optString("feedback"),
            question = json.optString("question"),
            gloss = json.optString("gloss"),
            verdict = json.optString("verdict"),
        )
    }
}
