shader_type canvas_item;
render_mode unshaded;

// --- Uniforms ---
uniform float time_scale : hint_range(0.0, 5.0) = 1.0;
uniform float voxel_scale : hint_range(0.1, 1.0) = 0.2;
uniform float density : hint_range(0.0, 1.0) = 0.5;
uniform vec3 line_color : source_color = vec3(5.0, 0.6, 0.0);
uniform float transmission : hint_range(0.0, 1.0) = 0.3;

// --- Noise Helpers ---
float hash(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return fract((p.x + p.y) * p.z);
}

float noise(vec3 x) {
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
                   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
               mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
                   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// --- Voxel Logic ---
float map_terrain(vec3 p) {
    p *= voxel_scale;
    float t = TIME * 0.5 * time_scale;
    float f = 0.500 * noise(p + vec3(0.0, 1.0, 0.0) * t);
    f += 0.250 * noise(p * 2.02 + vec3(0.0, 2.0, 0.0) * t);
    return step(f, density); // Returns 1.0 if voxel exists
}

// --- DDA Raycaster ---
// Optimized for Godot 4.4
float raycast(vec3 ro, vec3 rd, out vec3 oVos, out vec3 oDir) {
    vec3 pos = floor(ro);
    vec3 ri = 1.0 / rd;
    vec3 rs = sign(rd);
    vec3 dis = (pos - ro + 0.5 + rs * 0.5) * ri;
    
    float res = -1.0;
    vec3 mm = vec3(0.0);
    
    for(int i = 0; i < 96; i++) {
        if(map_terrain(pos) > 0.5) { res = 1.0; break; }
        mm = step(dis.xyz, dis.yzx) * step(dis.xyz, dis.zxy);
        dis += mm * rs * ri;
        pos += mm * rs;
    }
    
    oDir = mm;
    oVos = pos;
    vec3 mini = (pos - ro + 0.5 - 0.5 * rs) * ri;
    return max(mini.x, max(mini.y, mini.z)) * res;
}

// --- Visual Helpers ---
float maxcomp(vec4 v) { return max(max(v.x, v.y), max(v.z, v.w)); }

float isEdge(vec2 uv) {
    vec2 st = 1.0 - uv;
    vec4 wb = smoothstep(0.85, 0.99, vec4(uv.x, st.x, uv.y, st.y));
    return maxcomp(wb);
}

void fragment() {
    // Coordinate Setup
    vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 p = (2.0 * FRAGCOORD.xy - res.xy) / res.y;
    
    // Camera
    vec3 ro = vec3(0.0, 5.0, 10.0);
    vec3 ta = vec3(0.0, 0.0, 0.0);
    vec3 cw = normalize(ta - ro);
    vec3 cp = vec3(0.0, 1.0, 0.0);
    vec3 cu = normalize(cross(cw, cp));
    vec3 cv = normalize(cross(cu, cw));
    vec3 rd = normalize(p.x * cu + p.y * cv + 2.5 * cw);

    // Default Background
    vec3 col = mix(vec3(0.02, 0.04, 0.1), vec3(0.01), SCREEN_UV.y);

    vec3 vos, dir;
    float t = raycast(ro, rd, vos, dir);

    if (t > 0.0) {
        vec3 nor = -dir * sign(rd);
        vec3 pos = ro + rd * t;
        vec3 uvw = pos - vos;
        
        // Find UV on the cube face
        vec2 uv = vec2(dot(dir.yzx, uvw), dot(dir.zxy, uvw));
        
        // Lighting Calculations
        float edge = isEdge(uv);
        float dif = clamp(dot(nor, normalize(vec3(-0.4, 0.7, 0.3))), 0.0, 1.0);
        
        // Pearlescent / Glass effect
        float fresnel = pow(1.0 - clamp(dot(nor, -rd), 0.0, 1.0), 3.0);
        vec3 base_col = vec3(0.1, 0.2, 0.3);
        
        // Final color assembly
        vec3 cube_col = base_col + (dif * 0.5);
        cube_col = mix(cube_col, col, transmission); // Transparency feel
        cube_col += line_color * edge * 2.0;         // Edge glow
        cube_col += fresnel * vec3(0.5, 0.8, 1.0);   // Fresnel reflection
        
        // Distance Fog
        col = mix(cube_col, col, 1.0 - exp(-0.02 * t));
    }

    // Output with Gamma Correction
    COLOR = vec4(pow(col, vec3(0.4545)), 1.0);
}