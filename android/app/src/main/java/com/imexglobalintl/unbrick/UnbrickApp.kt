package com.imexglobalintl.unbrick

import android.speech.RecognizerIntent
import android.speech.tts.TextToSpeech
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Locale

private enum class Tab { Lessons, Tutor, Blocking }

private val Ink = Color(0xFFF5F5F7)
private val Muted = Color(0xFF8E8E99)
private val Bg = Color(0xFF06070B)

@Composable
fun UnbrickApp(lessons: List<StudyUnit>) {
    var tab by remember { mutableStateOf(Tab.Lessons) }
    var russian by remember { mutableStateOf(false) }
    MaterialTheme(colorScheme = darkColorScheme(background = Bg, surface = Color(0xFF11141C), primary = Color(0xFF5E5CE6))) {
        Scaffold(
            containerColor = Bg,
            bottomBar = {
                NavigationBar(containerColor = Color(0xFF11141C)) {
                    NavigationBarItem(selected = tab == Tab.Lessons, onClick = { tab = Tab.Lessons }, icon = {}, label = { Text("Lessons") })
                    NavigationBarItem(selected = tab == Tab.Tutor, onClick = { tab = Tab.Tutor }, icon = {}, label = { Text("Tutor") })
                    NavigationBarItem(selected = tab == Tab.Blocking, onClick = { tab = Tab.Blocking }, icon = {}, label = { Text("Blocking") })
                }
            },
        ) { padding ->
            Column(Modifier.fillMaxSize().padding(padding).padding(16.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(selected = !russian, onClick = { russian = false }, label = { Text("English") })
                    FilterChip(selected = russian, onClick = { russian = true }, label = { Text("Русский") })
                }
                Box(Modifier.weight(1f).fillMaxWidth()) {
                    when (tab) {
                        Tab.Lessons -> LessonsScreen(lessons, russian)
                        Tab.Tutor -> TutorScreen(lessons, russian)
                        Tab.Blocking -> BlockingScreen()
                    }
                }
            }
        }
    }
}

@Composable
private fun LessonsScreen(lessons: List<StudyUnit>, russian: Boolean) {
    var open by remember { mutableStateOf("") }
    val levels = lessons.map { it.level }.distinct().sorted()
    var level by remember(levels) { mutableIntStateOf(levels.firstOrNull { it == 3 } ?: levels.firstOrNull() ?: 0) }
    if (open.isNotEmpty()) {
        val unit = lessons.firstOrNull { it.id == open }
        Column(Modifier.fillMaxSize()) {
            Button(onClick = { open = "" }) { Text("All units") }
            if (unit == null) {
                Text("That unit is not in the shared lessons file.", color = Muted)
            } else {
                Text("L${unit.level} · ${unit.n}. ${unit.ko}", color = Ink, style = MaterialTheme.typography.titleLarge)
                Text(if (russian) unit.ru else unit.en, color = Muted)
                Text("Vocabulary", color = Ink, modifier = Modifier.padding(top = 12.dp))
                LazyColumn(Modifier.weight(1f)) {
                    items(unit.vocab) { word ->
                        Text(word.ko, color = Ink)
                        Text(if (russian) word.ru else word.en, color = Muted, modifier = Modifier.padding(bottom = 8.dp))
                    }
                    item { Text("Dialogue", color = Ink, modifier = Modifier.padding(top = 8.dp)) }
                    items(unit.dialogue) { line ->
                        Text("${line.speaker}: ${line.ko}", color = Ink)
                        Text(if (russian) line.ru else line.en, color = Muted, modifier = Modifier.padding(bottom = 8.dp))
                    }
                }
            }
        }
        return
    }
    if (lessons.isEmpty()) {
        Text("Lessons didn't load. The shared Content.json is copied in at build time.", color = Muted, modifier = Modifier.padding(top = 12.dp))
        return
    }
    Column(Modifier.fillMaxSize().padding(top = 12.dp)) {
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            levels.forEach { lv ->
                FilterChip(selected = level == lv, onClick = { level = lv }, label = { Text("L$lv") })
            }
        }
        val shown = lessons.filter { it.level == level }
        if (shown.isEmpty()) {
            Text("No lessons for this level.", color = Muted, modifier = Modifier.padding(top = 12.dp))
            return
        }
        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxSize().padding(top = 12.dp)) {
            items(shown, key = { it.id }) { unit ->
                Button(onClick = { open = unit.id }, modifier = Modifier.fillMaxWidth()) {
                    Text("L${unit.level} · ${unit.n}. ${unit.ko} · ${if (russian) unit.ru else unit.en}")
                }
            }
        }
    }
}

