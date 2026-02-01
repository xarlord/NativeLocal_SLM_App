package com.example.nativelocal_slm_app.domain.model

/**
 * Hair length presets for style simulation.
 */
enum class LengthPreset(val displayName: String, val description: String) {
    SHORT("Short", "Above chin length"),
    SHOULDER("Shoulder Length", "At shoulder level"),
    MEDIUM("Medium", "Below shoulder, above mid-back"),
    LONG("Long", "Mid-back length"),
    EXTRA_LONG("Extra Long", "Waist length or longer")
}

/**
 * Bang styles for simulation.
 */
enum class BangStyle(val displayName: String) {
    NONE("No Bangs"),
    STRAIGHT("Straight Bangs"),
    SIDE_SWEEP("Side Swept"),
    CURTAIN("Curtain Bangs"),
    BLUNT("Blunt Bangs"),
    WISPY("Wispy Bangs"),
    V_SHAPED("V-Shaped Bangs")
}

/**
 * Hair accessories that can be added.
 */
enum class HairAccessory(val displayName: String) {
    NONE("No Accessory"),
    HEADBAND("Headband"),
    FLOWER_CROWN("Flower Crown"),
    RIBBON("Ribbon"),
    HAIR_PINS("Hair Pins"),
    TIARA("Tiara"),
    HAT("Hat")
}

/**
 * Sealed class representing different hair style selections.
 */
sealed class HairStyleSelection {
    data class Length(val preset: LengthPreset) : HairStyleSelection()
    data class Bangs(val style: BangStyle) : HairStyleSelection()
    data class Accessory(val accessory: HairAccessory) : HairStyleSelection()
}
