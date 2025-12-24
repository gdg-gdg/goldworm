extends Node
## Fonts.gd - Font management autoload
## =====================================
## Provides access to Peaberry font
## Use apply_title for headers (gold colored)
## Use apply_body for everything else (modulated colors)

const GOLD_COLOR := Color(1.0, 0.85, 0.3)

# Preloaded font
var FONT: Font

func _ready() -> void:
	FONT = load("res://fonts/Peaberry-Font-v2.0/Peaberry Font Family/Peaberry Base/PeaberryBase.ttf")

## Apply title font to a label (gold color for headers)
func apply_title(label: Label, size: int = 36) -> void:
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", GOLD_COLOR)

## Apply body font to a label with optional color
func apply_body(label: Label, size: int = 14, color: Color = Color.WHITE) -> void:
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)

## Apply body font to a button
func apply_button(button: Button, size: int = 14) -> void:
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", size)
