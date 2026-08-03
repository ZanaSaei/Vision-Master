shader_type canvas_item;
render_mode unshaded;

// --- GODOT 4 FIX: Explicitly declare SCREEN_TEXTURE ---
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float blur_amount : hint_range(0.0, 0.05) = 0.015;
uniform float tint_strength : hint_range(0.0, 1.0) = 0.2;

void fragment() {
    vec2 size = TEXTURE_PIXEL_SIZE * blur_amount;
    vec4 color = vec4(0.0);
    float total = 0.0;
    
    // 5x5 Box blur
    for (float x = -2.0; x <= 2.0; x += 1.0) {
        for (float y = -2.0; y <= 2.0; y += 1.0) {
            vec2 offset = vec2(x, y) * size;
            color += texture(SCREEN_TEXTURE, UV + offset);
            total += 1.0;
        }
    }
    color /= total;
    
    // Apply dark tint
    color.rgb = mix(color.rgb, vec3(0.05, 0.05, 0.15), tint_strength);
    COLOR = color;
}