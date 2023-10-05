#pragma language glsl3

#ifdef VERTEX
	vec4 position(mat4 transform, vec4 vertex) {
		return transform * vertex;
	}
#endif

#ifdef PIXEL
	uniform float exposure_min;
	uniform float exposure_max;
	uniform float exposure_nudge;

	//uniform Image bloom_blur;
	uniform sampler2DArray bloom_blur;
	uniform int bloom_layer;
	uniform vec4 bloom_viewport;
	uniform float bloom_strength = 0.07f;	

	//uniform float gamma;

	//uniform Image luminance;
	//uniform int luminance_mipmap_count;

	uniform Image gradual_luminance;

	vec3 bloom_mix(vec3 hdr_col, vec3 bloom_col) {
		return mix(hdr_col, bloom_col, bloom_strength);
	}

	vec3 RGBtoXYZ(vec3 rgb) {
    	mat3 RGBtoXYZMatrix = mat3(
		 0.4124564, 0.3575761, 0.1804375,
       	 0.2126729, 0.7151522, 0.0721750,
       	 0.0193339, 0.1191920, 0.9503041);
		 return RGBtoXYZMatrix * rgb;
	}

	vec3 RGBtoLab(vec3 rgb) {
		vec3 xyz = RGBtoXYZ(rgb);

    	// Normalize to D65 white point
		xyz /= vec3(0.950456, 1.0, 1.088754);
		vec3 fxyz = xyz;
		fxyz = mix(pow(fxyz, vec3(1.0/3.0)), (fxyz * 903.3 + vec3(16.0/116.0)), step(fxyz, vec3(0.008856)));

		return vec3(
			116.0 * fxyz.y - 16.0,
			500.0 * (fxyz.x - fxyz.y),
			200.0 * (fxyz.y - fxyz.z)
		);
	}

	vec3 XYZtoLab(vec3 xyz) {
    	// Normalize to D65 white point
		xyz /= vec3(0.950456, 1.0, 1.088754);
		vec3 fxyz = xyz;
		fxyz = mix(pow(fxyz, vec3(1.0/3.0)), (fxyz * 903.3 + vec3(16.0/116.0)), step(fxyz, vec3(0.008856)));

		return vec3(
			116.0 * fxyz.y - 16.0,
			500.0 * (fxyz.x - fxyz.y),
			200.0 * (fxyz.y - fxyz.z)
		);
	}

	vec3 LabtoXYZ(vec3 lab) {
		float y = (lab.x + 16.0) / 116.0;
		float x = (lab.y / 500.0) + y;
		float z = y - (lab.z / 200.0);

		float y3 = y * y * y;
		float x3 = x * x * x;
		float z3 = z * z * z;

		if (y3 > 0.008856) y = y3;
		else y = (y - 16.0/116.0) / 7.787;

		if (x3 > 0.008856) x = x3;
		else x = (x - 16.0/116.0) / 7.787;

		if (z3 > 0.008856) z = z3;
		else z = (z - 16.0/116.0) / 7.787;

		return vec3(
			x * 0.950456,
			y,
			z * 1.088754
		);
	}

	vec3 LabtoRGB(vec3 lab) {
		vec3 xyz = LabtoXYZ(lab);

		mat3 XYZtoRGBMatrix = mat3(
			3.2404542, -1.5371385, -0.4985314,
		   -0.9692660,  1.8760108,  0.0415560,
			0.0556434, -0.2040259,  1.0572252
		);

		return XYZtoRGBMatrix * xyz;
	}

	vec3 XYZtoRGB(vec3 xyz) {
		mat3 XYZtoRGBMatrix = mat3(
			3.2404542, -1.5371385, -0.4985314,
		   -0.9692660,  1.8760108,  0.0415560,
			0.0556434, -0.2040259,  1.0572252
		);

		return XYZtoRGBMatrix * xyz;
	}

	// Function to convert XYZ to xyY
	vec3 XYZtoxyY(vec3 xyz) {
		float sum = xyz.x + xyz.y + xyz.z;

		if (sum > 0.0) {
			float x = xyz.x / sum;
			float y = xyz.y / sum;
			float Y = xyz.y;
			return vec3(x, y, Y);
		} else {
			return vec3(0.0, 0.0, xyz.y);
		}
	}
	// Function to convert xyY to XYZ
	vec3 xyYtoXYZ(vec3 xyY) {
		float Y = xyY.z;
		float x = xyY.x;
		float y = xyY.y;

		if (y > 0.0) {
			float X = (x * Y) / y;
			float Z = ((1.0 - x - y) * Y) / y;
			return vec3(X, Y, Z);
		} else {
			return vec3(0.0, Y, 0.0);
		}
	}

	float LABgetChroma(vec3 Lab) {
		return sqrt(Lab.y*Lab.y + Lab.z*Lab.z);
	}

	vec3 AdjustSaturation_xyY(vec3 xyY, float adjust, float mask) {
		mask = clamp(mask,0,1);
		vec3 adjusted = vec3(xyY.xy*adjust, xyY.z);
		return  mask*adjusted + (1.0-mask)*xyY;
	}

	float getChroma_xyY(vec3 xyY) {
    	return sqrt(xyY.x * xyY.x + xyY.y * xyY.y);
	}

	vec3 adjustSaturation_xyY(vec3 xyY, float saturation) {
    // Ensure saturation is within the valid range [-1.0, 1.0]
    saturation = clamp(saturation, -1.0, 1.0);

    float x = xyY.x;
    float y = xyY.y;
    float Y = xyY.z;

    // Calculate the chroma (C) of the original xyY color
    float C = sqrt(x * x + y * y);

    // Calculate the new chromaticity coordinates while maintaining Y
    float newX = x + (x / C) * saturation;
    float newY = y + (y / C) * saturation;

    // Ensure the new chromaticity coordinates are within [0.0, 1.0]
    newX = clamp(newX, 0.0, 1.0);
    newY = clamp(newY, 0.0, 1.0);

    // Return the adjusted xyY color with the original luminance
    return vec3(newX, newY, Y);
}

	#define M_PI 3.1415926535897932384626433832795
	float LabHue(vec3 lab) {
		return 180.0 * atan( lab.z , lab.y ) / M_PI;
	}

	vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords ) {
		//float avg_lum = texelFetch(luminance, ivec2(0,0), luminance_mipmap_count-1).r;
		float avg_lum = texture(gradual_luminance, ivec2(0,0)).r;

		float exposure_val = exposure_nudge/(avg_lum);
		exposure_val = clamp(exposure_val, exposure_min, exposure_max);

		vec4 pix_color = Texel(tex, texture_coords);
		vec3 hdr_color = pix_color.rgb;

		vec2 bloom_v_offset = bloom_viewport.xy;
		vec2 bloom_v_size   = bloom_viewport.zw;
		vec3 bloom_color = Texel(bloom_blur, vec3(bloom_v_offset + texture_coords*bloom_v_size, bloom_layer)).rgb;
		hdr_color = bloom_mix(hdr_color, bloom_color);

		//vec3 result = vec3(1.0) - exp(-hdr_color * exposure_val);
		//vec3 result = hdr_color;

		vec3 Lab = RGBtoLab(hdr_color);
		float chroma = (LABgetChroma(Lab)/300.0);
		chroma = clamp(chroma, 0.0, 1.0);
		//float chroma = (LABgetChroma(Lab)/200.0);
		//float chroma = (getChroma_xyY(xyY) - 0.3)* (1/0.7);
		//float hue    = LabHue(Lab);

		//Lab.y *= 0.95;
		//Lab.z *= 0.95;
		Lab.y = (Lab.y*1.15) * chroma + Lab.y*( 1.0 - chroma );
		Lab.z = (Lab.z*1.15) * chroma + Lab.z*( 1.0 - chroma );
		hdr_color = LabtoRGB(Lab);

		vec3 result = vec3(1.0) - exp(-hdr_color * exposure_val);
		return vec4(result, 1.0);
	}
#endif
