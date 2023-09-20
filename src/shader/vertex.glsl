#pragma language glsl3

const int MAX_POINT_LIGHTS = 9;
// the distance at which the dynamic shadowmap ends, its here
// we transition from sampling the dynamic shadowmap to the static one
const float DIR_LIGHT_TRANSITION_DISTANCE = 360;

varying vec3 frag_position;
varying vec3 frag_w_position;
varying vec4 dir_frag_light_pos;
varying vec4 dir_static_frag_light_pos;
varying vec3 frag_normal;

uniform int u_point_light_count;
uniform float u_shadow_imult;
uniform mat4 u_dir_lightspace;
uniform mat4 u_dir_static_lightspace;

// used to set the brightness of fog
uniform float skybox_brightness;

uniform bool  u_uses_tileatlas;
uniform Image u_tileatlas;
uniform vec4  u_tileatlas_uv[64];

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
	//return mat3(transpose(inverse(skin_u)));
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
	mat4 skinview_u = u_view * skin_u;

	frag_normal = normalize(get_normal_matrix(skin_u) * VertexNormal);

	vec4 model_v = skin_u * vertex;
	vec4 view_v = skinview_u * vertex;

	frag_position = (u_rot * view_v).xyz;

	vec4 surface_offset = vec4(frag_normal * u_contour_outline_offset, 0.0);
	view_v += surface_offset;

	// create a fake curved horizon effect
	if (curve_flag) {
		view_v.y = view_v.y + (view_v.z*view_v.z) / curve_coeff; }

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

uniform bool texture_animated;
uniform int  texture_animated_dimx;
uniform int  texture_animated_frame;
uniform int  texture_animated_framecount;

uniform vec3 view_pos;
uniform vec3 light_dir;
uniform vec4 light_col;
uniform vec4 ambient_col;

// light size is stored in point_light_pos[i].w 
uniform vec4 point_light_pos[MAX_POINT_LIGHTS];
uniform vec4 point_light_col[MAX_POINT_LIGHTS];

//uniform int point_light_shadow_map_index[MAX_POINT_LIGHTS];
uniform bool point_light_has_shadow_map[MAX_POINT_LIGHTS];
// these next two uniform's are only defined for static point lights, dynamic
// point lights do not have shadow maps
// these arrays are indexed by point_light_shadow_map_index[i], where i is the index for a point light
// if the point light at index i does not have shadow maps, point_light_shadow_map_index will be -1
//uniform samplerCubeShadow point_light_shadow_maps[MAX_POINT_LIGHTS];
uniform samplerCube point_light_shadow_maps[MAX_POINT_LIGHTS];
uniform int point_light_far_planes[MAX_POINT_LIGHTS];

uniform Image MainTex;
uniform sampler2DShadow dir_shadow_map; 
uniform sampler2DShadow dir_static_shadow_map;
uniform vec3 dir_light_dir;
uniform vec4 dir_light_col;

//uniform sampler2DShadow point_shadow_maps[MAX_POINT_LIGHTS];

uniform float draw_to_outline_buffer;
uniform vec4 outline_colour;

uniform bool u_draw_as_contour;
uniform vec4 u_contour_colour;

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

// diffuse lighting with a less pronounced clamping effect compared to diffuse_lighting, this is used for
// point lights
vec3 diffuse_lighting_2( vec3 normal, vec3 light_dir, vec4 light_col) {
	float diff = max(0.0, dot(normal, normalize(light_dir))) ;
	if (diff > 0.0) {
		float old_diff = diff;
		diff = 1.0 - pow( 1.0 - diff , 2 );
		diff = min(1.0, 1.1 * diff);
		diff = (old_diff + diff) * 0.5;
	}
	vec3 diff_col = light_col.rgb * light_col.a * diff;
	return diff_col;
}

vec3 specular_highlight( vec3 normal , vec3 light_dir, vec4 light_col ) {
	float specular_strength = 0.1;

	vec3 view_dir = normalize( view_pos - frag_w_position );
	vec3 light_dir_n = normalize( light_dir);
	vec3 halfway_v = normalize(light_dir_n + view_dir);

	float spec = pow(  max(dot(normal,halfway_v),  0.0), 16);

	return spec * specular_strength * light_col.rgb * light_col.a;
}

