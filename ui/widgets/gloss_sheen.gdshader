shader_type canvas_item;

// ============================================================
//  GLOSS SHEEN — the shiny coating of a glossy menu button.
//
//  Drawn as a transparent overlay ON TOP of a card's styleboxes, so the button
//  keeps its own normal / hover / pressed styles (and their shadows) and only
//  gains the shine. Everything is masked by a rounded-rect SDF built from the
//  card's own corner radius, so the gloss never spills past the rounded edges.
//
//  Layers, bottom to top:
//    1) a tinted glass wash over the polished lip at the top of the card,
//    2) the specular band just under that lip — the highlight the eye reads as
//       gloss (a white gradient alone has nowhere to climb on a pale face),
//    3) a deep shade along the bottom edge — the volume under the shine,
//    4) a thin diagonal shine streak (the classic gloss cue),
//    5) an inner rim light on the top edge.
//
//  `sheen` is the interaction state: 0 at rest, +1 on hover, negative while
//  pressed (the surface flattens and the gloss dims).
//
//  rect_size is synced to the control size by gloss_sheen.gd, so the corner
//  arcs stay perfect circles at any card width.
// ============================================================

uniform vec2 rect_size = vec2(1000.0, 150.0);
uniform float corner_radius : hint_range(0.0, 120.0) = 26.0;
uniform vec4 tint : source_color = vec4(0.23, 0.51, 0.96, 1.0);
uniform float sheen : hint_range(-1.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

// Signed distance to a centred rounded rect; < 0 inside, > 0 outside.
float rounded_rect_sd(vec2 p, vec2 half_ext, float radius) {
	vec2 q = abs(p) - (half_ext - vec2(radius));
	return length(max(q, vec2(0.0))) - radius;
}

// Straight-alpha "source over" accumulation: `acc` holds premultiplied colour.
void over(inout vec4 acc, vec3 rgb, float alpha) {
	acc.rgb = rgb * alpha + acc.rgb * (1.0 - alpha);
	acc.a = alpha + acc.a * (1.0 - alpha);
}

void fragment() {
	vec2 half_ext = max(rect_size, vec2(1.0)) * 0.5;
	vec2 p = UV * rect_size;
	float radius = min(corner_radius, min(half_ext.x, half_ext.y));
	float d = rounded_rect_sd(p - half_ext, half_ext, radius);
	float aa = max(fwidth(d), 0.0001);
	float inside = 1.0 - smoothstep(-aa, aa, d);

	// Hover clears the face and lifts the highlight; a press deepens the tint
	// and dims the shine.
	float hover = max(sheen, 0.0);
	float press = max(-sheen, 0.0);
	float gloss_gain = (1.0 + 0.45 * hover - 0.55 * press) * strength;
	float tint_gain = (1.0 - 0.30 * hover + 0.45 * press) * strength;

	vec4 acc = vec4(0.0);

	// 1) Tinted glass: the section colour pools towards the BOTTOM of the card
	//    and leaves the top edge clean. On a pale face the vertical sweep from
	//    untinted light down to tinted shade is what reads as gloss — a tinted
	//    top would instead read as a smudge.
	over(acc, tint.rgb, smoothstep(0.30, 1.0, UV.y) * 0.22 * tint_gain);

	// 2) Specular band: the polish catching the light just under the top edge.
	//    A pale face has little headroom above it, so this is a soft band
	//    rather than a bright cap — it lifts the clean top instead of fighting
	//    a wash there.
	float band_y = (UV.y - 0.17) * (1.0 / 0.115);
	float spec = exp(-band_y * band_y) * 0.55 * gloss_gain;
	over(acc, vec3(1.0), clamp(spec, 0.0, 1.0));

	// 3) Bottom shade: the same colour, deepened, pooling under the lower curve
	//    — the volume under the shine, which sinks further as the card is
	//    pressed.
	over(acc, tint.rgb * 0.55,
		smoothstep(0.72, 1.0, UV.y) * (0.14 + 0.10 * press) * strength);

	// 4) Shine streak: a thin diagonal line of light crossing the face where the
	//    tint has already pooled, so it has something to lift off. This is the
	//    cue that the surface is polished rather than painted.
	float streak_x = (UV.y - 0.58 - (UV.x - 0.5) * 0.10) * (1.0 / 0.045);
	float streak = exp(-streak_x * streak_x)
		* smoothstep(0.10, 0.36, UV.x)
		* (1.0 - smoothstep(0.62, 0.94, UV.x))
		* 0.34 * gloss_gain;
	over(acc, vec3(1.0), clamp(streak, 0.0, 1.0));

	// 5) Inner rim light: lights the top edge only, so the card reads as a
	//    raised, polished surface rather than a shiny sticker.
	float rim = 1.0 - smoothstep(0.0, 1.8, -d);
	float top_only = 1.0 - smoothstep(0.30, 0.62, UV.y);
	over(acc, vec3(1.0), clamp(rim * top_only * 0.55 * gloss_gain, 0.0, 1.0));

	vec3 rgb = acc.rgb / max(acc.a, 0.0001);
	COLOR = vec4(rgb, clamp(acc.a * inside, 0.0, 1.0));
}
