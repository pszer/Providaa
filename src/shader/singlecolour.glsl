#pragma language glsl3

#ifdef PIXEL
	vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords ) {
    	return color;
	}
#endif
