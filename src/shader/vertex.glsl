#pragma language glsl3

//const int MAX_POINT_LIGHTS = 10;
// the distance at which the dynamic shadowmap ends, its here
// we transition from sampling the dynamic shadowmap to the static one
const float DIR_LIGHT_TRANSITION_DISTANCE = 350;

varying vec3 frag_position;
varying vec3 frag_w_position;
varying vec4 dir_frag_light_pos;
varying vec4 dir_static_frag_light_pos;
varying vec3 frag_normal;
varying vec2 texscale;
varying vec2 texoffset;

//uniform int POINT_LIGHT_COUNT;
uniform float disable_shadows;
uniform mat4 u_dir_lightspace;
uniform mat4 u_dir_static_lightspace;
//uniform mat4 u_point_lightspaces[MAX_POINT_LIGHTS];

#ifdef VERTEX

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

uniform mat4 u_bone_matrices[48];
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

mat3 get_normal_matrix(mat4 skin_u) {
	// u_normal_model matrix is calculated outside and passed to shader
	// if skinning is enabled then this needs to be recalculated
	if (u_skinning != 0 || instance_draw_call) {
		return mat3(transpose(inverse(skin_u)));
	}
	return mat3(u_normal_model);
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
	//mat4 modelview_u = u_rot * u_view * skin_u;
	mat4 skinview_u = u_view * skin_u;

	frag_normal = get_normal_matrix(skin_u) * VertexNormal;

	vec4 model_v = skin_u * vertex;
	vec4 view_v = skinview_u * vertex;

	// create a fake curved horizon effect
	if (curve_flag) {
		view_v.y = view_v.y + (view_v.z*view_v.z) / curve_coeff; }

	view_v = u_rot * view_v;

	// interpolate fragment position in viewspace and worldspace
	frag_position = view_v.xyz;
	frag_w_position = model_v.xyz;

	// calculate fragment position in lightspaces
	dir_frag_light_pos = (u_dir_lightspace * model_v) * (1.0-disable_shadows);
	dir_static_frag_light_pos = (u_dir_static_lightspace * model_v) * (1.0-disable_shadows);

	// apply texture offset/scaling
	texscale = TextureScale;
	if (texscale.x == 0) { texscale.x = 1; }
	if (texscale.y == 0) { texscale.y = 1; }
	texoffset = TextureOffset;

	return u_proj * view_v;
}
#endif

#ifdef PIXEL

uniform float fog_start;
uniform float fog_end;
uniform vec3  fog_colour;

uniform bool texture_animated;
uniform int  texture_animated_dimx;
uniform int  texture_animated_frame;
uniform int  texture_animated_framecount;

uniform vec3 view_pos;
uniform vec3 light_dir;
uniform vec4 light_col;
uniform vec4 ambient_col;

uniform Image MainTex;
uniform sampler2DShadow dir_shadow_map; 
uniform sampler2DShadow dir_static_shadow_map;
uniform vec3 dir_light_dir;
uniform vec4 dir_light_col;

//uniform sampler2DShadow point_shadow_maps[MAX_POINT_LIGHTS];

uniform float draw_to_outline_buffer;
uniform vec4 outline_colour;

vec3 ambient_lighting( vec4 ambient_col ) {
	return ambient_col.rgb * ambient_col.a;
}

vec3 diffuse_lighting( vec3 normal, vec3 light_dir, vec4 light_col) {
	float diff = 0.0;
	if (dot(normal, normalize(light_dir)) > 0.0) {
		diff = 1.0 - pow(diff,4);
	}
	//float diff = max(0.0, dot(normal, normalize(light_dir)));
	vec3 diff_col = light_col.rgb * light_col.a * diff;
	return diff_col;
}

