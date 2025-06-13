shader_type canvas_item;

uniform float quantity : hint_range(0.0, 1.0);
uniform float effect_tint : hint_range(0.0, 1.0);
uniform vec4 target_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec4 white_blend = vec4(1.0, 1.0, 1.0, base.a);
	vec4 result = mix(base, white_blend, quantity);
	
	result = mix(result, target_color * result, effect_tint);
	
	COLOR = result;
}
