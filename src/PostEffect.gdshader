shader_type spatial;
render_mode unshaded;

void vertex() {
    POSITION = vec4(VERTEX, 1.0);
    POSITION.z = 0.0;
}

// exposed uniforms
uniform float DepthThreshold : hint_range(0.0, 10.0) = 0.1;
uniform float LumaLikenessThreshold : hint_range(0.0, 1.0) = 0.15;
uniform float NormalDotOffset : hint_range(0.0, 1.0) = 0.9;
uniform int Range : hint_range(0, 32) = 5;
uniform float Gamma : hint_range(1.0, 2.2) = 2.2;

#define NORMAL_LIKENESS_THRESHOLD 0.05
#define DEPTH_DISABLED_VALUE 0.0
#define NORMALS_DISABLED_VALUE 0.0
#define COLORS_DISABLED_VALUE 1.0
#define DEPTH_NORMAL_HACK false
#define DO_DIAGONALS true

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, source_color, filter_nearest;
uniform sampler2D normal_texture : hint_normal_roughness_texture, repeat_disable, source_color, filter_nearest;

float get_linear_depth(vec2 uv, mat4 mat)
{
    float depth = texture(depth_texture, uv).x;
    vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
    vec4 view = mat * vec4(ndc, 1.0);
    view.xyz /= view.w;
    float linear_depth = -view.z;
    return linear_depth;
}

float getInfoDepth(vec2 texcoord, mat4 mat)
{
    float depth = get_linear_depth(texcoord, mat);
    return depth;
}
float compare_depth(float depth_a, float sqrt_b, float view_dot, float sqrt_far)
{
    float sqrt_a = sqrt(depth_a);
    float depth_diff = abs(sqrt_a - sqrt_b);
    if ((sqrt_a == sqrt_far) != (sqrt_b == sqrt_far))
        depth_diff = 1000000.0;
    return depth_diff;
}
float depth_compare(vec2 texcoord, float sqrt_b, float view_dot, mat4 mat, float sqrt_far)
{
    return compare_depth(getInfoDepth(texcoord, mat), sqrt_b, view_dot, sqrt_far);
}
bool is_similar_depth(float depth_diff)
{
    return depth_diff <= DepthThreshold;
}
float is_similar_depth_f(float depth_diff)
{
    return is_similar_depth(depth_diff) ? 0.0 : 1.0;
}

vec3 getInfoNormal(vec2 texcoord)
{
    vec3 normal = texture(normal_texture, texcoord).rgb*2.0 - 1.0;
    return normal;
}
float compare_normal(vec3 normal_a, vec3 normal_b)
{
    float dp = dot(normal_a, normal_b); // 1.0 to -1.0 (1.0 being more similar)
    float normal_diff = 1.0 - dp; // now 0.0 to 2.0 (0.0 being more similar)
    normal_diff += NormalDotOffset*2.0;
    normal_diff = max(0.0, normal_diff-2.0);
    
    float normal_length = length(normal_a);
    // bogus normal, probably a rendering bug, or the sky. treat as same as neighbor
    if(normal_length > 1.1 || normal_length < 0.9)
        normal_diff = 0.0;
    
    return normal_diff;
}
float normal_compare(vec2 texcoord, vec3 normal_b)
{
    return compare_normal(getInfoNormal(texcoord), normal_b);
}
bool is_similar_normal(float normal_diff)
{
    return normal_diff < NORMAL_LIKENESS_THRESHOLD;
}
float is_similar_normal_f(float normal_diff)
{
    return is_similar_normal(normal_diff) ? 0.0 : 1.0;
}

vec3 getInfoColor(vec2 texcoord)
{
    return texture(screen_texture, texcoord).rgb;
}

float color_compare(vec2 texcoord, vec3 color_b)
{
    vec3 color_a = sqrt(getInfoColor(texcoord));
    vec3 c = color_a - color_b;
    float luma_diff = dot(c, c);
    return luma_diff;
}
bool is_similar_color(float color_diff)
{
    return color_diff < (LumaLikenessThreshold*LumaLikenessThreshold);
}
float is_similar_color_f(float color_diff)
{
    return is_similar_color(color_diff) ? 0.0 : 1.0;
}

struct edge_info {
    float left_like;
    float right_like;
    bool left_open;
    bool right_open;
};

