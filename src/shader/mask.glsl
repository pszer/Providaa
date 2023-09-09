#pragma language glsl3

// masking shader used for compositing animated eyes

#ifdef VERTEX
	vec4 position(mat4 transform, vec4 vertex) {
		return transform * vertex;
	}
#endif

#ifdef PIXEL
	uniform bool multiplicative_mask;

	uniform Image mask;

	uniform vec2 uv_translate;

	uniform bool flip_x;
	uniform bool flip_y;

	vec2 flip_uv(vec2 uv, bool flipx, bool flipy) {
		vec2 result = uv;
		if (flipx) {
			result.x = 1.0 - result.x; }
		if (flipy) {
			result.y = 1.0 - result.y; }
		return result;
	}

	vec2 flip_translate(vec2 uv_translate, bool flipx, bool flipy) {
		if (flipx) { uv_translate.x = -uv_translate.x; }
		if (flipy) { uv_translate.y = -uv_translate.y; }
		return uv_translate;
	}

	vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords ) {

		texture_coords = flip_uv(texture_coords, flip_x, flip_y);

		vec4 mask_pix = Texel(mask, texture_coords);
		vec4 tex_pix  = Texel(tex, texture_coords - flip_translate(uv_translate, flip_x, flip_y));

		if (multiplicative_mask) {
			return mask_pix * tex_pix;
		} else {
			float s = mask_pix.a == 0 ? 0 : 1;
			//return s * tex_pix + vec4(mask_coords.xy,0,1);
			return s * tex_pix;
			//return s * tex_pix;
		}
	}

#endif
