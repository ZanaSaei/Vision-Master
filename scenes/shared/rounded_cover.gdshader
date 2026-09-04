shader_type canvas_item;

// Rounds the corners of a cover thumbnail inside a card chip so the image
// matches the chip's rounded accent frame instead of showing sharp 90-degree
// corners. corner_radius is a fraction of the cover's SHORT side (0..0.5),
// so the arc stays a true circular corner at any aspect ratio.

uniform float corner_radius : hint_range(0.0, 0.5) = 0.17;

void fragment() {
	// Convert UV into "short side == 1.0" pixel space so the rounded corner is
	// a real circle, not an ellipse.
	float aspect = TEXTURE_PIXEL_SIZE.x / TEXTURE_PIXEL_SIZE.y; // width / height
	vec2 p;
	vec2 half_ext;
	if (aspect >= 1.0) {
		// Landscape / square: short side is the height.
		p = vec2(UV.x * aspect, UV.y);
		half_ext = vec2(0.5 * aspect, 0.5);
	} else {
		// Portrait: short side is the width.
		p = vec2(UV.x, UV.y / aspect);
		half_ext = vec2(0.5, 0.5 / aspect);
	}
	vec2 center = half_ext;

	// Rounded-rectangle SDF: distance to the rounded outline.
	vec2 q = abs(p - center) - (half_ext - corner_radius);
	float dist = length(max(q, vec2(0.0))) - corner_radius;

	// ~1px anti-aliased alpha edge.
	float aa = fwidth(dist);
	float alpha = 1.0 - smoothstep(-aa, aa, dist);

	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(tex.rgb, tex.a * alpha);
}
