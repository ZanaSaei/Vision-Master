shader_type canvas_item;

uniform float speed = 0.15;
uniform vec4 color1 : source_color = vec4(0.05, 0.05, 0.2, 1.0); // Deep Blue
uniform vec4 color2 : source_color = vec4(0.3, 0.1, 0.4, 1.0); // Purple
uniform vec4 color3 : source_color = vec4(0.1, 0.3, 0.4, 1.0); // Teal

void fragment() {
    vec2 uv = UV;
    float t = TIME * speed;
    
    // Create a flowing, organic gradient
    vec3 color = mix(color1.rgb, color2.rgb, sin(uv.x * 3.14 + t) * 0.5 + 0.5);
    color = mix(color, color3.rgb, cos(uv.y * 3.14 - t * 0.5) * 0.5 + 0.5);
    
    // Add a subtle vignette
    float vignette = 1.0 - smoothstep(0.4, 1.4, length(uv - 0.5) * 1.5);
    color *= vignette;
    
    COLOR = vec4(color, 1.0);
}