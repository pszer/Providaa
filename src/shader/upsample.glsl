#pragma language glsl3

#ifdef VERTEX
	vec4 position(mat4 transform, vec4 vertex) {
		return transform * vertex;
	}
#endif

#ifdef PIXEL

// This shader performs upsampling on a texture,
// as taken from Call Of Duty method, presented at ACM Siggraph 2014.

//Remember to add bilinear minification filter for this texture!
// Remember to use a floating-point texture format (for HDR)!
// Remember to use edge clamping for this texture!
uniform float filter_radius;

vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords ) {
    // The filter kernel is applied with a radius, specified in texture
    // coordinates, so that the radius will vary across mip resolutions.
    float x = filter_radius;
    float y = filter_radius;

    // Take 9 samples around current texel:
    // a - b - c
    // d - e - f
    // g - h - i
    // === ('e' is the current texel) ===
    vec3 a = Texel(tex, vec2(texture_coords.x - x, texture_coords.y + y)).rgb;
    vec3 b = Texel(tex, vec2(texture_coords.x,     texture_coords.y + y)).rgb;
    vec3 c = Texel(tex, vec2(texture_coords.x + x, texture_coords.y + y)).rgb;

    vec3 d = Texel(tex, vec2(texture_coords.x - x, texture_coords.y)).rgb;
    vec3 e = Texel(tex, vec2(texture_coords.x,     texture_coords.y)).rgb;
    vec3 f = Texel(tex, vec2(texture_coords.x + x, texture_coords.y)).rgb;

    vec3 g = Texel(tex, vec2(texture_coords.x - x, texture_coords.y - y)).rgb;
    vec3 h = Texel(tex, vec2(texture_coords.x,     texture_coords.y - y)).rgb;
    vec3 i = Texel(tex, vec2(texture_coords.x + x, texture_coords.y - y)).rgb;

	    // Apply weighted distribution, by using a 3x3 tent filter:
    //  1   | 1 2 1 |
    // -- * | 2 4 2 |
    // 16   | 1 2 1 |
    vec3 upsample = e*4.0;
    upsample += (b+d+f+h)*2.0;
    upsample += (a+c+g+i);
    upsample *= 1.0 / 16.0;

	return vec4(upsample, 1.0);
}

#endif
