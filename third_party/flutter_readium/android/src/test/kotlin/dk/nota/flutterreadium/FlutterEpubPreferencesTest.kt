package dk.nota.flutterreadium

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.readium.r2.navigator.preferences.FontFamily
import org.readium.r2.navigator.preferences.TextAlign

@OptIn(org.readium.r2.shared.ExperimentalReadiumApi::class)
internal class FlutterEpubPreferencesTest {
    @Test
    fun `fontSize is forwarded unchanged as a ratio`() {
        val prefs = FlutterEpubPreferences(fontSize = 1.5)
        val epub = prefs.toEpubPreferences()
        assertEquals(1.5, epub.fontSize)
    }

    @Test
    fun `fontSize default ratio (1_0) is preserved`() {
        val prefs = FlutterEpubPreferences(fontSize = 1.0)
        val epub = prefs.toEpubPreferences()
        assertEquals(1.0, epub.fontSize)
    }

    @Test
    fun `null fontSize produces null in EpubPreferences`() {
        val prefs = FlutterEpubPreferences(fontSize = null)
        val epub = prefs.toEpubPreferences()
        assertNull(epub.fontSize)
    }

    @Test
    fun `font family custom css variable contains the css family name`() {
        val prefs = FlutterEpubPreferences(fontFamily = FontFamily("serif"))

        assertEquals("serif", prefs.toCustomCssVariables()["--USER__fontFamily"])
        assertEquals(
            "readium-font-on",
            prefs.toCustomCssVariables()["--USER__fontOverride"],
        )
    }

    @Test
    fun `typography preferences are exposed as Readium CSS variables`() {
        val css =
            FlutterEpubPreferences(
                fontSize = 1.25,
                pageMargins = 1.2,
                lineHeight = 1.6,
                paragraphSpacing = 0.5,
                paragraphIndent = 1.0,
                letterSpacing = 0.1,
            ).toCustomCssVariables()

        assertEquals("125.0%", css["--USER__fontSize"])
        assertEquals("1.2", css["--USER__pageMargins"])
        assertEquals("readium-advanced-on", css["--USER__advancedSettings"])
        assertEquals("1.6", css["--USER__lineHeight"])
        assertEquals("0.5rem", css["--USER__paraSpacing"])
        assertEquals("1.0rem", css["--USER__paraIndent"])
        assertEquals("0.1rem", css["--USER__letterSpacing"])
    }

    @Test
    fun `text alignment is exposed as a Readium CSS variable`() {
        val css = FlutterEpubPreferences(textAlign = TextAlign.JUSTIFY).toCustomCssVariables()

        assertEquals("justify", css["--USER__textAlign"])
        assertEquals("readium-advanced-on", css["--USER__advancedSettings"])
    }
}
