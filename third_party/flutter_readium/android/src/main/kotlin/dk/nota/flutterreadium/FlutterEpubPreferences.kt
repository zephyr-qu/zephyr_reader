package dk.nota.flutterreadium

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import org.readium.r2.navigator.epub.EpubPreferences
import org.readium.r2.navigator.preferences.ColumnCount
import org.readium.r2.navigator.preferences.Configurable
import org.readium.r2.navigator.preferences.FontFamily
import org.readium.r2.navigator.preferences.ImageFilter
import org.readium.r2.navigator.preferences.ReadingProgression
import org.readium.r2.navigator.preferences.Spread
import org.readium.r2.navigator.preferences.TextAlign
import org.readium.r2.shared.ExperimentalReadiumApi
import org.readium.r2.shared.util.Language

private const val TAG = "FlutterEpubPreferences"

private const val TOP_MARGIN_CSS_VARIABLE = "--FLUTTER_READIUM-first-element-top-margin"
private const val BLACK_AND_WHITE_COMIC_MODE_CSS_VARIABLE = "--FLUTTER_READIUM-black-white-comic-mode"
private const val USER_BACKGROUND_COLOR_CSS_VARIABLE = "--USER__backgroundColor"
private const val USER_TEXT_COLOR_CSS_VARIABLE = "--USER__textColor"
private const val USER_FONT_FAMILY_CSS_VARIABLE = "--USER__fontFamily"
private const val USER_FONT_OVERRIDE_CSS_VARIABLE = "--USER__fontOverride"
private const val USER_FONT_SIZE_CSS_VARIABLE = "--USER__fontSize"
private const val USER_TEXT_ALIGN_CSS_VARIABLE = "--USER__textAlign"
private const val USER_PAGE_MARGINS_CSS_VARIABLE = "--USER__pageMargins"
private const val USER_ADVANCED_SETTINGS_CSS_VARIABLE = "--USER__advancedSettings"
private const val USER_LINE_HEIGHT_CSS_VARIABLE = "--USER__lineHeight"
private const val USER_PARAGRAPH_SPACING_CSS_VARIABLE = "--USER__paraSpacing"
private const val USER_PARAGRAPH_INDENT_CSS_VARIABLE = "--USER__paraIndent"
private const val USER_LETTER_SPACING_CSS_VARIABLE = "--USER__letterSpacing"