vec3 specular_highlight( vec3 normal , vec3 light_dir, vec4 light_col ) {
	float specular_strength = 1;

	vec3 view_dir = normalize( view_pos - frag_position );
	vec3 light_dir_n = normalize( light_dir);
	vec3 halfway_v = normalize(light_dir_n + view_dir);

	float spec = pow(  max(dot(normal,halfway_v),  0.0), 5);

	return spec * specular_strength * light_col.rgb * light_col.a;
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

const vec2 poissonDisk[16] = vec2[](
   vec2( -0.94201624, -0.39906216 ),
   vec2( 0.94558609, -0.76890725 ),
   vec2( -0.094184101, -0.92938870 ),
   vec2( 0.34495938, 0.29387760 ),
   vec2( -0.91588581, 0.45771432 ),
   vec2( -0.81544232, -0.87912464 ),
   vec2( -0.38277543, 0.27676845 ),
   vec2( 0.97484398, 0.75648379 ),
   vec2( 0.44323325, -0.97511554 ),
   vec2( 0.53742981, -0.47373420 ),
   vec2( -0.26496911, -0.41893023 ),
   vec2( 0.79197514, 0.19090188 ),
   vec2( -0.24188840, 0.99706507 ),
   vec2( -0.81409955, 0.91437590 ),
   vec2( 0.19984126, 0.78641367 ),
   vec2( 0.14383161, -0.14100790 )
);

const vec2 distantPoints[4] = vec2[](
   vec2( -0.9, -0.9 ),
   vec2(  0.9, -0.9 ),
   vec2(  0.9,  0.9 ),
   vec2( -0.9,  0.9 )
);

float random(vec3 seed, int i){
	vec4 seed4 = vec4(seed,i);
	float dot_product = dot(seed4, vec4(12.9898,78.233,45.164,94.673));
	return fract(sin(dot_product) * 43758.5453);
}

// unfortunately Texture:setWrap("clampone") is only in Love2D 12.0 (not released yet)
// have to do to it manually...
float texture_shadow_clampone(sampler2DShadow shadow, vec3 vec) {
	if (vec.x <= 0.0 || vec.x >= 1.0 || vec.y <= 0.0 || vec.y >= 1.0 || vec.z <= 0.0 || vec.z >= 1.0) {
		return 1.0;
	} else {
		return texture(shadow, vec);
	}
}

float shadow_calculation( vec4 pos , mat4 lightspace, sampler2DShadow shadow_map , vec3 normal , vec3 light_dir) {
	vec4 prooj_coords = pos.xyzw;
	prooj_coords = vec4(prooj_coords.xyz * 0.5 + 0.5, prooj_coords.w);

	float cosTheta = clamp( dot( normal,light_dir ), 0,1 );

	float curr_depth    = prooj_coords.z;

	float bias = 0.00125*tan(acos(cosTheta));
	float radius = 2000.0;
	bias = clamp(bias, 0.00100,0.00230);

	float shadow = 1.0;

	// first we sample 4 distant points, if all 4 are either in shadow or in light its likely that any other points
	// we sample would also be in shadow or in light
	for (int i=0; i<4; i++) {
		float s = texture_shadow_clampone( shadow_map, vec3(prooj_coords.xy + distantPoints[i]/radius, (curr_depth/prooj_coords.w)-bias));
		shadow -= (1.0/16.0) * s;
	}

	// if all distant points are in shadow, then return 1.0 (fully in shadow)
	// otherwise 0.0 (fully in light)
	if (shadow == 1.0) {
		return 1.0;
	} else if (shadow <= 1.0 - 3.9 * (1/16.0)) {
		return 0.0;
	}

	for (int i=0; i<12; i++) {
		int index = int(16.0*random(floor(frag_w_position.xyz*1000.0), i))%16;
		shadow -= (1.0/16.0) * texture_shadow_clampone( shadow_map, vec3(prooj_coords.xy + poissonDisk[index]/radius, (curr_depth/prooj_coords.w)-bias));
	}

	return shadow;
}

// love_Canvases[0] = HDR color
// love_Canvases[1] = outline buffer

vec3 calc_dir_light_col(vec4 frag_light_pos, vec4 static_frag_light_pos, mat4 lightspace, mat4 static_lightspace, sampler2DShadow map, sampler2DShadow static_map,
 vec3 normal, vec3 dir, vec4 col, float frag_dist) {
	
	vec3 light_dir_n = normalize(-dir);
	vec3 diffuse = diffuse_lighting( normal, light_dir_n, col);
	vec3 specular = specular_highlight( normal , light_dir_n, col);

	float shadow = 0.0;
	if (disable_shadows == 0.0) {
		const float transition_end = DIR_LIGHT_TRANSITION_DISTANCE;
		const float transition_start = DIR_LIGHT_TRANSITION_DISTANCE - 30;
		const float difference = transition_end - transition_start;

		float interp = clamp((frag_dist - transition_start)/difference,0.0,1.0);

		float close_shadow = 0.0;
		float static_shadow = 0.0;

		if (interp >= 0.0) {
			close_shadow = shadow_calculation(frag_light_pos, lightspace,
			  map, normal , light_dir_n);
		}
		if (interp <= 1.0) {
			static_shadow = shadow_calculation(static_frag_light_pos, static_lightspace,
			  static_map, normal, light_dir_n);
		}


		shadow = close_shadow * (1.0 - interp) + static_shadow * interp;
	}

	return (1.0-shadow)*(diffuse + specular);
}

void effect( ) {
	float dist = frag_position.z*frag_position.z + frag_position.x*frag_position.x;
	dist = sqrt(dist);

	float fog_r = (dist - fog_start) / (fog_end - fog_start);
	fog_r = clamp(fog_r, 0.0,1.0);

	vec3 light = ambient_lighting( ambient_col );
	vec3 dir_light_result = calc_dir_light_col(dir_frag_light_pos, dir_static_frag_light_pos, u_dir_lightspace, u_dir_static_lightspace,
		dir_shadow_map, dir_static_shadow_map,
		frag_normal, dir_light_dir, dir_light_col, dist);

	light += dir_light_result;

	vec2 coords = calc_tex_coords(vec2(VaryingTexCoord));

	coords = coords / texscale;

	vec4 texcolor = Texel(MainTex, coords);
	vec4 pix = texcolor * vec4(light,1.0);

	// TODO make the fog colour work properly with HDR
	vec4 result = vec4((1-fog_r)*pix.rgb + fog_r*fog_colour, pix.a);

	love_Canvases[0] = result;
	love_Canvases[1] = vec4(outline_colour) * draw_to_outline_buffer;
}

#endif
