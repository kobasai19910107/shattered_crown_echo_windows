shader_type canvas_item;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.8, 0.95, 1.0);
void fragment() {
    vec4 sample_color = texture(TEXTURE, UV) * COLOR;
    COLOR = vec4(mix(sample_color.rgb, flash_color.rgb, flash_amount), sample_color.a);
}
