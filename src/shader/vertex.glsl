#pragma language glsl3

extern mat4 u_proj;
extern mat4 u_view;
extern mat4 u_rot;
extern mat4 u_model;
extern mat3 u_normal_model;
//
extern float curve_coeff;
extern bool curve_flag;

varying vec3 frag_position;
varying vec3 frag_normal;
varying vec2 texscale;
varying vec2 texoffset;
varying vec3 view_pos;
varying vec3 view_dir;

#ifdef VERTEX

attribute vec3 VertexNormal;
attribute vec4 VertexWeight;
attribute vec4 VertexBone;
attribute vec4 VertexTangent;

attribute vec2 TextureScale;
attribute vec2 TextureOffset;

uniform mat4 u_bone_matrices[64];
uniform int  u_skinning;

mat4 get_deform_matrix() {
	if (u_skinning != 0) {
		return
			u_bone_matrices[int(VertexBone.x*255.0)] * VertexWeight.x +
			u_bone_matrices[int(VertexBone.y*255.0)] * VertexWeight.y +
			u_bone_matrices[int(VertexBone.z*255.0)] * VertexWeight.z +
			u_bone_matrices[int(VertexBone.w*255.0)] * VertexWeight.w;
	}
	return mat4(1.0);
}

mat3 get_normal_matrix(mat4 modelview_u) {
	// u_normal_model matrix is calculated outside and passed to shader
	// if skinning is enabled then this needs to be recalculated
	if (u_skinning != 0) {
		return mat3(transpose(inverse(modelview_u)));
	}
	return u_normal_model;
}

vec4 position(mat4 transform, vec4 vertex) {
	mat4 skin_u = u_model * get_deform_matrix();
	mat4 modelview_u = u_rot * u_view * skin_u;

	vec4 view_v = modelview_u * vertex;

	if (curve_flag) {
		view_v.y = view_v.y + (view_v.z*view_v.z) / curve_coeff; }

	frag_position = view_v.xyz;
	frag_normal = get_normal_matrix(modelview_u) * VertexNormal;

	texscale = TextureScale;
	if (texscale.x == 0) { texscale.x = 1; }
	if (texscale.y == 0) { texscale.y = 1; }
	texoffset = TextureOffset;

	vec4 pos_v = u_proj * view_v;
	return pos_v;
}
#endif



#ifdef PIXEL

extern float fog_start;
extern float fog_end;
extern vec4  fog_colour;

extern bool texture_animated;
extern int  texture_animated_dimx;
extern int  texture_animated_frame;
extern int  texture_animated_framecount;

extern vec3 light_dir;
extern vec3 light_col;
extern vec3 ambient_col;
extern float ambient_str;

vec3 ambient_lighting( vec3 normal, vec3 light_dir, vec3 light_col, vec3 ambient_col, float ambient_str ) {
	float diff = max(0.0, dot(normal, normalize(light_dir)));
	vec3 diff_col = light_col * diff;
	return diff_col + ambient_col*ambient_str;
}

vec3 specular_highlight( vec3 normal , vec3 light_dir, vec3 light_col ) {
	float specular_strength = 0.01;
	vec3 view_dir = normalize(-frag_position);
	vec3 light_dir_n = normalize(light_dir);
	vec3 halfway_v = normalize(light_dir_n + view_dir);

	//vec3 reflect_dir = reflect(-light_dir, normal);

	float spec = pow(max(dot(normal,halfway_v),0.0), 48);

	return spec * specular_strength * light_col;
}

vec2 calc_tex_coords( vec2 uv_coords ) {
	if (!texture_animated) {
		return uv_coords + texoffset;
	} else {
		vec2 step = vec2(1.0,1.0) / float(texture_animated_dimx);

		vec2 texpos = vec2(mod(texture_animated_frame,texture_animated_dimx), texture_animated_frame / texture_animated_dimx);
		return mod(uv_coords + texoffset,vec2(1,1))*step + texpos*step;
	}
}

vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords ) {
	float dist = frag_position.z*frag_position.z + frag_position.x*frag_position.x;
	dist = sqrt(dist);

	vec3 light_dir_n = normalize(light_dir);

	float fog_r = (dist - fog_start) / (fog_end - fog_start);
	fog_r = clamp(fog_r, 0.0,1.0);
	if (fog_r > 0.99) { return fog_colour; }

	vec3 light_result = ambient_lighting(frag_normal, light_dir_n, light_col, ambient_col, ambient_str);
	vec3 specular_result = specular_highlight( frag_normal , light_dir_n, light_col);
	vec4 light = vec4(light_result + specular_result, 1.0);

	vec4 texcolor;
	vec2 coords = calc_tex_coords(texture_coords);

	coords = coords / texscale;

	texcolor = Texel(tex, coords);
	vec4 pix = texcolor * light;

	return (1-fog_r)*pix + fog_r*fog_colour;
}
#endif
