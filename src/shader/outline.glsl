#pragma language glsl3

#ifdef VERTEX
	vec4 position(mat4 transform, vec4 vertex) {
		return transform * vertex;
	}
#endif

#ifdef PIXEL
	const int MAX_OUTLINE_SIZE = 8;

	uniform int   outline_size;
	uniform float kernel[(MAX_OUTLINE_SIZE*2+1)*(MAX_OUTLINE_SIZE*2+1)];
	//const float kernel[MAX_OUTLINE_SIZE*MAX_OUTLINE_SIZE] = float[] (0.0,  1, 0.0,
	//                                   1 , 1,  1  ,
	//								 0.0,  1, 0.0);

	vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords ) {
		vec2 tex_offset = 1.0 / textureSize(tex, 0); // gets size of single texel
		vec4 result = vec4(0.0);
		int i = 0;
		for (int x = -outline_size; x <= outline_size; ++x) {
			for (int y = -outline_size; y <= outline_size; ++y) {
				float kernel_val = kernel[i];

				if (kernel_val > 0) {
					vec4 pix = Texel(tex, texture_coords + vec2(tex_offset.x * x, tex_offset.y * y));
					if (pix != vec4(0.0)) {
						return pix;
					}
				}
				i = i+1;
			}
		}

    	return vec4(0,0,0,0);
	}
#endif
