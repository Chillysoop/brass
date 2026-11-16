shader_type canvas_item;

uniform vec4 portrait_region;

void fragment() {
	vec2 cell = (UV / TEXTURE_PIXEL_SIZE - portrait_region.xy) / portrait_region.zw;
	vec2 margin = min(cell, 1.0 - cell);
	vec3 rgb = texture(TEXTURE, UV).rgb;
	float brightness = max(rgb.r, max(rgb.g, rgb.b));
	// Feather the painted backdrop into the draft without drawing a rectangular matte.
	COLOR.a *= smoothstep(0.12, 0.22, brightness) * smoothstep(0.0, 0.06, min(margin.x, margin.y));
}
