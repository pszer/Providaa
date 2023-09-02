#pragma language glsl3

#ifdef VERTEX
	vec4 position(mat4 transform, vec4 vertex) {
		return transform * vertex;
	}
#endif

#ifdef PIXEL
	uniform bool hdr_enabled;
	uniform float exposure;

	vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords ) {
		vec4 pix_color = Texel(tex, texture_coords);
		vec3 hdr_color = pix_color.rgb;
		float hdr_flag  = pix_color.a;

		if (hdr_enabled) {
			vec3 result = vec3(1.0) - exp(-hdr_color * exposure);
			return vec4(result, pix_color.a);
		} else {
			return vec4(hdr_color, 1.0);
		}
	}
#endif
