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

    @Test fun normalizesOnly600And809() {
        listOf("+56 600 123 4567", "6001234567", "0056 600 123 4567", "(600) 123-4567")
            .forEach { assertEquals(it, "6001234567", BlockRules.normalize(it)) }
        assertEquals("809123456", BlockRules.normalize("+56809123456"))
        listOf("+56912345678", "600123", "800123456", "", null).forEach { assertNull(it, BlockRules.normalize(it)) }
    }

    @Test fun allowedNumbersRingInEveryFormat() {
        val config = BlockConfig(allowed = setOf("6001234567", "809123456"))
        listOf("+566001234567", "566001234567", "6001234567", "600 123 4567", "0056 600 123 4567", "+56809123456", "809123456")
            .forEach { assertNull(it, BlockRules.match(it, config)) }
    }

    @Test fun allowingOneNumberKeepsBlockingTheRest() {
        val config = BlockConfig(allowed = setOf("6001234567"))
        assertEquals(Prefix.P600, BlockRules.match("+566001234568", config))
        assertEquals(Prefix.P809, BlockRules.match("809123456", config))
    }

    @Test fun formatsNumbers() {
        assertEquals("600 123 4567", formatNumber("+566001234567"))
        assertEquals("809 123 456", formatNumber("809123456"))
        assertEquals("anon", formatNumber("anon"))
    }
}
