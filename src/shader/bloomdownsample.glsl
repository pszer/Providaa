
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

uniform sampler2DArray texs;
uniform int destination_layer;
uniform int source_layer;
uniform vec2 src_resolution;
uniform float src_x;
uniform float src_y;
uniform vec2 max_resolution;

uniform bool u_initial_blit;
uniform Image MainTex;

uniform int mode;
uniform float filter_radius;

void effect() {
	if (mode==0) {
		vec2 ratio = src_resolution / max_resolution;
		vec2 srcTexelSize = 1.0 / src_resolution;
		float x = srcTexelSize.x;
		float y = srcTexelSize.y;
		float x_off = src_x/max_resolution.x;

		// Take 13 samples around current texel:
		// a - b - c
		// - j - k -
		// d - e - f
		// - l - m -
		// g - h - i
		// === ('e' is the current texel) ===

		vec3 a,b,c,d,e,f,g,h,i,j,k,l,m,L;
		vec2 texture_coords = VaryingTexCoord.xy;
		if (u_initial_blit) {
			a = Texel(MainTex, vec2(texture_coords.x - 2*x, texture_coords.y + 2*y)).rgb;
			b = Texel(MainTex, vec2(texture_coords.x,       texture_coords.y + 2*y)).rgb;
			c = Texel(MainTex, vec2(texture_coords.x + 2*x, texture_coords.y + 2*y)).rgb;

			d = Texel(MainTex, vec2(texture_coords.x - 2*x, texture_coords.y)).rgb;
			e = Texel(MainTex, vec2(texture_coords.x,       texture_coords.y)).rgb;
			f = Texel(MainTex, vec2(texture_coords.x + 2*x, texture_coords.y)).rgb;

			g = Texel(MainTex, vec2(texture_coords.x - 2*x, texture_coords.y - 2*y)).rgb;
			h = Texel(MainTex, vec2(texture_coords.x,       texture_coords.y - 2*y)).rgb;
			i = Texel(MainTex, vec2(texture_coords.x + 2*x, texture_coords.y - 2*y)).rgb;

			j = Texel(MainTex, vec2(texture_coords.x - x, texture_coords.y + y)).rgb;
			k = Texel(MainTex, vec2(texture_coords.x + x, texture_coords.y + y)).rgb;
			l = Texel(MainTex, vec2(texture_coords.x - x, texture_coords.y - y)).rgb;
			m = Texel(MainTex, vec2(texture_coords.x + x, texture_coords.y - y)).rgb;

			L = Texel(MainTex, vec2(texture_coords.x, texture_coords.y)).rgb;
		} else {
			int layer = source_layer;
			vec3 mul = vec3(ratio,1.0);
			vec3 off = vec3(x_off,0,0);
			a = Texel(texs, off+mul*vec3(texture_coords.x - 2*x, texture_coords.y + 2*y,layer)).rgb;
			b = Texel(texs, off+mul*vec3(texture_coords.x,       texture_coords.y + 2*y,layer)).rgb;
			c = Texel(texs, off+mul*vec3(texture_coords.x + 2*x, texture_coords.y + 2*y,layer)).rgb;

			d = Texel(texs, off+mul*vec3(texture_coords.x - 2*x, texture_coords.y,layer)).rgb;
			e = Texel(texs, off+mul*vec3(texture_coords.x,       texture_coords.y,layer)).rgb;
			f = Texel(texs, off+mul*vec3(texture_coords.x + 2*x, texture_coords.y,layer)).rgb;

			g = Texel(texs, off+mul*vec3(texture_coords.x - 2*x, texture_coords.y - 2*y,layer)).rgb;
			h = Texel(texs, off+mul*vec3(texture_coords.x,       texture_coords.y - 2*y,layer)).rgb;
			i = Texel(texs, off+mul*vec3(texture_coords.x + 2*x, texture_coords.y - 2*y,layer)).rgb;

			j = Texel(texs, off+mul*vec3(texture_coords.x - x, texture_coords.y + y,layer)).rgb;
			k = Texel(texs, off+mul*vec3(texture_coords.x + x, texture_coords.y + y,layer)).rgb;
			l = Texel(texs, off+mul*vec3(texture_coords.x - x, texture_coords.y - y,layer)).rgb;
			m = Texel(texs, off+mul*vec3(texture_coords.x + x, texture_coords.y - y,layer)).rgb;

			L = Texel(texs, off+mul*vec3(texture_coords.x, texture_coords.y,layer)).rgb;
		}

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

		for (int i=0;i<2;++i) {
			if (i==destination_layer) {
				love_Canvases[i]=vec4(downsample,1.0);
			} else {
				love_Canvases[i]=vec4(0.0);
			}
		}
		love_Canvases[2]=vec4(L,1.0);
	} else {
		vec2 ratio = src_resolution / max_resolution;
		// The filter kernel is applied with a radius, specified in texture
		// coordinates, so that the radius will vary across mip resolutions.
		float x = filter_radius;
		float y = filter_radius;
		float x_off = src_x/max_resolution.x;
		float y_off = src_y/max_resolution.y;

		// Take 9 samples around current texel:
		// a - b - c
		// d - e - f
		// g - h - i
		// === ('e' is the current texel) ===
		int src_layer = (destination_layer+1)%2;
		vec2 texture_coords = VaryingTexCoord.xy;
		vec3 mul = vec3(ratio,1.0);
		vec3 off = vec3(x_off,y_off,0);
		vec3 a = Texel(texs, off+mul*vec3(texture_coords.x - x, texture_coords.y + y, src_layer)).rgb;
		vec3 b = Texel(texs, off+mul*vec3(texture_coords.x,     texture_coords.y + y, src_layer)).rgb;
		vec3 c = Texel(texs, off+mul*vec3(texture_coords.x + x, texture_coords.y + y, src_layer)).rgb;

		vec3 d = Texel(texs, off+mul*vec3(texture_coords.x - x, texture_coords.y, src_layer)).rgb;
		vec3 e = Texel(texs, off+mul*vec3(texture_coords.x,     texture_coords.y, src_layer)).rgb;
		vec3 f = Texel(texs, off+mul*vec3(texture_coords.x + x, texture_coords.y, src_layer)).rgb;

		vec3 g = Texel(texs, off+mul*vec3(texture_coords.x - x, texture_coords.y - y, src_layer)).rgb;
		vec3 h = Texel(texs, off+mul*vec3(texture_coords.x,     texture_coords.y - y, src_layer)).rgb;
		vec3 i = Texel(texs, off+mul*vec3(texture_coords.x + x, texture_coords.y - y, src_layer)).rgb;

			// Apply weighted distribution, by using a 3x3 tent filter:
		//  1   | 1 2 1 |
		// -- * | 2 4 2 |
		// 16   | 1 2 1 |
		vec3 upsample = e*4.0;
		upsample += (b+d+f+h)*2.0;
		upsample += (a+c+g+i);
		upsample *= 1.0 / 16.0;

		for (int i=0;i<2;++i) {
			if (i==destination_layer) {
				love_Canvases[i]=vec4(upsample,1.0);
			} else {
				love_Canvases[i]=vec4(0.0);
			}
		}
		love_Canvases[2]=vec4(0.0);
	}
}

#endif
