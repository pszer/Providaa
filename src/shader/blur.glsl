#pragma language glsl3

#ifdef VERTEX
	vec4 position(mat4 transform, vec4 vertex) {
		return transform * vertex;
	}
#endif

#ifdef PIXEL
	uniform bool horizontal_flag;
	uniform float weight[5] = float[] (0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);

	vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords ) {
		vec2 tex_offset = 1.0 / textureSize(tex, 0); // gets size of single texel
	    vec3 result = texture(tex, texture_coords).rgb * weight[0]; // current fragment's contribution
	    if(horizontal_flag)
	    {
    	    for(int i = 1; i < 5; ++i)
    	    {
    	        result += Texel(tex, texture_coords + vec2(tex_offset.x * i, 0.0)).rgb * weight[i];
    	        result += Texel(tex, texture_coords - vec2(tex_offset.x * i, 0.0)).rgb * weight[i];
    	    }
    	}
    	else
    	{
			for(int i = 1; i < 5; ++i)
        	{
        	    result += Texel(tex, texture_coords + vec2(0.0, tex_offset.y * i)).rgb * weight[i];
        	    result += Texel(tex, texture_coords - vec2(0.0, tex_offset.y * i)).rgb * weight[i];
        	}
    	}

    	return vec4(result, 1.0);
	}
#endif