edge_info follow_edge(vec2 texcoord, mat2 to_px_2, int aa_mode, float center, float view_dot, mat4 mat, float sqrt_far, vec3 center_normal, vec3 center_color, int range)
{
    float left_like = 0.0;
    float right_like = 0.0;
    bool left_open = true;
    bool right_open = true;
    
    vec2 b_plus = vec2(0.0, -1.0) * to_px_2;
    vec2 a_plus_raw = vec2(1.0, 0.0) * to_px_2;
    
    for(int xsign = -1; xsign <= 1; xsign += 2)
    {
        vec2 a_plus = a_plus_raw*float(xsign);
        
        float left_plus  = xsign > 0 ? 0.0 : 1.0;
        float right_plus = xsign < 0 ? 0.0 : 1.0;
        for(int x = 1; x <= range; x += 1)
        {
            vec2 coord_a = texcoord + a_plus*float(x);
            vec2 coord_b = coord_a + b_plus;
            bool info_a = false;
            bool info_b = false;
            // pick likeness comparison info depending on aa mode
            if (aa_mode == 1)
            {
                info_a = is_similar_depth(depth_compare(coord_a, center, view_dot, mat, sqrt_far));
                info_b = is_similar_depth(depth_compare(coord_b, center, view_dot, mat, sqrt_far));
            }
            else if (aa_mode == 2)
            {
                info_a = is_similar_normal(normal_compare(coord_a, center_normal));
                info_b = is_similar_normal(normal_compare(coord_b, center_normal));
            }
            else// if (aa_mode == 3)
            {
                info_a = is_similar_color(color_compare(coord_a, center_color));
                info_b = is_similar_color(color_compare(coord_b, center_color));
            }
            // set closed ends appropriately if closed
            left_open  = left_open  && (info_b || info_a || xsign ==  1);
            right_open = right_open && (info_b || info_a || xsign == -1);
            // break on end
            if(info_b || !info_a)
                break;
            // otherwise continue following edge
            left_like  += left_plus;
            right_like += right_plus;
        }
    }
    edge_info ret = edge_info(left_like, right_like, left_open, right_open);
    return ret;
}

