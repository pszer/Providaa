#pragma language glsl3

// shader used to composite faces

#ifdef VERTEX
	vec4 position(mat4 transform, vec4 vertex) {
		return transform * vertex;
	}
#endif

#ifdef PIXEL
	uniform bool multiplicative_mask;

	uniform Image leye_sclera_mask;
	uniform Image leye_base_img;
	uniform Image leye_iris_img;
	uniform Image leye_highlight_img;
	uniform vec2 leye_uv_translate;
	uniform vec4 leye_pos;

	uniform Image reye_sclera_mask;
	uniform Image reye_base_img;
	uniform Image reye_iris_img;
	uniform Image reye_highlight_img;
	uniform vec2 reye_uv_translate;
	uniform vec4 reye_pos;

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

	#define transform_uv_to_rect(uv, rect) ((uv.xy - rect.xy) / rect.zw)

	vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords ) {
		//vec4 tex_pix  = Texel(tex, texture_coords);

		vec4 tex_pix = vec4(0.0);

		vec2 leye_coord = transform_uv_to_rect(texture_coords, leye_pos);
		if (leye_coord.x>=0.0 && leye_coord.x<=1.0 && leye_coord.y>=0.0 && leye_coord.y<=1.0) {
			vec2 flipped_uv = flip_uv(leye_coord, true, false);

			vec2 translate = leye_uv_translate;
			translate.x = -translate.x;
			vec4 mask_pix = Texel(leye_sclera_mask, flipped_uv);
			vec4 iris_pix = Texel(leye_iris_img, flipped_uv - translate) * mask_pix;

			if (iris_pix != vec4(0.0)) {
				vec4 highlight_pix = Texel(leye_highlight_img, leye_coord);
				if (highlight_pix != vec4(0.0)) { return highlight_pix; }
				return iris_pix;
			}

			tex_pix = Texel( leye_base_img , flipped_uv );
			return tex_pix;
		}

		vec2 reye_coord = transform_uv_to_rect(texture_coords, reye_pos);
		if (reye_coord.x>=0.0 && reye_coord.x<=1.0 && reye_coord.y>=0.0 && reye_coord.y<=1.0) {
			vec4 mask_pix = Texel(reye_sclera_mask, reye_coord);
			vec4 iris_pix = Texel(reye_iris_img, reye_coord - reye_uv_translate) * mask_pix;

			if (iris_pix != vec4(0.0)) {
				vec4 highlight_pix = Texel(reye_highlight_img, reye_coord);
				if (highlight_pix != vec4(0.0)) { return highlight_pix; }
				return iris_pix;
			}

			tex_pix = Texel( reye_base_img , reye_coord );
			return tex_pix;
		}

		return tex_pix;
	}

#endif
