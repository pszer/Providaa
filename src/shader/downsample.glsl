#pragma language glsl3

#ifdef VERTEX
	vec4 position(mat4 transform, vec4 vertex) {
		return transform * vertex;
	}
#endif

// This shader performs downsampling on a texture,
// as taken from Call Of Duty method, presented at ACM Siggraph 2014.
// This particular method was customly designed to eliminate
// "pulsating artifacts and temporal stability issues".

// Remember to add bilinear minification filter for this texture!
// Remember to use a floating-point texture format (for HDR)!
// Remember to use edge clamping for this texture!

#ifdef PIXEL

uniform vec2 src_resolution;

vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords ) {
    vec2 srcTexelSize = 1.0 / src_resolution;
    float x = srcTexelSize.x;
    float y = srcTexelSize.y;

    // Take 13 samples around current texel:
    // a - b - c
    // - j - k -
    // d - e - f
    // - l - m -
    // g - h - i
    // === ('e' is the current texel) ===
    vec3 a = Texel(tex, vec2(texture_coords.x - 2*x, texture_coords.y + 2*y)).rgb;
    vec3 b = Texel(tex, vec2(texture_coords.x,       texture_coords.y + 2*y)).rgb;
    vec3 c = Texel(tex, vec2(texture_coords.x + 2*x, texture_coords.y + 2*y)).rgb;

    vec3 d = Texel(tex, vec2(texture_coords.x - 2*x, texture_coords.y)).rgb;
    vec3 e = Texel(tex, vec2(texture_coords.x,       texture_coords.y)).rgb;
    vec3 f = Texel(tex, vec2(texture_coords.x + 2*x, texture_coords.y)).rgb;

    vec3 g = Texel(tex, vec2(texture_coords.x - 2*x, texture_coords.y - 2*y)).rgb;
    vec3 h = Texel(tex, vec2(texture_coords.x,       texture_coords.y - 2*y)).rgb;
    vec3 i = Texel(tex, vec2(texture_coords.x + 2*x, texture_coords.y - 2*y)).rgb;

    vec3 j = Texel(tex, vec2(texture_coords.x - x, texture_coords.y + y)).rgb;
    vec3 k = Texel(tex, vec2(texture_coords.x + x, texture_coords.y + y)).rgb;
    vec3 l = Texel(tex, vec2(texture_coords.x - x, texture_coords.y - y)).rgb;
    vec3 m = Texel(tex, vec2(texture_coords.x + x, texture_coords.y - y)).rgb;

    // Apply weighted distribution:
    // 0.5 + 0.125 + 0.125 + 0.125 + 0.125 = 1
    // a,b,d,e * 0.125
    // b,c,e,f * 0.125
    // d,e,g,h * 0.125
    // e,f,h,i * 0.125
    // j,k,l,m * 0.5
    // This shows 5 square areas that are being sampled. But some of them overlap,
    // so to have an energy preserving downsample we need to make some adjustments.
    // The weights are the distributed, so that the sum of j,k,l,m (e.g.)
    // contribute 0.5 to the final color output. The code below is written
    // to effectively yield this sum. We get:
    // 0.125*5 + 0.03125*4 + 0.0625*4 = 1
    vec3 downsample = e*0.125;
    downsample += (a+c+g+i)*0.03125;
    downsample += (b+d+f+h)*0.0625;
    downsample += (j+k+l+m)*0.125;
	downsample = max(downsample, vec3(0.0001)); // we dont want pure 0,0,0 black when upsampling!

	return vec4(downsample, 1.0);
}

#endif