void fragment()
{
    vec2 texcoord = SCREEN_UV;
    vec4 base_color = texture(screen_texture, texcoord);
    
    vec3 view = normalize((PROJECTION_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
    
    mat4 mat = INV_PROJECTION_MATRIX;
    
    vec4 temp = mat * vec4(0.0, 0.0, 1.0, 1.0);
    temp /= temp.w;
    float sqrt_far = sqrt(-temp.z);
    
    float linear_depth = get_linear_depth(SCREEN_UV, mat);
    
    vec2 res = 1.0/vec2(textureSize(screen_texture, 0));
    
    vec3 center_normal = getInfoNormal(texcoord);
    
    float center = 0.0;
    vec3 center_color = vec3(0.0);
    
    float view_dot = abs(dot(view, center_normal));
    
    float top    = 0.0;
    float bottom = 0.0;
    float left   = 0.0;
    float right  = 0.0;
    
    int aa_mode = 0; // 0 - none, 1 - depth, 2 - normal, 3 - color
    if (aa_mode == 0 && DepthThreshold != DEPTH_DISABLED_VALUE)
    {
        center = sqrt(linear_depth);
        top    = depth_compare(texcoord + vec2( 0.0, -1.0)*res, center, view_dot, mat, sqrt_far);
        bottom = depth_compare(texcoord + vec2( 0.0,  1.0)*res, center, view_dot, mat, sqrt_far);
        left   = depth_compare(texcoord + vec2(-1.0,  0.0)*res, center, view_dot, mat, sqrt_far);
        right  = depth_compare(texcoord + vec2( 1.0,  0.0)*res, center, view_dot, mat, sqrt_far);
        
        if (!is_similar_depth(max(max(top, bottom), max(left, right))))
            aa_mode = 1;
    }
    // (only fall back to normals AA if not sky)
    if(aa_mode == 0 && NormalDotOffset != NORMALS_DISABLED_VALUE && center < sqrt_far*0.95)
    {
        top    = normal_compare(texcoord + vec2( 0.0, -1.0)*res, center_normal);
        bottom = normal_compare(texcoord + vec2( 0.0,  1.0)*res, center_normal);
        left   = normal_compare(texcoord + vec2(-1.0,  0.0)*res, center_normal);
        right  = normal_compare(texcoord + vec2( 1.0,  0.0)*res, center_normal);
    
        if (!is_similar_normal(max(max(top, bottom), max(left, right))))
            aa_mode = 2;
    }
    if(aa_mode == 0 && LumaLikenessThreshold != COLORS_DISABLED_VALUE)
    {
        center_color = sqrt(base_color.rgb);
        top    = color_compare(texcoord + vec2( 0.0, -1.0)*res, center_color);
        bottom = color_compare(texcoord + vec2( 0.0,  1.0)*res, center_color);
        left   = color_compare(texcoord + vec2(-1.0,  0.0)*res, center_color);
        right  = color_compare(texcoord + vec2( 1.0,  0.0)*res, center_color);
        
        if (!is_similar_color(max(max(top, bottom), max(left, right))))
            aa_mode = 3;
    }
    
    // skip if no edges
    if (aa_mode == 0)
    {
        ALBEDO = base_color.rgb;
    }
    else
    {
        // edge-following AA
        
        float tl = 0.0;
        float tr = 0.0;
        float bl = 0.0;
        float br = 0.0;
        
        float t = 0.0;
        float b = 0.0;
        float l = 0.0;
        float r = 0.0;
        
        // evaluate similarity of nearby eight neighbors
        if (aa_mode == 1)
        {
            tl = is_similar_depth_f(depth_compare(texcoord + vec2(-1.0, -1.0)*res, center, view_dot, mat, sqrt_far));
            tr = is_similar_depth_f(depth_compare(texcoord + vec2( 1.0, -1.0)*res, center, view_dot, mat, sqrt_far));
            bl = is_similar_depth_f(depth_compare(texcoord + vec2(-1.0,  1.0)*res, center, view_dot, mat, sqrt_far));
            br = is_similar_depth_f(depth_compare(texcoord + vec2( 1.0,  1.0)*res, center, view_dot, mat, sqrt_far));
            
            t = is_similar_depth_f(top   );
            b = is_similar_depth_f(bottom);
            l = is_similar_depth_f(left  );
            r = is_similar_depth_f(right );
        }
        else if (aa_mode == 2)
        {
            tl = is_similar_normal_f(normal_compare(texcoord + vec2(-1.0, -1.0)*res, center_normal));
            tr = is_similar_normal_f(normal_compare(texcoord + vec2( 1.0, -1.0)*res, center_normal));
            bl = is_similar_normal_f(normal_compare(texcoord + vec2(-1.0,  1.0)*res, center_normal));
            br = is_similar_normal_f(normal_compare(texcoord + vec2( 1.0,  1.0)*res, center_normal));
            
            t = is_similar_normal_f(top   );
            b = is_similar_normal_f(bottom);
            l = is_similar_normal_f(left  );
            r = is_similar_normal_f(right );
        }
        else if (aa_mode == 3)
        {
            tl = is_similar_color_f(color_compare(texcoord + vec2(-1.0, -1.0)*res, center_color));
            tr = is_similar_color_f(color_compare(texcoord + vec2( 1.0, -1.0)*res, center_color));
            bl = is_similar_color_f(color_compare(texcoord + vec2(-1.0,  1.0)*res, center_color));
            br = is_similar_color_f(color_compare(texcoord + vec2( 1.0,  1.0)*res, center_color));
            
            t = is_similar_color_f(top   );
            b = is_similar_color_f(bottom);
            l = is_similar_color_f(left  );
            r = is_similar_color_f(right );
        }
        
        // compare eight neighbors
        // (eight are needed because otherwise this pattern is ambiguous w/r/t up/down vs left/right:)
        // (X X .)
        // (X X .)
        // (X . .)
        // (because with only four neighbors, it looks like:)
        // (? X ?)
        // (X X .)
        // (? . ?)
        
        float t_compare  = tl*0.25 + tr*0.25 + t*0.5;
        float b_compare  = bl*0.25 + br*0.25 + b*0.5;
        float l_compare  = tl*0.25 + bl*0.25 + l*0.5;
        float r_compare  = tr*0.25 + br*0.25 + r*0.5;
        
        float tl_compare = DO_DIAGONALS ? t*0.5 + l*0.5 : 0.0;
        float tr_compare = DO_DIAGONALS ? t*0.5 + r*0.5 : 0.0;
        float bl_compare = DO_DIAGONALS ? b*0.5 + l*0.5 : 0.0;
        float br_compare = DO_DIAGONALS ? b*0.5 + r*0.5 : 0.0;
        
        float comparisons[8] = {t_compare, b_compare, l_compare, r_compare, tl_compare, tr_compare, bl_compare, br_compare};
        mat2 mats[8] = {mat2(vec2(res.x, 0.0), vec2(0.0, res.y)),
                        mat2(vec2(res.x, 0.0), vec2(0.0, -res.y)),
                        mat2(vec2(0.0, res.x), vec2(res.y, 0.0)),
                        mat2(vec2(0.0, -res.x), vec2(res.y, 0.0)),
                        mat2(vec2(-res.x,  res.x), vec2(res.y, 0.0)),
                        mat2(vec2(-res.x, -res.x), vec2(res.y, 0.0)),
                        mat2(vec2( res.x, -res.x), vec2(res.y, 0.0)),
                        mat2(vec2( res.x,  res.x), vec2(res.y, 0.0))};
        
        // figure out what type of edge we're on and configure the edge search accordingly
        
        bool skip = false;

        float max_compare = max(max(max(t_compare, b_compare), max(l_compare, r_compare)), max(max(tl_compare, bl_compare), max(tr_compare, br_compare)));
        
        // pick walking transform based on what direction the edge is going in
        mat2 to_px_2 = mat2(vec2(0.0, 0.0), vec2(0.0, 0.0));
        int found = -1;
        if (DO_DIAGONALS)
        {
            for(int i = 0; i < 8; i++)
            {
                if (comparisons[i] == max_compare)
                {
                    if (found >= 0)
                    {
                        // If we found two equal best candidates, run two edge followings at a low range
                        // to figure out which one is longer, then use that.
                        // This is needed to disambituate this type of pattern:
                        // (X X X)
                        // (X . .)
                        // (. . .)
                        // as to whether it's diagonal or not.
                        edge_info first = follow_edge(texcoord, mats[found], aa_mode, center, view_dot, mat, sqrt_far, center_normal, center_color, 2);
                        edge_info second = follow_edge(texcoord, mats[i], aa_mode, center, view_dot, mat, sqrt_far, center_normal, center_color, 2);
                        if (second.left_like + second.right_like > first.left_like + first.right_like)
                        {
                            found = i;
                            break;
                        }
                        else
                            break;
                        // always break to ensure that we don't run edge-following several times in worst-case scenarios
                    }
                    else
                        found = i;
                }
            }
            to_px_2 = mats[found];
        }
        else
        {
            for(int i = 0; i < 8 && found < 0; i++)
            {
                if (comparisons[i] == max_compare)
                    found = i;
            }
        }
        
        if(!skip)
        {
            // follow edge and find the ratio of like to unlike pixels to estimate
            edge_info info = follow_edge(texcoord, to_px_2, aa_mode, center, view_dot, mat, sqrt_far, center_normal, center_color, Range);
            bool left_open = info.left_open;
            bool right_open = info.right_open;
            float left_like = info.left_like;
            float right_like = info.right_like;
            
            // fix up data for convex bits
            if(!left_open && !right_open)
            {
                left_open = left_like >= right_like;
                right_open = !left_open;
            }
            // calculate the blending ratio based on the number of open and closed neighboring pixels
            // this is the calculation that approximates proportionally where along the edge we are
            float blend_amount = 0.0;
            float pixel_range = left_like + right_like + 1.0;
            if (left_open != right_open)
                blend_amount = ((left_open ? left_like : right_like)+0.5)/(pixel_range) - 0.5;
            blend_amount = clamp(blend_amount, 0.0, 1.0);
            
            vec4 next_color = texture(screen_texture, texcoord + vec2(0.0, -1.0) * to_px_2);
            
            // blend neighboring edge pixel into center pixel based on ratio of low to high pixels
            // this is the step that approximately reconstructs the original shape
            vec3 gamma_inv = vec3(1.0/Gamma);
            vec3 color_a = pow(base_color.rgb, gamma_inv);
            vec3 color_b = pow(next_color.rgb, gamma_inv);
            vec3 blend_color = mix(color_a, color_b, blend_amount);
            
            ALBEDO = pow(blend_color, vec3(Gamma));
        }
        else
        {
            ALBEDO = base_color.rgb;
        }
    }
}