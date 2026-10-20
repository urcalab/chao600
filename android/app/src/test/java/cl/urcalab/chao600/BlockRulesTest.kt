package cl.urcalab.chao600

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class BlockRulesTest {
    private val both = BlockConfig()

    @Test fun blocks600InEveryFormat() {
        listOf("+56600123 4567", "+566001234567", "566001234567", "6001234567", "600 123 4567", "0056600123 4567", "(600) 123-4567")
            .forEach { assertEquals(it, Prefix.P600, BlockRules.match(it, both)) }
    }

    @Test fun blocks809InEveryFormat() {
        listOf("+56809123456", "56809123456", "809123456", "809 123 456")
            .forEach { assertEquals(it, Prefix.P809, BlockRules.match(it, both)) }
    }

    @Test fun letsNormalCallsThrough() {
        listOf(
            "+56912345678", // mobile
            "+56221234567", // Santiago landline
            "+5628091234", // too short to be an 809
            "+560809123456", // wrong length
            "+566001234", // truncated 600
            "+566001234567890", // overlong
            "+14155550123", // abroad
            "+56912600123", // 600 in the middle
            "800123456", // 800 is not blocked
            "", null,
        ).forEach { assertNull(it, BlockRules.match(it, both)) }
    }

    @Test fun respectsToggles() {
        assertNull(BlockRules.match("6001234567", BlockConfig(block600 = false)))
        assertEquals(Prefix.P809, BlockRules.match("809123456", BlockConfig(block600 = false)))
        assertNull(BlockRules.match("809123456", BlockConfig(block809 = false)))
        assertNull(BlockRules.match("6001234567", BlockConfig(block600 = false, block809 = false)))
    }

    @Test fun formatsNumbers() {
        assertEquals("600 123 4567", formatNumber("+566001234567"))
        assertEquals("809 123 456", formatNumber("809123456"))
        assertEquals("anon", formatNumber("anon"))
    }
}
