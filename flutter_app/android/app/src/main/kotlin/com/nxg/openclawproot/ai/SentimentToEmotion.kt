package com.nxg.openclawproot.ai

/**
 * Simple keyword-based sentiment analyzer for mapping LLM responses to orb emotions.
 *
 * Scoring:
 *  1. Counts positive, negative, question, surprised, and calm keywords.
 *  2. Whichever category has the highest count wins.
 *  3. If all counts are zero → "speaking" (neutral).
 *  4. If positive and negative tie → "thinking".
 */
object SentimentToEmotion {

    private val positiveWords = setOf(
        "great", "awesome", "fantastic", "excellent", "wonderful", "amazing", "love",
        "perfect", "beautiful", "brilliant", "delightful", "glad", "happy", "joy",
        "pleased", "splendid", "superb", "terrific", "thank", "thanks", "cool",
        "nice", "good", "best", "excited", "welcome", "absolutely", "yes",
        "genial", "maravilloso", "excelente", "fantástico", "feliz", "alegre",
        "encantado", "perfecto", "hermoso", "gracias", "estupendo"
    )

    private val negativeWords = setOf(
        "sorry", "apologize", "error", "failed", "failure", "cannot", "can't",
        "unable", "mistake", "wrong", "bad", "terrible", "horrible", "awful",
        "problem", "issue", "broken", "crash", "exception", "invalid",
        "lo siento", "error", "fallo", "problema", "incorrecto", "mal"
    )

    private val questionIndicators = setOf(
        "what", "why", "how", "when", "where", "who", "which",
        "could you", "would you", "can you", "do you", "does",
        "qué", "cómo", "por qué", "cuándo", "dónde", "quién"
    )

    private val surpriseWords = setOf(
        "wow", "whoa", "oh", "really", "no way", "incredible",
        "unbelievable", "surprising", "surprised", "unexpected",
        "guau", "increíble", "sorprendente", "no puede ser", "vaya"
    )

    private val calmWords = setOf(
        "sure", "okay", "ok", "fine", "alright", "of course",
        "certainly", "absolutely", "relax", "easy", "calm",
        "seguro", "claro", "vale", "bien", "tranquilo", "despacio"
    )

    /**
     * Analyze the text and return an emotion string:
     *  "happy", "error", "thinking", "surprised", "calm", or "speaking".
     */
    fun analyze(text: String): String {
        val lower = text.lowercase()
        val words = lower.split(Regex("[\\s,.;:!?¡¿\\-]+"))

        val positiveScore = words.count { it in positiveWords }
        val negativeScore = words.count { it in negativeWords }
        val questionScore = words.count { it in questionIndicators }
        val surpriseScore = words.count { it in surpriseWords }
        val calmScore = words.count { it in calmWords }

        // Also check if the text ends with a question mark
        val endsWithQuestion = text.trim().endsWith("?") || text.trim().endsWith("¿")

        // Build map of scores
        val scores = mapOf(
            "positive" to positiveScore + (if (lower.contains("thank") || lower.contains("gracias")) 1 else 0),
            "negative" to negativeScore,
            "question" to questionScore + (if (endsWithQuestion) 2 else 0),
            "surprised" to surpriseScore,
            "calm" to calmScore,
        )

        val bestPair = scores.maxByOrNull { it.value }
            ?: return "speaking"

        // If no keywords found
        if (bestPair.value == 0) return "speaking"

        // Tie between positive & negative → thinking
        if (scores["positive"] == scores["negative"] &&
            scores["positive"]!! > 0 &&
            scores["negative"]!! > 0
        ) {
            return "thinking"
        }

        return bestPair.key
    }
}
