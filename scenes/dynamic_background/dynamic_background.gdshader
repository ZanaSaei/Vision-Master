shader_type canvas_item;

uniform float u_progress : hint_range(0.0, 1.0) = 1.0;
uniform float u_time = 0.0;
uniform float u_breathe_amount : hint_range(0.0, 0.08) = 0.012;

uniform vec2 u_curve_offset_1 = vec2(0.0);
uniform vec2 u_curve_offset_2 = vec2(0.0);
uniform vec2 u_curve_offset_3 = vec2(0.0);
uniform vec2 u_curve_offset_4 = vec2(0.0);

float ease_out_quart(float t) { return 1.0 - pow(1.0 - t, 4.0); }

float blob(vec2 uv, vec2 pos, float radius, float feather) {
    float d = length(uv - pos);
    return smoothstep(radius + feather, radius - feather, d);
}

float oval(vec2 uv, vec2 pos, vec2 size, float rotation, float feather) {
    vec2 local = uv - pos;
    float c = cos(rotation);
    float s = sin(rotation);
    local = vec2(local.x * c + local.y * s, -local.x * s + local.y * c);
    float d = length(local / size);
    return smoothstep(1.0 + feather, 1.0 - feather, d);
}

float band(vec2 uv, vec2 pos, vec2 size, float rotation,
           float thickness, float feather) {
    vec2 local = uv - pos;
    float c = cos(rotation);
    float s = sin(rotation);
    local = vec2(local.x * c + local.y * s, -local.x * s + local.y * c);
    float d = length(local / size);
    float inner = 1.0 - thickness;
    return smoothstep(inner + feather, inner - feather, d)
         * smoothstep(1.0 - feather, 1.0 + feather, d);
}

void fragment() {
    vec2 uv = UV;
    float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
    vec2 a = vec2(uv.x, uv.y * aspect);
    
    float p = ease_out_quart(u_progress);
    float br = sin(u_time * 0.6) * u_breathe_amount;
    
    vec3 col = vec3(0.0, 0.0, 0.035);
    
    // Curve 1 - Top-right
    vec2 p1 = mix(vec2(1.7, -0.4), vec2(0.72, 0.10), p) + u_curve_offset_1;
    float f1 = oval(a, p1, vec2(0.58, 0.42), 0.28, 0.10 + br);
    col = mix(col, vec3(0.0, 0.07, 0.44), f1 * 0.95);
    
    // Curve 2 - Bottom-left
    vec2 p2 = mix(vec2(-0.7, 1.7), vec2(0.18, 0.84), p) + u_curve_offset_2;
    float f2 = oval(a, p2, vec2(0.52, 0.46), -0.22, 0.10 + br);
    col = mix(col, vec3(0.0, 0.055, 0.40), f2 * 0.90);
    
    // Curve 3 - Top-left
    vec2 p3 = mix(vec2(-0.9, -0.9), vec2(0.12, 0.22), p) + u_curve_offset_3;
    float f3 = oval(a, p3, vec2(0.42, 0.36), 0.52, 0.08);
    col = mix(col, vec3(0.0, 0.022, 0.22), f3 * 0.75);
    
    // Curve 4 - Bottom-right
    vec2 p4 = mix(vec2(1.7, 1.3), vec2(0.80, 0.74), p) + u_curve_offset_4;
    float f4 = oval(a, p4, vec2(0.40, 0.40), -0.38, 0.08);
    col = mix(col, vec3(0.0, 0.016, 0.18), f4 * 0.70);
    
    // Center dark blob
    vec2 pc = mix(vec2(0.5, -1.3), vec2(0.5, 0.50), p);
    float fc = blob(a, pc, 0.33, 0.11 + br);
    col = mix(col, vec3(0.0, 0.0, 0.05), fc * 0.97);
    
    COLOR = vec4(col, 1.0);
}