@OptIn(ExperimentalReadiumApi::class)
@Serializable
data class FlutterEpubPreferences(
    val backgroundColor: String? = null,
    val columnCount: ColumnCount? = null,
    val fontFamily: FontFamily? = null,
    val fontSize: Double? = null,
    val fontWeight: Double? = null,
    val hyphens: Boolean? = null,
    val imageFilter: ImageFilter? = null,
    val language: Language? = null,
    val letterSpacing: Double? = null,
    val ligatures: Boolean? = null,
    val lineHeight: Double? = null,
    val pageMargins: Double? = null,
    val paragraphIndent: Double? = null,
    val paragraphSpacing: Double? = null,
    val publisherStyles: Boolean? = null,
    val readingProgression: ReadingProgression? = null,
    val scroll: Boolean? = null,
    val spread: Spread? = null,
    val textAlign: TextAlign? = null,
    val textColor: String? = null,
    val textNormalization: Boolean? = null,
    val typeScale: Double? = null,
    val verticalText: Boolean? = null,
    val wordSpacing: Double? = null,
    val blackAndWhiteComicMode: Boolean? = false,
    val disableSynchronization: Boolean? = false,
    val syncPolicy: String? = null,
    val firstElementTopMargin: Int? = null,
    val preventMOColumnBreaks: Boolean? = true,
) : Configurable.Preferences<FlutterEpubPreferences> {
    override fun plus(other: FlutterEpubPreferences): FlutterEpubPreferences =
        FlutterEpubPreferences(
            backgroundColor = other.backgroundColor ?: backgroundColor,
            columnCount = other.columnCount ?: columnCount,
            fontFamily = other.fontFamily ?: fontFamily,
            fontWeight = other.fontWeight ?: fontWeight,
            fontSize = other.fontSize ?: fontSize,
            hyphens = other.hyphens ?: hyphens,
            imageFilter = other.imageFilter ?: imageFilter,
            language = other.language ?: language,
            letterSpacing = other.letterSpacing ?: letterSpacing,
            ligatures = other.ligatures ?: ligatures,
            lineHeight = other.lineHeight ?: lineHeight,
            pageMargins = other.pageMargins ?: pageMargins,
            paragraphIndent = other.paragraphIndent ?: paragraphIndent,
            paragraphSpacing = other.paragraphSpacing ?: paragraphSpacing,
            publisherStyles = other.publisherStyles ?: publisherStyles,
            readingProgression = other.readingProgression ?: readingProgression,
            scroll = other.scroll ?: scroll,
            spread = other.spread ?: spread,
            textAlign = other.textAlign ?: textAlign,
            textColor = other.textColor ?: textColor,
            textNormalization = other.textNormalization ?: textNormalization,
            typeScale = other.typeScale ?: typeScale,
            verticalText = other.verticalText ?: verticalText,
            wordSpacing = other.wordSpacing ?: wordSpacing,
            blackAndWhiteComicMode = other.blackAndWhiteComicMode ?: blackAndWhiteComicMode,
            disableSynchronization = other.disableSynchronization ?: disableSynchronization,
            syncPolicy = other.syncPolicy ?: syncPolicy,
            firstElementTopMargin = other.firstElementTopMargin ?: firstElementTopMargin,
            preventMOColumnBreaks = other.preventMOColumnBreaks ?: preventMOColumnBreaks,
        )

    fun toEpubPreferences(): EpubPreferences =
        EpubPreferences(
            backgroundColor = backgroundColor?.let { readiumColorFromCSS(it) },
            columnCount,
            fontFamily,
            fontSize,
            fontWeight,
            hyphens,
            imageFilter,
            language,
            letterSpacing,
            ligatures,
            lineHeight,
            pageMargins,
            paragraphIndent,
            paragraphSpacing,
            publisherStyles,
            readingProgression,
            scroll = scroll,
            spread,
            textAlign,
            textColor = textColor?.let { readiumColorFromCSS(it) },
            textNormalization,
            theme = null,
            typeScale,
            verticalText,
            wordSpacing,
        )

    fun toCustomCssVariables(): Map<String, String?> {
        val map = mutableMapOf<String, String?>()
        map[TOP_MARGIN_CSS_VARIABLE] = firstElementTopMargin?.let { "${it}px" }
        map[BLACK_AND_WHITE_COMIC_MODE_CSS_VARIABLE] = if (blackAndWhiteComicMode == true) "1" else null
        map[USER_BACKGROUND_COLOR_CSS_VARIABLE] = backgroundColor
        map[USER_TEXT_COLOR_CSS_VARIABLE] = textColor
        // FontFamily is a Kotlin value class. Its toString() is a debug
        // representation (for example, "FontFamily(name=serif)"), not a CSS
        // font-family value.
        map[USER_FONT_FAMILY_CSS_VARIABLE] = fontFamily?.name
        // Readium CSS enables the font-family selector only when this marker
        // is present in the root style attribute.
        map[USER_FONT_OVERRIDE_CSS_VARIABLE] =
            fontFamily?.let { "readium-font-on" }
        // Keep the current document in sync with native Readium's preference
        // submission. These are the exact CSS variables used by ReadiumCSS.
        map[USER_FONT_SIZE_CSS_VARIABLE] = fontSize?.let { "${it * 100}%" }
        map[USER_TEXT_ALIGN_CSS_VARIABLE] = textAlign?.name?.lowercase()
        map[USER_PAGE_MARGINS_CSS_VARIABLE] = pageMargins?.toString()
        val hasAdvancedSettings =
            textAlign != null ||
            lineHeight != null ||
            paragraphSpacing != null ||
            paragraphIndent != null ||
            letterSpacing != null
        map[USER_ADVANCED_SETTINGS_CSS_VARIABLE] =
            if (hasAdvancedSettings) "readium-advanced-on" else null
        map[USER_LINE_HEIGHT_CSS_VARIABLE] = lineHeight?.toString()
        map[USER_PARAGRAPH_SPACING_CSS_VARIABLE] =
            paragraphSpacing?.let { "${it}rem" }
        map[USER_PARAGRAPH_INDENT_CSS_VARIABLE] =
            paragraphIndent?.let { "${it}rem" }
        map[USER_LETTER_SPACING_CSS_VARIABLE] =
            letterSpacing?.let { "${it}rem" }
        return map
    }

    fun toInjectableStyleSheet(): String =
        """<style id="flutter_readium_style">:root {${
            toCustomCssVariables().filter { it.value != null }
                .map { (key, value) -> "$key: $value !important" }
                .joinToString(separator = ";")
        }}</style>""".trimIndent()

    companion object {
        fun fromMap(map: Map<String, Any>): FlutterEpubPreferences {
            val element = mapToJsonObject(map)
            return Json.decodeFromJsonElement(serializer(), element)
        }

        fun fromJson(jsonString: String): FlutterEpubPreferences = Json.decodeFromString<FlutterEpubPreferences>(jsonString)
    }
}
