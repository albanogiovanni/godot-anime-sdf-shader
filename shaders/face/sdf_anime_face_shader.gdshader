shader_type spatial;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, shadows_disabled;

uniform sampler2D albedo_tex : source_color;
uniform sampler2D sdf_face_map : source_color;
uniform sampler2D shadow_color_tex : source_color;

void fragment() {
    // --- Base Color & Gamma correction ---
    vec4 base_tex = texture(albedo_tex, UV);
    // Increase power to saturate colors for an Anime/Stylized aesthetic
    vec3 albedo_final = pow(base_tex.rgb, vec3(1.5));

    // --- Fresnel / Rim Light logic ---
    // Calculate a light border based on the view angle relative to the surface normal
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.0);
    float rim_mask = pow(fresnel, 8.0);
    // Constrain the emission intensity to a maximum of 1.0
    vec3 emission_final = min(vec3(rim_mask), vec3(1.0));

    ALBEDO = albedo_final;
    EMISSION = emission_final;
    SSS_STRENGTH = 0.05;
}

void light() {
    // --- World Space Vectors (Flattened XZ) ---
    // Transform normal to World Space and flatten it on the Y-axis for stable horizontal rotation
    vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
    vec3 normal_xz = normalize(world_normal * vec3(1.0, 0.0, 1.0));

    // Transform light direction to World Space and flatten on the Y-axis
    vec3 world_light = (INV_VIEW_MATRIX * vec4(LIGHT, 0.0)).xyz;
    vec3 light_xz = normalize(world_light * vec3(1.0, 0.0, 1.0));

    // --- Half Lambert Calculation ---
    // Smooths the N·L dot product to map the range [-1, 1] to [0, 1]
    float dot_product = dot(normal_xz, light_xz);
    float half_lambert = (dot_product * -0.5) + 0.5;

    // --- Shadow UV Flip Logic ---
    // Create a flipped UV for asymmetrical face maps when the light moves to the other side
    vec2 uv_flipped = UV * vec2(-1.0, 1.0);
    vec2 target_uv;
    
    // Determine which UV to use based on the light's horizontal direction
    float flip_tolerance = 0.3;
    if (abs(0.0 - light_xz.x) < flip_tolerance) {
        target_uv = vec2(0.0); // Neutral/Forward light
    } else if (0.0 < light_xz.x) {
        target_uv = UV;        // Light from one side
    } else {
        target_uv = uv_flipped; // Flip UV for light from the opposite side
    }

    // --- SDF Processing ---
    // Sample the Face Shadow Map and find the highest value across RGB channels
    vec4 sdf_sample = texture(sdf_face_map, target_uv);
    float sdf_val = max(max(sdf_sample.r, sdf_sample.g), sdf_sample.b);
    
    // Create the hard-edged shadow mask by comparing the Half Lambert value to the SDF map
    float shadow_mask = step(half_lambert, sdf_val);

    // --- Cel Shade Lighting Color ---
    vec3 shadow_color = texture(shadow_color_tex, UV).rgb;
    // Blend the shadow mask with the shadow texture using a Screen blend mode logic
    vec3 composite_shading = 1.0 - (1.0 - vec3(shadow_mask)) * (1.0 - shadow_color);
    
    // Apply gamma correction to the light color to prevent over-exposure
    vec3 corrected_light_color = pow(LIGHT_COLOR, vec3(0.5));

    DIFFUSE_LIGHT = composite_shading * corrected_light_color;
}
