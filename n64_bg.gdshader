shader_type canvas_item;



uniform float zoom : hint_range(0.1, 10.0) = 0.4; 

uniform float speed : hint_range(0.01, 5.0) = 0.04;



// --- LIQUID PROPERTIES ---

uniform float bump_amount : hint_range(0.01, 10.0) = 0.7;

uniform float chromatic_aberration : hint_range(0.0, 100) = 100.0;

uniform float reflection_strength : hint_range(0.0, 10.0) = 0.9;

uniform float fresnel_power : hint_range(1.0, 8.0) = 2.2;



uniform vec3 env_tint : source_color = vec3(0.6, 0.75, 1.0);

uniform vec3 spec_color : source_color = vec3(1.0, 1.0, 1.0);

uniform vec3 base_color : source_color = vec3(0.1, 0.1, 0.15);



uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;



// Smooth wave function

vec2 W(vec2 p, float t) {

    p *= zoom;

    p = (p + 3.0) * 4.0;

    for (int i = 0; i < 3; i++) {

        p += cos(p.yx * 3.0 + vec2(t, 1.57)) / 3.0;

        p += sin(p.yx + t + vec2(1.57, 0.0)) / 2.0;

        p *= 1.3; 

    }

    return mod(p, 2.0) - 1.0;

}



float bumpFunc(vec2 p, float t) {

    return length(W(p, t)) * 0.7071;

}



void fragment() {

    // 1. CLEAN COORDINATES (No more pixelation)

    vec2 p = (UV - 0.5);

    p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x; 

    float t = TIME * speed;



    // 2. HIGH-PRECISION NORMALS

    float eps = 0.005; // Smaller epsilon for smoother gradients

    float f = bumpFunc(p, t);

    float fx = bumpFunc(p - vec2(eps, 0.0), t);

    float fy = bumpFunc(p - vec2(0.0, eps), t);

    

    // sn = Surface Normal

    vec3 sn = normalize(vec3((fx - f) / eps, (fy - f) / eps, -1.0 / bump_amount));

    // rd = Ray Direction (viewing angle)

    vec3 rd = normalize(vec3(p, 1.0));



    // 3. CHROMATIC ABERRATION (Refraction)

    // We sample the background 3 times with slight offsets for that "glass" prism effect

    vec2 refr_uv = SCREEN_UV + sn.xy * 0.05;

    float r = texture(screen_texture, refr_uv + (sn.xy * chromatic_aberration)).r;

    float g = texture(screen_texture, refr_uv).g;

    float b = texture(screen_texture, refr_uv - (sn.xy * chromatic_aberration)).b;

    vec3 background = vec3(r, g, b);



    // 4. FRESNEL & REFLECTION

    // Fresnel makes the edges of the liquid "pop" with more reflection

    float fresnel = pow(1.0 + dot(sn, rd), fresnel_power);

    

    vec3 refl_vec = reflect(rd, sn);

    float env_map = max(dot(refl_vec, vec3(0.5, 0.7, 1.0)), 0.0);

    vec3 reflection = pow(env_map, 3.0) * env_tint * reflection_strength;



    // 5. SPECULAR GLINTS

    vec3 lp = vec3(cos(t * 0.5), sin(t * 0.5), -1.0); // Moving light source

    vec3 ld = normalize(lp - vec3(p, 0.0));

    float spec = pow(max(dot(reflect(-ld, sn), -rd), 0.0), 64.0);

    

    // 6. FINAL COMBINE

    // Use base_color instead of screen background when screen is empty/dark
    vec3 bg_with_base = max(background, base_color);

    // We blend the base/background with the Fresnel reflection
    vec3 col = mix(bg_with_base, reflection, fresnel * 0.5);

    col += reflection * 0.5; // Constant environmental sheen

    col += spec_color * spec * 2.0; // Hot specular highlight

    // Add a slight darkening in the "valleys" for depth
    col *= (f * 0.4 + 0.7);

    // Tint toward base color for more visible color shifts
    col = mix(col, base_color * 2.0, 0.3);

    COLOR = vec4(col, 1.0);

}