package com.imexglobalintl.unbrick

import android.content.Context
import org.json.JSONObject

data class Vocab(val ko: String, val en: String, val ru: String)
data class Line(val speaker: String, val ko: String, val en: String, val ru: String)
data class StudyUnit(
    val id: String,
    val level: Int,
    val n: Int,
    val ko: String,
    val en: String,
    val ru: String,
    val vocab: List<Vocab>,
    val dialogue: List<Line>,
)

object ContentRepository {
    fun load(context: Context): List<StudyUnit> {
        val text = context.assets.open("content.json").bufferedReader().use { it.readText() }
        val units = JSONObject(text).getJSONArray("units")
        return buildList {
            for (i in 0 until units.length()) {
                val unit = units.getJSONObject(i)
                val vocabJson = unit.getJSONArray("vocab")
                val dialogueJson = unit.getJSONArray("dialogue")
                val level = unit.optInt("level", 3)
                val n = unit.getInt("n")
                add(
                    StudyUnit(
                        id = "$level-$n",
                        level = level,
                        n = n,
                        ko = unit.getString("ko"),
                        en = unit.getString("en"),
                        ru = unit.getString("ru"),
                        vocab = buildList {
                            for (v in 0 until vocabJson.length()) {
                                val word = vocabJson.getJSONObject(v)
                                if (word.optString("ko").isEmpty()) continue
                                add(Vocab(word.getString("ko"), word.optString("en"), word.optString("ru")))
                            }
                        },
                        dialogue = buildList {
                            for (d in 0 until dialogueJson.length()) {
                                val line = dialogueJson.getJSONObject(d)
                                if (line.optString("ko").isEmpty()) continue
                                add(Line(line.optString("speaker"), line.getString("ko"), line.optString("en"), line.optString("ru")))
                            }
                        },
                    )
                )
            }
        }
    }
}
