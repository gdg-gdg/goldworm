shader_type canvas_item;

// --- N64 STYLE ANIMATED GRADIENT ---
uniform float pixel_size : hint_range(64.0, 512.0) = 200.0;
uniform int color_levels : hint_range(2, 32) = 12;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.25;
uniform float speed : hint_range(0.01, 2.0) = 0.3;
uniform float wave_intensity : hint_range(0.0, 1.0) = 0.15;

// Configurable colors
uniform vec4 color_top : source_color = vec4(0.2, 0.5, 0.3, 1.0);
uniform vec4 color_bottom : source_color = vec4(0.1, 0.1, 0.2, 1.0);

// 4x4 Bayer Dither Matrix
float dither(vec2 uv) {
    int x = int(mod(uv.x, 4.0));
    int y = int(mod(uv.y, 4.0));
    float m[16] = float[](
        0.0, 8.0, 2.0, 10.0,
        12.0, 4.0, 14.0, 6.0,
        3.0, 11.0, 1.0, 9.0,
        15.0, 7.0, 13.0, 5.0
    );
    return m[y * 4 + x] / 16.0;
}

// Smooth wave distortion
vec2 wave(vec2 p, float t) {
    p = (p + 3.0) * 4.0;
    for (int i = 0; i < 3; i++) {
        p += cos(p.yx * 3.0 + vec2(t, 1.57)) / 3.0;
        p += sin(p.yx + t + vec2(1.57, 0.0)) / 2.0;
        p *= 1.2;
    }
    return mod(p, 2.0) - 1.0;
}

void fragment() {
    // 1. Pixelation
    vec2 grid_uv = floor(UV * pixel_size) / pixel_size;
    vec2 screen_uv = (grid_uv - 0.5);
    float t = TIME * speed;

    // 2. Animated wave factor
    float f = length(wave(screen_uv, t)) * 0.7071;
    float diff = pow(f, 3.0);

    // 3. Gradient with wave distortion
    float gradient = grid_uv.y + (f * wave_intensity) - (wave_intensity * 0.5);
    gradient = clamp(gradient, 0.0, 1.0);

    vec3 base_color = mix(color_bottom.rgb, color_top.rgb, gradient + diff * 0.3);

    // 4. Posterization
    float levels = float(color_levels);
    base_color = floor(base_color * levels) / levels;

    // 5. Dithering
    float d = dither(UV * pixel_size);
    base_color += (d - 0.5) * dither_strength / levels;

    COLOR = vec4(base_color, 1.0);
}
