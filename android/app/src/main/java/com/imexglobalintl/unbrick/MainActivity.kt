package com.imexglobalintl.unbrick

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val lessons = runCatching { ContentRepository.load(this) }.getOrElse { emptyList() }
        setContent { UnbrickApp(lessons) }
    }
}
