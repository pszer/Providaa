#pragma language glsl3

#ifdef VERTEX
	vec4 position(mat4 transform, vec4 vertex) {
		return transform * vertex;
	}
#endif

#ifdef PIXEL

	uniform Image luminance;
	uniform int luminance_mipmap_count;
	uniform float dt;

	vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords ) {
		float avg_lum = texelFetch(luminance, ivec2(0,0), luminance_mipmap_count-1).r;
    	return vec4(avg_lum,avg_lum,avg_lum,dt);
	}
#endif
