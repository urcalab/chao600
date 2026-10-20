package cl.urcalab.chao600

/** The Chilean number families Chao 600 can block. */
enum class Prefix(val code: String) {
    P600("600"),
    P809("809"),
}

data class BlockConfig(
    val block600: Boolean = true,
    val block809: Boolean = true,
    /** Numbers that always ring, as [BlockRules.normalize] writes them. */
    val allowed: Set<String> = emptySet(),
) {
    fun blocks(prefix: Prefix) = when (prefix) {
        Prefix.P600 -> block600
        Prefix.P809 -> block809
    }
}

object BlockRules {
    // Android hands over the caller ID as the carrier sends it: E.164 (+56…), with
    // the 56 but no "+", or national. Unlike iOS, a pattern is enough; no number lists.
    // 600 XXX XXXX has 10 digits, 809 XXX XXX has 9.
    private val number600 = Regex("""^(?:(?:00)?56)?600\d{7}$""")
    private val number809 = Regex("""^(?:(?:00)?56)?809\d{6}$""")

    const val MAX_ALLOWED = 100

    /** A 600 or 809 number in national form ("6001234567"), whatever format it was typed or reported in; null for anything else. */
    fun normalize(number: String?): String? {
        val digits = number?.filter { it.isDigit() }?.removePrefix("00")?.removePrefix("56") ?: return null
        return digits.takeIf { number600.matches(it) || number809.matches(it) }
    }

    /** Which blocked family [number] belongs to under [config], or null if the call should ring. */
    fun match(number: String?, config: BlockConfig): Prefix? {
        val digits = number?.filter { it.isDigit() } ?: return null
        if (normalize(number) in config.allowed) return null
        return when {
            config.block600 && number600.matches(digits) -> Prefix.P600
            config.block809 && number809.matches(digits) -> Prefix.P809
            else -> null
        }
    }
}
