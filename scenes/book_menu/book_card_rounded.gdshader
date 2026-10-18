shader_type canvas_item;

uniform float corner_radius : hint_range(0.0, 200.0) = 25.0;
uniform vec2 rect_size = vec2(300.0, 400.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;

	vec2 p = UV * rect_size;
	float r = corner_radius;

	// Is the pixel on the left strip (where the corners live)?
	float on_left = step(p.x, r);

	// Is the pixel in the straight vertical section of the left edge?
	float in_middle =
		step(r, p.y) * step(p.y, rect_size.y - r);

	// Corner arcs.
	float d_tl = distance(p, vec2(r, r));
	float d_bl = distance(p, vec2(r, rect_size.y - r));

	float in_tl =
		(1.0 - step(r, p.y)) *
		(1.0 - smoothstep(r - 1.5, r, d_tl));

	float in_bl =
		step(rect_size.y - r, p.y) *
		(1.0 - smoothstep(r - 1.5, r, d_bl));

	float corner_region = on_left * (1.0 - in_middle);
	float mask = mix(1.0, in_tl + in_bl, corner_region);

	COLOR = vec4(base.rgb, base.a * mask);
}