shader_type spatial;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, shadows_disabled;

uniform sampler2D albedo_texture : source_color;
uniform sampler2D shadow_color_texture : source_color;

void fragment() {
    // --- Base Color & Gamma ---
    vec4 base_tex = texture(albedo_texture, UV);
    // Raise the power to slightly saturate the color (Anime Style)
    vec3 albedo_final = pow(base_tex.rgb, vec3(1.5));

    // --- Fresnel / Rim Light ---
    // Creates a light rim based on the camera angle
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.0);
    float rim_mask = pow(fresnel, 8.0);
    // Limit the emission intensity
    vec3 emission_final = min(vec3(rim_mask), vec3(1.0));

    ALBEDO = albedo_final;
    EMISSION = emission_final;
    SSS_STRENGTH = 0.05;
}

void light() {
    // --- Vector Projection in World Space ---
    // Object normal in world space (flattened on XZ for stability)
    vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
    vec3 normal_xz = normalize(world_normal * vec3(1.0, 0.0, 1.0));

    // Light direction in world space (flattened on XZ)
    vec3 world_light = (INV_VIEW_MATRIX * vec4(LIGHT, 0.0)).xyz;
    vec3 light_xz = normalize(world_light * vec3(1.0, 0.0, 1.0));

    // --- Cel Shading Calculation ---
    float dot_prod = dot(normal_xz, light_xz);
    // Half-Lambert to soften the transition before the cutoff
    float half_lambert = (dot_prod * -0.5) + 0.5;
    
    // Hard cutoff (Cel Step). 0.2 is the shadow threshold.
    float cel_mask = step(half_lambert, 0.2);

    // --- Color Composition ---
    vec3 shadow_color = texture(shadow_color_texture, UV).rgb;
    // Blend the shadow mask with the shadow color texture (Screen Mode)
    vec3 shading_composite = 1.0 - (1.0 - vec3(cel_mask)) * (1.0 - shadow_color);

    // Light color correction (prevents white highlights from blowing out)
    vec3 light_color_final = pow(LIGHT_COLOR, vec3(0.5));

    DIFFUSE_LIGHT = shading_composite * light_color_final;
}