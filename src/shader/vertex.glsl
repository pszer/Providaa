#pragma language glsl3

varying vec3 frag_position;
varying vec3 frag_w_position;
varying vec4 frag_light_pos[24];
varying vec3 frag_normal;
varying vec2 texscale;
varying vec2 texoffset;

uniform int LIGHT_COUNT;
uniform mat4 u_lightspaces[24];

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
	if (u_skinning != 0) {
		return mat3(transpose(inverse(skin_u)));
	}
	return mat3(u_normal_model);
}

vec4 position(mat4 transform, vec4 vertex) {
	mat4 skin_u = u_model * get_deform_matrix();
	mat4 modelview_u = u_rot * u_view * skin_u;

	frag_normal = get_normal_matrix(skin_u) * VertexNormal;

	vec4 model_v = skin_u * vertex;
	vec4 view_v = modelview_u * vertex;

	// create a fake curved horizon effect
	if (curve_flag) {
		view_v.y = view_v.y + (view_v.z*view_v.z) / curve_coeff; }

	frag_position = view_v.xyz;
	frag_w_position = model_v.xyz;

	for (int i = 0; i < LIGHT_COUNT; i++) {
		frag_light_pos[i] = u_lightspaces[i] * model_v;
	}

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
uniform sampler2DShadow shadow_maps[24]; 

vec3 ambient_lighting( vec4 ambient_col ) {
	return ambient_col.rgb * ambient_col.a;
}

vec3 diffuse_lighting( vec3 normal, vec3 light_dir, vec4 light_col) {
	float diff = max(0.0, dot(normal, normalize(light_dir)));
	vec3 diff_col = light_col.rgb * light_col.a * diff;
	return diff_col;
}

vec3 specular_highlight( vec3 normal , vec3 light_dir, vec4 light_col ) {
	float specular_strength = 0.5;

	vec3 view_dir = normalize( view_pos - frag_position );
	vec3 light_dir_n = normalize( light_dir);
	vec3 halfway_v = normalize(light_dir_n + view_dir);

	float spec = pow(  max(dot(normal,halfway_v),  0.0), 0.5);

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

float random(vec3 seed, int i){
	vec4 seed4 = vec4(seed,i);
	float dot_product = dot(seed4, vec4(12.9898,78.233,45.164,94.673));
	return fract(sin(dot_product) * 43758.5453);
}

float shadow_calculation( vec4 pos , mat4 lightspace, sampler2DShadow shadow_map ) {
	vec3 prooj_coords = pos.xyz / pos.w;
	prooj_coords = prooj_coords * 0.5 + 0.5;

	float curr_depth    = prooj_coords.z;
	float bias = 0.0005;

	float shadow = 0.0;
	for (int i=0;i<4;i++){
		int index = int(16.0*random(floor(frag_w_position.xyz*1000.0), i))%16;
		shadow += 0.25 * (1.0- texture( shadow_map, vec3(prooj_coords.xy + poissonDisk[index]/20000.0, curr_depth-bias), 0));
	}

	return shadow;
}

void effect( ) {
	float dist = frag_position.z*frag_position.z + frag_position.x*frag_position.x;
	dist = sqrt(dist);

	vec3 light_dir_n = normalize(-light_dir);

	float fog_r = (dist - fog_start) / (fog_end - fog_start);
	fog_r = clamp(fog_r, 0.0,1.0);

	vec3 ambient = ambient_lighting( ambient_col );
	vec3 diffuse = diffuse_lighting(frag_normal, light_dir_n, light_col);
	vec3 specular = specular_highlight( frag_normal , light_dir_n, light_col);

	// TODO implement multiple light sources
	float shadow = shadow_calculation(frag_light_pos[0], u_lightspaces[0], shadow_maps[0]);

	vec4 light = vec4(ambient + (1.0-shadow)*(diffuse + specular), 1.0);

	vec4 texcolor;
	vec2 coords = calc_tex_coords(vec2(VaryingTexCoord));

	coords = coords / texscale;

	//texcolor = Texel(tex, coords);
	texcolor = Texel(MainTex, coords);
	vec4 pix = texcolor * light;

	// TODO make the fog colour work properly with HDR
	vec4 result = vec4((1-fog_r)*pix.rgb + fog_r*fog_colour, 1.0);

	float brightness = dot(result.rgb, vec3(0.2126, 0.7152, 0.0722));

	love_Canvases[0] = result;
	if (brightness > 1.5) {
		love_Canvases[1] = result;
	} else {
		love_Canvases[1] = vec4(0.0,0.0,0.0,1.0);
	}
	//return result;
}

#endif
