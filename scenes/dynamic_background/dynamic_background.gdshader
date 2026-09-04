shader_type canvas_item;

// Ambient menu background — rendered on a full-screen quad behind the menu
// content by AnimatedBackground. Colors are fed from the active Dark/Light
// palette via apply_theme(); u_time drives the slow ambient motion.
//
// Layered effect:
//   1) vertical base gradient (brighter top, deeper bottom)
//   2) breathing glow behind the title / hero area
//   3) two soft aurora bands drifting slowly across the screen
//   4) gentle vignette that lets the centre content pop

uniform vec3 u_col_top : source_color = vec3(0.05, 0.09, 0.30);
uniform vec3 u_col_bottom : source_color = vec3(0.008, 0.012, 0.045);
uniform vec3 u_col_glow : source_color = vec3(0.32, 0.21, 0.66);
uniform vec3 u_col_band_a : source_color = vec3(0.32, 0.21, 0.66);
uniform vec3 u_col_band_b : source_color = vec3(0.20, 0.24, 0.66);

uniform float u_time = 0.0;
uniform float u_glow_strength : hint_range(0.0, 1.0) = 0.4;
uniform float u_vignette : hint_range(0.0, 1.0) = 0.55;

void fragment() {
    // Aspect-corrected, centered coordinates so radial shapes stay round
    // on the tall portrait canvas.
    float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
    vec2 a = vec2(UV.x - 0.5, (UV.y - 0.5) * aspect);

    // 1) Vertical base gradient: brighter near the top, deep at the bottom.
    float g = pow(1.0 - UV.y, 0.8);
    vec3 col = mix(u_col_bottom, u_col_top, g);

    float t = u_time;

    // 2) Breathing glow behind the title / hero area (upper-centre).
    float breath = 0.5 + 0.5 * sin(t * 0.55);
    float d_glow = length(a - vec2(0.0, -0.34 * aspect));
    float glow = smoothstep(0.9, 0.04, d_glow);
    col += u_col_glow * glow * u_glow_strength * (0.6 + 0.4 * breath);

    // 3) Two soft aurora bands drifting slowly across the screen.
    for (int i = 0; i < 2; i++) {
        float f = float(i);
        float y = 0.40 + f * 0.24;
        float wave = sin(UV.x * (3.0 + f * 1.6) + t * (0.16 + f * 0.10) + f * 2.4)
                   + 0.45 * sin(UV.x * (5.5 + f) + t * (0.22 + f * 0.12) + f * 4.1);
        float band = exp(-pow((UV.y - y - 0.035 * wave) * 7.0, 2.0));
        vec3 cb = mix(u_col_band_a, u_col_band_b, f);
        col += cb * band * (0.08 + 0.05 * sin(t * 0.30 + f * 1.7));
    }

    // 4) Gentle vignette: darken the edges so the content area pops.
    vec2 ndc = a / vec2(0.5, 0.5 * aspect);
    float vig = smoothstep(1.35, 0.45, length(ndc));
    col *= mix(1.0 - 0.42 * u_vignette, 1.0, clamp(vig, 0.0, 1.0));

    COLOR = vec4(col, 1.0);
}