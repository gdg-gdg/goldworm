shader_type canvas_item;

// --- RETRO CONTROLS ---
uniform float pixel_size : hint_range(64.0, 512.0) = 320.0; // Less pixelated
uniform int color_levels : hint_range(2, 64) = 16;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.2;

// --- OIL & SHINE CONTROLS ---
uniform float speed : hint_range(0.01, 1.0) = 0.04; // Even slower creeping motion
uniform float oil_viscosity : hint_range(0.1, 5.0) = 2.5;
uniform float rainbow_intensity : hint_range(0.0, 2.0) = 1.2;
uniform float shine_sharpness : hint_range(1.0, 50.0) = 35.0; // Makes highlights look like tiny pearls

// 4x4 Bayer Dither Matrix
float dither(vec2 uv) {
    int x = int(mod(uv.x, 4.0));
    int y = int(mod(uv.y, 4.0));
    float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
    return m[y * 4 + x] / 16.0;
}

// Complex Warp for "Swirling" Motion
vec2 W(vec2 p, float t) {
    p = (p + 3.0) * oil_viscosity;
    for (int i = 0; i < 4; i++) { // Extra iteration for complexity
        float t_mod = t + float(i) * 0.2;
        p += cos(p.yx * 2.5 + vec2(t_mod, 1.57)) / 2.0;
        p += sin(p.yx + t_mod * 0.8 + vec2(1.57, 0.0)) / 2.0;
        p *= 1.1;
    }
    return mod(p, 2.0) - 1.0;
}

void fragment() {
    // 1. Pixelation
    vec2 grid_uv = floor(UV * pixel_size) / pixel_size;
    vec2 screen_uv = (grid_uv - 0.5);
    float t = TIME * speed;

    // 2. The Warp & Normal Calculation
    vec2 warp = W(screen_uv, t);
    float f = length(warp) * 0.7071;

    // Create a "normal" from the warp to calculate light reflections
    vec2 eps = vec2(0.02, 0.0);
    float f_dx = length(W(screen_uv + eps.xy, t)) - f;
    float f_dy = length(W(screen_uv + eps.yx, t)) - f;
    vec3 normal = normalize(vec3(f_dx, f_dy, 0.2));

    // 3. Oily Iridescence (The Rainbow Effect)
    // We shift colors based on the slope of the "waves"
    vec3 rainbow;
    rainbow.r = sin(f * 6.0 + 0.0) * 0.5 + 0.5;
    rainbow.g = sin(f * 6.0 + 2.0) * 0.5 + 0.5;
    rainbow.b = sin(f * 6.0 + 4.0) * 0.5 + 0.5;

    // 4. Fake "Environment" Lighting
    // Simulates a light source reflecting off the oil surface
    float spec = pow(max(dot(normal, vec3(0.0, 0.0, 1.0)), 0.0), shine_sharpness);

    // Deep dark base color + rainbow swirls + sharp white highlights
    vec3 base_color = mix(vec3(0.02, 0.01, 0.05), rainbow, rainbow_intensity * 0.4);
    vec3 final_col = base_color + (rainbow * spec) + (vec3(spec) * 1.5);

    // 5. N64 Crunch (Posterize & Dither)
    float levels = float(color_levels);
    final_col = floor(final_col * levels) / levels;
    float d = dither(UV * pixel_size);
    final_col += (d - 0.5) * dither_strength / levels;

    COLOR = vec4(final_col, 1.0);
}
