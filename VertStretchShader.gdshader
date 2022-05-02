shader_type spatial;
render_mode specular_schlick_ggx, skip_vertex_transform;




void vertex() {
    //VERTEX = (vec4(VERTEX, 1.0) * INV_PROJECTION_MATRIX).rgb;
    //VERTEX = (vec4(VERTEX, 1.0) * INV_CAMERA_MATRIX).rgb;
    //VERTEX = (vec4(VERTEX, 1.0) * inverse(WORLD_MATRIX)).rgb;
    //VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).rgb;
    NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    vec4 ret = vec4(VERTEX, 1.0);
    ret = WORLD_MATRIX * ret;
    float b = INV_CAMERA_MATRIX[1][1];
    //ret.y /= clamp(b, cos(atan(0.5)), 1.0);
    ret.y /= clamp(b, cos(30.0/180.0*3.1415926535), 1.0);
    ret = INV_CAMERA_MATRIX * ret;
    VERTEX = ret.rgb;
// Output:0

}

void fragment() {
// Output:0

}

void light() {
// Output:0

}
