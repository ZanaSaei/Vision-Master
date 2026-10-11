shader_type canvas_item;

// ============================================================
// GRADIENT CARD — the rounded gradient banner button background.
//
// Draws a rounded-rect (true circular corners via an SDF) filled with a
// diagonal two-colour gradient, plus the three decorative touches that make
// the reference cards read as "glossy plastic":
//   1) a soft light wash over the top of the card,
//   2) a faint diagonal shine line,
//   3) two translucent bright blobs bleeding in from the bottom-right corner.
// The control is expected to extend `inset` px beyond the card on every side
// so the blurred drop shadow (shifted down by shadow_offset) is not clipped.
//
// rect_size is synced to the control size by GradientCardRect.gd so the
// corner arcs stay perfect circles at any card width.
// ============================================================

uniform vec4 color_top : source_color = vec4(1.0, 0.80, 0.20, 1.0);
uniform vec4 color_bottom : source_color = vec4(0.97, 0.57, 0.11, 1.0);
uniform vec2 rect_size = vec2(976.0, 296.0);
uniform float corner_radius = 64.0;
uniform float inset = 28.0;
uniform float shadow_blur = 22.0;
uniform float shadow_offset = 10.0;
uniform vec4 shadow_color : source_color = vec4(0.10, 0.10, 0.10, 0.32);

// Signed distance to a centred rounded rect; < 0 inside, > 0 outside.
float rounded_rect_sd(vec2 p, vec2 center, vec2 half_ext, float radius) {
	vec2 q = abs(p - center) - (half_ext - radius);
	return length(max(q, vec2(0.0))) - radius;
}

void fragment() {
	vec2 p = UV * rect_size;
	vec2 center = rect_size * 0.5;
	vec2 card_half = center - vec2(inset);
	float r = min(corner_radius, min(card_half.x, card_half.y));

	float d = rounded_rect_sd(p, center, card_half, r);
	float aa = fwidth(d) + 0.5;
	float inside = 1.0 - smoothstep(-aa, aa, d);

	// Soft drop shadow: same shape, pushed down, blurred outward.
	float sd = rounded_rect_sd(p, center + vec2(0.0, shadow_offset), card_half, r);
	float shadow_a = shadow_color.a * (1.0 - smoothstep(0.0, shadow_blur, sd));

	// Diagonal two-stop gradient.
	vec4 base = mix(color_top, color_bottom, smoothstep(0.0, 1.0, UV.y * 0.85 + UV.x * 0.15));

	// Glossy highlights.
	float gloss = (1.0 - smoothstep(0.0, 0.34, UV.y)) * 0.09;
	float shine = max(0.0, 0.10 - abs((UV.y - 0.10) - UV.x * 0.22) * 1.4);
	float d1 = length(p - vec2(rect_size.x * 0.94, rect_size.y * 1.10));
	float d2 = length(p - vec2(rect_size.x * 1.04, rect_size.y * 0.74));
	float blob = (1.0 - smoothstep(rect_size.y * 0.42, rect_size.y * 0.92, d1)) * 0.10
		+ (1.0 - smoothstep(rect_size.y * 0.52, rect_size.y * 0.98, d2)) * 0.07;
	vec3 lit = clamp(base.rgb + vec3(gloss + shine + blob), vec3(0.0), vec3(1.0));

	vec4 card = vec4(lit, 1.0);
	COLOR = mix(vec4(shadow_color.rgb, shadow_a), card, inside);
}
