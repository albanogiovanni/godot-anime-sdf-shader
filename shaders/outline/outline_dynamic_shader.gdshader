shader_type spatial;
// cull_front is vital for the "Inverted Hull" technique (inverting faces for the outline)
render_mode blend_mix, depth_draw_never, depth_test_default, cull_front, diffuse_toon, specular_disabled, unshaded, shadows_disabled, ambient_light_disabled;

void vertex() {
    // --- NormalShifting ---
    // Normalize the normal and apply an initial base scale
    vec3 normal_normalized = normalize(NORMAL);
    vec3 base_normal_scaling = normal_normalized / vec3(10.0);

    // --- ZDepth ---
    // Move the vertex to View Space to calculate how far it is from the camera
    vec3 view_space_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    // In view space, Z is negative forward; we invert it to work with positive values
    float z_depth_positive = view_space_pos.z * -1.0;

    // --- OutlineZDepthScaling ---
    // Calculate thickness based on distance (Z-Depth)
    float depth_thickness = z_depth_positive * 0.05;
    // Clamp the thickness so it doesn't disappear up close or become massive far away
    float clamped_thickness = clamp(depth_thickness, 0.005, 0.01);

    // --- VertexOffset ---
    // Multiply the normal displacement by the calculated thickness and add it to the vertex position
    vec3 final_offset = base_normal_scaling * vec3(clamped_thickness);
    VERTEX = final_offset + VERTEX;
}

void fragment() {
    // The outline color is pure black and does not receive light (unshaded)
    ALBEDO = vec3(0.0);
}