vec2 calc_tex_coords( vec2 uv_coords ) {
	/*if (!texture_animated) {
		return uv_coords + texoffset;
	} else {
		vec2 step = vec2(1.0,1.0) / float(texture_animated_dimx);

		vec2 texpos = vec2(mod(texture_animated_frame,texture_animated_dimx), texture_animated_frame / texture_animated_dimx);
		return mod(uv_coords + texoffset,vec2(1,1))*step + texpos*step;
	}*/
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

float shadow_calculation( vec4 pos , mat4 lightspace, sampler2DShadow shadow_map , vec3 normal , vec3 light_dir, float bias ) {
	vec4 prooj_coords = pos.xyzw;
	prooj_coords = vec4(prooj_coords.xyz * 0.5 + 0.5, prooj_coords.w);

	float cosTheta = clamp( dot( normal,light_dir ), 0,1 );

	float curr_depth    = prooj_coords.z;

	float angle = tan(acos(cosTheta));
	float radius = 2000.0; // the smaller, the larger the pcf radius
	//bias = clamp(bias, 0.00100,0.00230);
	bias = bias + (bias * min(angle,3.0))/10.0;

	float shadow = 1.0;

	// first we sample 4 distant points, if all 4 are either in shadow or in light its likely that any other points
	// we sample would also be in shadow or in light
	for (int i=0; i<4; i++) {
		float s = texture_shadow_clampone( shadow_map, vec3(prooj_coords.xy + distantPoints[i]/radius, (curr_depth/prooj_coords.w)-bias));
		shadow -= (1.0/12.0) * s;
	}

	// if all distant points are in shadow, then return 1.0 (fully in shadow)
	// otherwise 0.0 (fully in light)
	if (shadow == 1.0) {
		return 1.0;
	} else if (shadow <= 1.0 - 3.9 * (1/12.0)) {
		return 0.0;
	}

	for (int i=0; i<8; i++) {
		int index = int(16.0*random(floor(frag_w_position.xyz*100.0), i))%16;
		//int index = int(16.0*floor(frag_w_position.xyz*10.0*i))%16;
		//int index = i;
		shadow -= (1.0/12.0) * texture_shadow_clampone( shadow_map, vec3(prooj_coords.xy + poissonDisk[index]/radius, (curr_depth/prooj_coords.w)-bias));
	}

	return shadow;
}

vec3 calc_dir_light_col(vec4 frag_light_pos, vec4 static_frag_light_pos, mat4 lightspace, mat4 static_lightspace, sampler2DShadow map, sampler2DShadow static_map,
 vec3 normal, vec3 dir, vec4 col, float frag_dist) {
	
	vec3 light_dir_n = normalize(-dir);
	vec3 diffuse = diffuse_lighting( normal, light_dir_n, col);
	vec3 specular = specular_highlight( normal , light_dir_n, col);

	float shadow = 0.0;
	if (u_shadow_imult < 1.0) {
		const float transition_end = DIR_LIGHT_TRANSITION_DISTANCE;
		const float transition_start = DIR_LIGHT_TRANSITION_DISTANCE - 20;
		const float difference = transition_end - transition_start;

		float interp = clamp((frag_dist - transition_start)/difference,0.0,1.0);

		float close_shadow = 0.0;
		float static_shadow = 0.0;

		if (interp >= 0.0) {
			close_shadow = shadow_calculation(frag_light_pos, lightspace,
			  map, normal , light_dir_n, 0.0030);
		}
		if (interp <= 1.0) {
			static_shadow = shadow_calculation(static_frag_light_pos, static_lightspace,
			  static_map, normal, light_dir_n, 0.0015);
		}

		shadow = close_shadow * (1.0 - interp) + static_shadow * interp;
	}

	return (1.0 - shadow * (1.0-u_shadow_imult))*(diffuse + specular);
}

// same as calc_point_light_col_full but it takes in a pre-calculated attenuation
// as an argument
vec3 calc_point_light_col(int point_light_id, vec3 normal, float attenuate ) {

	vec3  light_pos  = point_light_pos[point_light_id].xyz;
	vec4  light_col  = point_light_col[point_light_id];

	vec3 dir = light_pos - frag_w_position;
	vec3 light_dir_n = normalize( dir );
	vec3 diffuse = diffuse_lighting( normal, light_dir_n, light_col );
	vec3 specular = specular_highlight( normal , light_dir_n, light_col );
	//vec3 specular = vec3(0.0);
	return (diffuse + specular) * attenuate;
}

float attenuate_light(float dist, float light_size) {
	float quad_comp   = 1.0/(light_size*light_size);
	float linear_comp = 150.0/light_size;
	float attenuate = 1.005/(1.0 + linear_comp*dist + quad_comp*dist*dist);
	return max(0.0, attenuate - 0.005);
}

vec3 calc_point_light_col_full(int point_light_id, vec3 normal ) {

	vec3  light_pos  = point_light_pos[point_light_id].xyz;
	float light_size = point_light_pos[point_light_id].w + 0.1; // ensure its never 0
	//float light_size = point_light_far_planes[point_light_id] + 0.1; // ensure its never 0
	vec4  light_col  = point_light_col[point_light_id];

	vec3 dir = light_pos - frag_w_position;
	// we add a tiny bias to ensure we never have a distance of 0
	float dist = length(dir) + 0.0001;

	float attenuate = attenuate_light(dist, light_size);

	vec3 light_dir_n = normalize( dir );
	vec3 diffuse = diffuse_lighting( normal, light_dir_n, light_col );
	vec3 specular = specular_highlight( normal , light_dir_n, light_col );
	//vec3 specular = vec3(0.0);
	return (diffuse + specular) * attenuate;
}

vec3 sample_offsets[20] = vec3[]
(
   vec3( 1,  1,  1), vec3( 1, -1,  1), vec3(-1, -1,  1), vec3(-1,  1,  1),
   vec3( 1,  1, -1), vec3( 1, -1, -1), vec3(-1, -1, -1), vec3(-1,  1, -1),
   vec3( 1,  1,  0), vec3( 1, -1,  0), vec3(-1, -1,  0), vec3(-1,  1,  0),
   vec3( 1,  0,  1), vec3(-1,  0,  1), vec3( 1,  0, -1), vec3(-1,  0, -1),
   vec3( 0,  1,  1), vec3( 0, -1,  1), vec3( 0, -1, -1), vec3( 0,  1, -1)
);

const vec3 poissonSphere[20] = vec3[](
   vec3( -0.94201624 , -0.39906216 , -0.094184101),
   vec3( 0.94558609  , -0.76890725 , -0.41893023),
   vec3( -0.094184101, -0.92938870 , 0.99706507),
   vec3( 0.34495938  , 0.29387760  , 0.14383161),
   vec3( -0.91588581 , 0.45771432  , 0.75648379),
   vec3( -0.81544232 , -0.87912464 , -0.38277543),
   vec3( -0.38277543 , 0.27676845  , -0.87912464 ),
   vec3( 0.97484398  , 0.75648379  , 0.53742981),
   vec3( 0.44323325  , -0.97511554 , 0.19090188 ),
   vec3( 0.53742981  , -0.47373420 ,-0.94201624),
   vec3( -0.26496911 , -0.41893023 , -0.094184101),
   vec3( 0.79197514  , 0.19090188  , 0.19984126),
   vec3( -0.24188840 , 0.99706507  , -0.76890725 ),
   vec3( -0.81409955 , 0.91437590  , -0.76890725 ),
   vec3( 0.19984126  , 0.78641367  , 0.45771432),
   vec3( 0.14383161  , -0.14100790 , -0.97511554 ),
   vec3( -0.81409955 , -0.76890725 , 0.91437590 ),
   vec3( -0.92938870 ,0.99706507   , -0.094184101),
   vec3( -0.094184101, -0.94201624 , -0.39906216),
   vec3( -0.97511554 , 0.19090188  , 0.44323325)
);

vec3 calc_point_light_col_shadow(int point_light_id, vec3 normal, const int point_shadow_id, float bias, samplerCube map) {
	float far_plane = point_light_far_planes[point_shadow_id];
	vec3 light_pos  = point_light_pos[point_light_id].xyz;
	float light_size = point_light_pos[point_light_id].w + 0.1; // ensure its never 0

	vec3 frag_to_light = (frag_w_position - light_pos);
	float curr_depth = length(frag_to_light);

	float attenuate = attenuate_light(curr_depth, light_size);
	if (attenuate < 0.005) { return vec3(0,0,0); }

	//float closest_depth = texture(map, frag_to_light).r;
	//closest_depth *= far_plane;

	//float adjusted_bias = bias * max( curr_depth / 60 , 1.0 );

	//float shadow = curr_depth - adjusted_bias > closest_depth ? 1.0 : 0.0;
	//float s = texture( map, vec4(frag_to_light, (curr_depth-bias)));
	//shadow -= s;

	float cosTheta = clamp( dot( normal, frag_to_light ), 0,1 );
	float bias_angled = clamp( abs(tan(acos(cosTheta))) , 0.25, 1);
	//float adjusted_bias = 0.0125*tan(acos(cosTheta));
	//float adjusted_bias = bias;

	//float adjusted_bias = bias * max( curr_depth / 500 , 1.0 ) * tan(acos(cosTheta));
	float adjusted_bias = bias * max( curr_depth / 1000 , 1.0 ) * bias_angled ;
	//float adjusted_bias = bias * max( curr_depth / 50 , 1.0 );

	const int samples = 7;
	float shadow = 1.0;
	float disk_radius = (1.0 + (curr_depth / far_plane)) * 1.0;
	for(int i = 0; i < samples; ++i) {
		//int index = int(20.0*random(floor(frag_w_position.xyz*10.0), i))%20;
		int index = i;
	    float closest_depth = texture(map, frag_to_light + poissonSphere[index] * disk_radius).r;
	    closest_depth *= far_plane;   // undo mapping [0;1]
		if(curr_depth - adjusted_bias < closest_depth)
        	shadow -= 1.0/float(samples);
	}

	vec3 light_result = calc_point_light_col( point_light_id , normal , attenuate );
	return (1.0 - shadow * (1.0-u_shadow_imult))*light_result;
}

// love_Canvases[0] is HDR color
// love_Canvases[1] is outline buffer
void effect( ) {
	// when drawing the model in contour line phase, we only need a solid
	// colour and can skip all the other fragment calculations
	if (u_draw_as_contour) {
		love_Canvases[0] = u_contour_colour;
		return;
	}

	float dist = (frag_position.z*frag_position.z) + (frag_position.x*frag_position.x) + (frag_position.y*frag_position.y);
	dist = sqrt(dist);

	float fog_r = (dist - fog_start) / (fog_end - fog_start);
	fog_r = clamp(fog_r, 0.0,1.0);

	vec3 light = ambient_lighting( ambient_col );
	vec3 dir_light_result = calc_dir_light_col(dir_frag_light_pos, dir_static_frag_light_pos, u_dir_lightspace, u_dir_static_lightspace,
		dir_shadow_map, dir_static_shadow_map,
		frag_normal, dir_light_dir, dir_light_col, dist);
	light += dir_light_result;

	//
	// EVIL SHIT - no cubemap arrays, no glsl 4.0+ variable indexing.
	//
	#define DO_POINT_LIGHT(i) if (u_point_light_count > i){if (point_light_has_shadow_map[i]) {light += calc_point_light_col_shadow(i, frag_normal, i, point_bias, point_light_shadow_maps[i]);} else {light += calc_point_light_col_full(i, frag_normal);}}
	float point_bias = 0.5;
	DO_POINT_LIGHT(0);
	DO_POINT_LIGHT(1);
	DO_POINT_LIGHT(2);
	DO_POINT_LIGHT(3);
	DO_POINT_LIGHT(4);
	DO_POINT_LIGHT(5);
	DO_POINT_LIGHT(6);
	DO_POINT_LIGHT(7);
	DO_POINT_LIGHT(8);

	vec2 coords = calc_tex_coords(vec2(VaryingTexCoord));

	vec4 texcolor;
	texcolor = Texel(MainTex, coords);

	vec4 pix = texcolor * vec4(light,1.0);

	// TODO make the fog colour work properly with HDR
	vec4 result = vec4((1-fog_r)*pix.rgb + fog_r*skybox_brightness*fog_colour, pix.a);

	love_Canvases[0] = result;
	//love_Canvases[1] = vec4(outline_colour) * draw_to_outline_buffer;
}

#endif
