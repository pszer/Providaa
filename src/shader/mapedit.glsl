#pragma language glsl3

varying vec3 frag_position;
varying vec3 frag_w_position;
varying vec4 dir_frag_light_pos;
varying vec4 dir_static_frag_light_pos;
varying vec3 frag_normal;

uniform int u_point_light_count;
uniform float u_shadow_imult;
uniform mat4 u_dir_lightspace;
uniform mat4 u_dir_static_lightspace;

uniform float skybox_brightness;

uniform bool  u_uses_tileatlas;
uniform Image u_tileatlas;
uniform vec4  u_tileatlas_uv[128];

#ifdef VERTEX

flat out vec2 texscale;
flat out vec2 texoffset;
flat out int  tex_uv_index;

uniform mat4 u_view;
uniform mat4 u_rot;
uniform mat4 u_model;
uniform mat4 u_proj;
uniform mat4 u_normal_model;

//
uniform float curve_coeff;
uniform bool curve_flag;

attribute vec3 VertexNormal;
attribute vec4 VertexWeight;
attribute vec4 VertexBone;
attribute vec4 VertexTangent;

uniform bool instance_draw_call;
attribute vec4 InstanceColumn1;
attribute vec4 InstanceColumn2;
attribute vec4 InstanceColumn3;
attribute vec4 InstanceColumn4;

attribute vec2 TextureScale;
attribute vec2 TextureOffset;
attribute float TextureUvIndex;

uniform mat4 u_bone_matrices[48];
uniform int  u_skinning;

uniform float u_contour_outline_offset;

mat4 get_deform_matrix() {
	return mat4(1.0);
}

mat3 get_normal_matrix(mat4 skin_u) {
	return mat3(transpose(inverse(skin_u)));
}

mat4 get_instance_model() {
	return mat4(InstanceColumn1,
				InstanceColumn2,
				InstanceColumn3,
				InstanceColumn4);
}

mat4 get_model_matrix() {
	if (instance_draw_call) {
		return mat4(InstanceColumn1,
		            InstanceColumn2,
		            InstanceColumn3,
		            InstanceColumn4);
	} else {
		return u_model;
	}
}

vec4 position(mat4 transform, vec4 vertex) {
	mat4 skin_u = get_model_matrix() * get_deform_matrix();
	mat4 skinview_u = u_view * skin_u;

	frag_normal = normalize(get_normal_matrix(skin_u) * VertexNormal);

	vec4 model_v = skin_u * vertex;
	vec4 view_v = skinview_u * vertex;

	frag_position = (u_rot * view_v).xyz;

	vec4 surface_offset = vec4(frag_normal * u_contour_outline_offset, 0.0);
	view_v += surface_offset;

	view_v = u_rot * view_v;

	// interpolate fragment position in viewspace and worldspace
	frag_w_position = model_v.xyz;

	// calculate fragment position in lightspaces
	dir_frag_light_pos = (u_dir_lightspace * model_v) ;
	dir_static_frag_light_pos = (u_dir_static_lightspace * model_v) ;

	// apply texture offset/scaling
	if (u_uses_tileatlas) {
		texscale = TextureScale;
		if (texscale.x == 0) { texscale.x = 1; }
		if (texscale.y == 0) { texscale.y = 1; }
		texoffset = TextureOffset;
		tex_uv_index = int(TextureUvIndex);
	}

	return u_proj * view_v;
}
#endif

#ifdef PIXEL

flat in vec2 texscale;
flat in vec2 texoffset;
flat in int  tex_uv_index;

uniform float fog_start;
uniform float fog_end;
uniform vec3  fog_colour;

uniform vec3 view_pos;
uniform vec3 light_dir;
uniform vec4 light_col;
uniform vec4 ambient_col;

vec3 ambient_lighting( vec4 ambient_col ) {
	return ambient_col.rgb * ambient_col.a;
}

// diffuse lighting with a "clamped effect", there is very little transition between
// points in light and points in shadow so things look flatter
vec3 diffuse_lighting( vec3 normal, vec3 light_dir, vec4 light_col) {
	//float diff = 0.0;
	float diff = max(0.0, dot(normalize(normal), normalize(light_dir))) ;
	if (diff > 0.0) {
		diff = 1.0 - pow( 1.0 - diff , 8 );
		diff = min(1.0, 1.3 * diff);
	}
	//float diff = max(0.0, dot(normal, normalize(light_dir)));
	vec3 diff_col = light_col.rgb * light_col.a * diff;
	return diff_col;
}

vec3 specular_highlight( vec3 normal , vec3 light_dir, vec4 light_col ) {
	return vec3(0,0,0)
}

vec2 calc_tex_coords( vec2 uv_coords ) {
	if (u_uses_tileatlas) {
		vec2 t_off = texoffset;
		vec2 t_scale = texscale;
		vec4 uv_info = u_tileatlas_uv[tex_uv_index];

		uv_coords.x = mod(uv_coords.x/t_scale.x + t_off.x, 1.0);
		uv_coords.y = mod(uv_coords.y/t_scale.y + t_off.y, 1.0);
		
		return vec2(
			uv_info.x + uv_info.z * uv_coords.x,
			uv_info.y + uv_info.w * uv_coords.y
		);
	} else {
		return uv_coords;
	}
}

void effect( ) {
	float dist = (frag_position.z*frag_position.z) + (frag_position.x*frag_position.x) + (frag_position.y*frag_position.y);
	dist = sqrt(dist);

	float fog_r = (dist - fog_start) / (fog_end - fog_start);
	fog_r = clamp(fog_r, 0.0,1.0);

	vec3 light = vec3(1.0,1.0,1.0);
	vec2 coords = calc_tex_coords(vec2(VaryingTexCoord));

	vec4 texcolor;
	texcolor = Texel(MainTex, coords);
	vec4 pix = texcolor * vec4(light,1.0);

	// TODO make the fog colour work properly with HDR
	vec4 result = vec4((1-fog_r)*pix.rgb + fog_r*skybox_brightness*fog_colour, pix.a);

	love_Canvases[0] = result;
}

#endif