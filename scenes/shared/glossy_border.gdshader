shader_type canvas_item;

uniform float speed : hint_range(0.0, 1.0) = 0.28;
uniform float phase : hint_range(0.0, 1.0) = 0.0;
uniform float tail_len : hint_range(0.05, 0.8) = 0.32;
uniform float ring_soft : hint_range(0.5, 8.0) = 2.6;
uniform float glow : hint_range(0.0, 2.0) = 0.95;
uniform float corner_radius : hint_range(0.0, 200.0) = 26.0;
uniform vec2 rect_size = vec2(600.0, 150.0);
uniform vec3 accent : source_color = vec3(0.3, 0.82, 0.96);

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void fragment() {
	vec4 base = COLOR * texture(TEXTURE, UV);
	vec2 half_size = rect_size * 0.5;
	vec2 uv_centered = UV * rect_size - half_size;
	float r = clamp(corner_radius, 0.0, min(half_size.x, half_size.y) - 1.0);
	float sd = sd_round_box(uv_centered, half_size, r);

	float border_mask = 1.0 - smoothstep(-4.0, 2.0, sd);

	float core = smoothstep(1.6, 0.0, abs(sd));
	float halo = exp(-abs(sd) / ring_soft);
	float ring = max(core, halo * 0.6) * border_mask;

	float ang  = atan(uv_centered.y, uv_centered.x);
	float t    = (ang + 3.14159265) / 6.28318530;
	float head = fract(TIME * speed + phase);
	float back = fract(head - t + 1.0);

	float tail = pow(smoothstep(tail_len, 0.0, back), 1.4);
	float hot  = smoothstep(0.05, 0.0, back);
	float comet = (tail + hot * 1.6) * border_mask;

	vec3 tail_col = accent * 1.25;
	vec3 comet_col = mix(tail_col, vec3(1.0), smoothstep(0.12, 0.0, back));
	float rim_base = halo * 0.18 * border_mask;

	vec3  add   = comet_col * comet * ring + accent * rim_base;
	float add_a = (comet * ring + rim_base) * glow;
	COLOR = vec4(base.rgb + add, clamp(base.a + add_a, 0.0, 1.0));
}
