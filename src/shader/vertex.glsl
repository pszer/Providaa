extern mat4 u_proj;
extern mat4 u_view;
extern mat4 u_rot;
//extern mat4 u_model;
//
extern float curve_coeff;
extern bool curve_flag;

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

varying vec4 vposition;
varying vec3 vnormal;
varying vec2 texscale;
varying vec2 texoffset;

#ifdef VERTEX

attribute vec3 VertexNormal;
attribute vec2 TextureScale;
attribute vec2  TextureOffset;

vec4 position(mat4 transform, vec4 vertex) {
	vec4 view_v = u_view * vertex;

	if (curve_flag) {
		view_v.y = view_v.y + (view_v.z*view_v.z) / curve_coeff;
	}

	vnormal = VertexNormal;
	texscale = TextureScale;
	if (texscale.x == 0) { texscale.x = 1; }
	if (texscale.y == 0) { texscale.y = 1; }
	texoffset = TextureOffset;

	vec4 pos_v = u_proj * u_rot * view_v;
	vposition = pos_v;
	return pos_v;
}
#endif

#ifdef PIXEL

vec3 ambient_lighting( vec3 normal, vec3 light_dir, vec3 light_col, vec3 ambient_col, float ambient_str ) {
	float diff = max(0.0, dot(normal, -normalize(light_dir)));
	vec3 diff_col = light_col * diff;
	return diff_col + ambient_col*ambient_str;
}

vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords ) {
	float dist = vposition.z*vposition.z + vposition.x*vposition.x;
	dist = sqrt(dist);

	float fog_r = (dist - fog_start) / (fog_end - fog_start);
	fog_r = clamp(fog_r, 0.0,1.0);

	vec3 light_result = ambient_lighting(vnormal, light_dir, light_col, ambient_col, ambient_str);
	vec4 light = vec4(light_result,1.0);

	vec4 texcolor;
	vec2 coords;
	if (!texture_animated) {
		coords = texture_coords + texoffset;
	} else {
		vec2 step = vec2(1.0,1.0) / float(texture_animated_dimx);
		//int frame = mod(texture_animated_frame + floor(AnimationOffset), texture_animated_framecount)

		vec2 texpos = vec2(mod(texture_animated_frame,texture_animated_dimx), texture_animated_frame / texture_animated_dimx);
		coords = mod(texture_coords + texoffset,vec2(1,1))*step + texpos*step;
	}

	coords = coords / texscale;

	texcolor = Texel(tex, coords);
	vec4 pix = texcolor * light;

	return (1-fog_r)*pix + fog_r*fog_colour;
}
#endif
