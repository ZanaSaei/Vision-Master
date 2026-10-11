shader_type canvas_item;

uniform vec4 bar_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform vec2 cutout_center = vec2(180.0, 0.0);

uniform float cutout_radius = 36.0;

uniform vec2 bar_size = vec2(360.0, 72.0);

void fragment()
{
	// UV maps the full background rect; use its own dimensions so offsets or
	// runtime scaling do not shift the cutout in pixel-space.
	vec2 pixel_position = UV * bar_size;

	float distance_to_selector = distance(
		pixel_position,
		cutout_center
	);

	if (distance_to_selector < cutout_radius)
	{
		COLOR = vec4(0.0);
	}
	else
	{
		COLOR = bar_color;
	}
}