#pragma language glsl3

#ifdef VERTEX
	vec4 position(mat4 transform, vec4 vertex) {
		return transform * vertex;
	}
#endif

#ifdef PIXEL
	vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords ) {
		vec4 result = Texel(tex, texture_coords);
		float brightness = dot(result.rgb, vec3(0.2126, 0.7152, 0.0722));
    	return vec4(brightness,brightness,brightness,1.0);
	}
#endif
