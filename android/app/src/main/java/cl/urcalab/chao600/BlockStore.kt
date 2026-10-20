package cl.urcalab.chao600

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONArray
import org.json.JSONObject

data class BlockedCall(val number: String, val prefix: Prefix, val timeMillis: Long)

/**
 * Settings and the blocked-call log, kept in this app's private storage and nowhere else.
 *
 * The screening service and the activity run in the same process, so the flows
 * below update the open screen the moment a call is blocked.
 */
class BlockStore private constructor(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("chao600", Context.MODE_PRIVATE)
    private val lock = Any()

    private val _config = MutableStateFlow(
        BlockConfig(
            prefs.getBoolean(KEY_600, true),
            prefs.getBoolean(KEY_809, true),
            prefs.getStringSet(KEY_ALLOWED, null)?.toSet().orEmpty(),
        ),
    )
    val config: StateFlow<BlockConfig> = _config.asStateFlow()

    private val _log = MutableStateFlow(readLog())
    val log: StateFlow<List<BlockedCall>> = _log.asStateFlow()

    fun setConfig(config: BlockConfig) {
        prefs.edit()
            .putBoolean(KEY_600, config.block600)
            .putBoolean(KEY_809, config.block809)
            .putStringSet(KEY_ALLOWED, config.allowed)
            .apply()
        _config.value = config
    }

    /** Newest first, capped so the log can't grow without bound. */
    fun record(call: BlockedCall) = synchronized(lock) {
        val updated = (listOf(call) + _log.value).take(MAX_ENTRIES)
        prefs.edit().putString(KEY_LOG, encode(updated)).apply()
        _log.value = updated
    }

    fun clearLog() = synchronized(lock) {
        prefs.edit().remove(KEY_LOG).apply()
        _log.value = emptyList()
    }

    private fun readLog(): List<BlockedCall> = runCatching {
        val array = JSONArray(prefs.getString(KEY_LOG, "[]"))
        List(array.length()) { i ->
            val o = array.getJSONObject(i)
            BlockedCall(o.getString("n"), Prefix.valueOf(o.getString("p")), o.getLong("t"))
        }
    }.getOrDefault(emptyList())

    private fun encode(calls: List<BlockedCall>) = JSONArray().apply {
        calls.forEach { put(JSONObject().put("n", it.number).put("p", it.prefix.name).put("t", it.timeMillis)) }
    }.toString()

    companion object {
        private const val KEY_600 = "block600"
        private const val KEY_809 = "block809"
        private const val KEY_ALLOWED = "allowed"
        private const val KEY_LOG = "log"
        const val MAX_ENTRIES = 500

        @Volatile private var instance: BlockStore? = null

        fun get(context: Context): BlockStore =
            instance ?: synchronized(this) { instance ?: BlockStore(context).also { instance = it } }
    }
}
