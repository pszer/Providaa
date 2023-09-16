#pragma language glsl3

#ifdef VERTEX
	vec4 position(mat4 transform, vec4 vertex) {
		return transform * vertex;
	}
#endif

#ifdef PIXEL
	uniform bool hdr_enabled;
	uniform float exposure;
	uniform float exposure_min;
	uniform float exposure_max;

	uniform Image bloom_blur;
	uniform float bloom_strength = 0.06f;

	//uniform Image luminance;
	//uniform int luminance_mipmap_count;

	uniform Image gradual_luminance;

	vec3 bloom_mix(vec3 hdr_col, vec3 bloom_col) {
		return mix(hdr_col, bloom_col, bloom_strength);
	}

	vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords ) {
		//float avg_lum = texelFetch(luminance, ivec2(0,0), luminance_mipmap_count-1).r;
		float avg_lum = texture(gradual_luminance, ivec2(0,0)).r;

		float exposure_val = 1.0/(avg_lum)   + exposure/100000000.0;
		exposure_val = clamp(exposure_val, exposure_min, exposure_max);

		vec4 pix_color = Texel(tex, texture_coords);
		vec3 hdr_color = pix_color.rgb;
		vec3 bloom_color = Texel(bloom_blur, texture_coords).rgb;
		hdr_color = bloom_mix(hdr_color, bloom_color);

		//float hdr_flag  = pix_color.a;

		if (hdr_enabled) {
			vec3 result = vec3(1.0) - exp(-hdr_color * exposure_val);
			return vec4(result, pix_color.a);
		} else {
			return vec4(hdr_color, 1.0);
		}
	}
#endif