@Composable
private fun TutorScreen(lessons: List<StudyUnit>, russian: Boolean) {
    val context = LocalContext.current
    val client = remember(context) { TutorClient(BuildConfig.API_BASE, BuildConfig.APP_TOKEN, DeviceId.get(context)) }
    val scope = rememberCoroutineScope()
    var input by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var lines by remember { mutableStateOf(listOf<String>()) }
    var turns by remember { mutableStateOf(listOf<Pair<String, String>>()) }
    val tts = remember { TextToSpeech(context) { } }
    DisposableEffect(Unit) { onDispose { tts.shutdown() } }

    val recognize = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        val heard = result.data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()
        if (!heard.isNullOrBlank()) input = heard
    }
    val micPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) recognize.launch(recognizerIntent())
    }

    LaunchedEffect(client.configured) {
        if (!client.configured || turns.isNotEmpty()) return@LaunchedEffect
        val opening = listOf("user" to "Start the session with your first question.")
        turns = opening
        busy = true
        val reply = runCatching { withContext(Dispatchers.IO) { client.tutor(systemPrompt(lessons, russian), opening) } }
        reply.onSuccess { r ->
            lines = listOf(listOf(r.feedback, r.question, r.gloss).filter { it.isNotBlank() }.joinToString("\n"))
            turns = opening + ("assistant" to JSONObjectLite(r.verdict, r.question))
        }.onFailure { err -> lines = listOf(tutorFailureLine(err.message)) }
        busy = false
    }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxSize().padding(top = 12.dp)) {
        if (!client.configured) {
            Text(
                "Claude is off until UNBRICK_API_BASE and UNBRICK_APP_TOKEN are in android/local.properties. The key stays on the server.",
                color = Muted,
            )
        }
        LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(lines) { line -> Text(line, color = Ink) }
        }
        OutlinedTextField(value = input, onValueChange = { input = it }, modifier = Modifier.fillMaxWidth(), label = { Text("한국어로") })
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { micPermission.launch(android.Manifest.permission.RECORD_AUDIO) }) { Text("Mic") }
            Button(
                enabled = !busy && input.isNotBlank() && client.configured,
                onClick = {
                    val said = input.trim()
                    input = ""
                    val nextTurns = turns + ("user" to "Learner answer: $said")
                    turns = nextTurns
                    lines = lines + "You: $said"
                    busy = true
                    scope.launch {
                        val reply = runCatching {
                            withContext(Dispatchers.IO) {
                                client.tutor(systemPrompt(lessons, russian), nextTurns)
                            }
                        }
                        reply.onSuccess { r ->
                            val shown = listOf(r.feedback, r.question, r.gloss).filter { it.isNotBlank() }.joinToString("\n")
                            lines = lines + "Tutor: $shown"
                            turns = nextTurns + ("assistant" to JSONObjectLite(r.verdict, r.question))
                            if (r.question.isNotBlank()) tts.speak(r.question, TextToSpeech.QUEUE_FLUSH, null, "q")
                        }.onFailure { err ->
                            lines = lines + tutorFailureLine(err.message)
                        }
                        busy = false
                    }
                },
            ) { Text(if (busy) "…" else "Send") }
        }
    }
}

private fun tutorFailureLine(message: String?): String {
    val text = message?.takeIf { it.isNotBlank() } ?: "Tutor failed."
    return if (text.startsWith("AI tutor is resting")) text else "Error: $text"
}

private fun recognizerIntent() = android.content.Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ko-KR")
}

private fun systemPrompt(lessons: List<StudyUnit>, russian: Boolean): String {
    val lang = if (russian) "Russian" else "English"
    val covered = lessons.map { it.level }.distinct().sorted().joinToString(", ")
    val scope = if (covered.isBlank()) "KIIP levels 0 through 5." else "Loaded lessons cover KIIP levels $covered."
    return "You are a Korean tutor. The learner's native language is $lang. $scope Ask one short question in Korean and give feedback in $lang."
}

private fun JSONObjectLite(verdict: String, question: String) =
    """{"verdict":"${verdict.replace("\"", "'")}","question":"${question.replace("\"", "'")}"}"""

@Composable
private fun BlockingScreen() {
    Column(Modifier.padding(top = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("App blocking is not in this Android build.", color = Ink, style = MaterialTheme.typography.titleLarge)
        Text(
            "iOS uses Screen Time, and later Family Controls, which do not exist on Android. A real block here needs its own design: a usage-access prompt, an accessibility service or device-policy controller, and a shield the learner cannot swipe away. None of that is wired up. The lesson JSON and the Claude proxy are the pieces this scaffold shares with the iPhone app.",
            color = Muted,
        )
    }
}
