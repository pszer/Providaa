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

varying vec4 vposition;

#ifdef VERTEX
vec4 position(mat4 transform, vec4 vertex) {
	vec4 view_v = u_view * vertex;

	if (curve_flag) {
		view_v.y = view_v.y + (view_v.z*view_v.z) / curve_coeff;
	}

	vec4 pos_v = u_proj * u_rot * view_v;
	vposition = pos_v;
	return pos_v;
}
#endif

#ifdef PIXEL
vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
{
	float dist = vposition.z*vposition.z + vposition.x*vposition.x;
	dist = sqrt(dist);

	float fog_r = (dist - fog_start) / (fog_end - fog_start);
	fog_r = clamp(fog_r, 0.0,1.0);

	if (!texture_animated) {
	    vec4 texcolor = Texel(tex, texture_coords);
		//vec4 pix = texcolor * color;
		vec4 pix = texcolor ;
		return (1-fog_r)*pix + fog_r*fog_colour;
	} else {
		vec2 step = vec2(1.0,1.0) / float(texture_animated_dimx);
		vec2 texpos = vec2(mod(texture_animated_frame,texture_animated_dimx), texture_animated_frame / texture_animated_dimx);

		vec2 coords = texture_coords*step + texpos*step;

	    vec4 texcolor = Texel(tex, coords);
		//vec4 pix = texcolor * color;
		vec4 pix = texcolor ;
		return (1-fog_r)*pix + fog_r*fog_colour;
	}
}
#endif
