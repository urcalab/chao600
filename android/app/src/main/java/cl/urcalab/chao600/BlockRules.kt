package cl.urcalab.chao600

/** The Chilean number families Chao 600 can block. */
enum class Prefix(val code: String) {
    P600("600"),
    P809("809"),
}

data class BlockConfig(
    val block600: Boolean = true,
    val block809: Boolean = true,
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

    /** Which blocked family [number] belongs to under [config], or null if the call should ring. */
    fun match(number: String?, config: BlockConfig): Prefix? {
        val digits = number?.filter { it.isDigit() } ?: return null
        return when {
            config.block600 && number600.matches(digits) -> Prefix.P600
            config.block809 && number809.matches(digits) -> Prefix.P809
            else -> null
        }
    }
}
