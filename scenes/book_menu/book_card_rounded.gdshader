shader_type canvas_item;

uniform float corner_radius : hint_range(0.0, 100.0) = 26.0;
uniform vec2 rect_size = vec2(640.0, 960.0);
uniform float spine_width = 38.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec2 p = UV * rect_size;
	vec2 half_size = rect_size * 0.5;
	vec2 d = abs(p - half_size) - (half_size - vec2(corner_radius));
	float dist = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
	float mask = 1.0 - smoothstep(corner_radius - 1.5, corner_radius, dist);

	// Realistic book spine crease lighting on the right edge (Persian binding)
	float x_from_right = rect_size.x - p.x;
	float spine_light = 1.0;
	if (x_from_right < spine_width) {
		float t = x_from_right / spine_width;
		spine_light = 0.85 + 0.15 * smoothstep(0.0, 1.0, t);
	} else if (x_from_right < spine_width + 16.0) {
		float t = (x_from_right - spine_width) / 16.0;
		spine_light = 1.0 + 0.12 * sin(t * 3.14159265);
	}

	// Soft lighting vignette for tactile 3D cover feel
	vec2 uv_vignette = UV * (1.0 - UV.yx);
	float vig = clamp(uv_vignette.x * uv_vignette.y * 14.0, 0.0, 1.0);
	float depth_shade = mix(0.92, 1.0, vig);

	vec3 col = base.rgb * spine_light * depth_shade;
	COLOR = vec4(col, base.a * mask);
}
