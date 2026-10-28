package webfs;

import haxe.io.Bytes;
import haxe.io.BytesInput;

/** A decoded image: `argb` holds 4 bytes per pixel in the order A, R, G, B (not premultiplied), row by row. */
typedef DecodedImage =
{
	var width:Int;
	var height:Int;
	var argb:Bytes;
}

/**
 * Complete PNG decoder written in plain Haxe (no OpenFL, so it can be tested on its own).
 *
 * Browsers can only decode images asynchronously, but Psych Engine asks for its images synchronously,
 * so mod PNGs are decoded by hand. Unlike the `format` library this handles every kind of PNG:
 *  - all colour types: greyscale, RGB, palette, greyscale + alpha, RGBA
 *  - all bit depths: 1, 2, 4, 8 and 16 (16 bit samples are reduced to 8 bit)
 *  - Adam7 interlacing
 *  - transparency from tRNS chunks (palette alpha, and the "transparent colour" of greyscale / RGB images)
 *  - every scanline filter
 */
class PngDecoder
{
	static final SIGNATURE:Array<Int> = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

	// Adam7: x start, y start, x step, y step of each of the 7 passes
	static final PASSES:Array<Array<Int>> = [
		[0, 0, 8, 8], [4, 0, 8, 8], [0, 4, 4, 8], [2, 0, 4, 4], [0, 2, 2, 4], [1, 0, 2, 2], [0, 1, 1, 2]
	];

	public static function isPng(bytes:Bytes):Bool
	{
		if (bytes == null || bytes.length < 8) return false;
		for (i in 0...8)
			if (bytes.get(i) != SIGNATURE[i]) return false;
		return true;
	}

	public static function decode(bytes:Bytes):DecodedImage
	{
		if (!isPng(bytes)) throw "not a PNG file";

		// ---- chunks ----
		var width = 0, height = 0, depth = 0, colorType = 0, interlace = 0;
		var palette:Bytes = null;
		var trns:Bytes = null;
		var idat = new haxe.io.BytesBuffer();
		var haveHeader = false;
		var haveData = false;

		var pos = 8;
		while (pos + 8 <= bytes.length)
		{
			var length = bytes.getInt32(pos); // big endian below
			length = (bytes.get(pos) << 24) | (bytes.get(pos + 1) << 16) | (bytes.get(pos + 2) << 8) | bytes.get(pos + 3);
			var type = bytes.getString(pos + 4, 4);
			var dataPos = pos + 8;
			if (length < 0 || dataPos + length > bytes.length) throw "truncated PNG";

			switch (type)
			{
				case "IHDR":
					width = be32(bytes, dataPos);
					height = be32(bytes, dataPos + 4);
					depth = bytes.get(dataPos + 8);
					colorType = bytes.get(dataPos + 9);
					if (bytes.get(dataPos + 10) != 0) throw "unknown PNG compression method";
					if (bytes.get(dataPos + 11) != 0) throw "unknown PNG filter method";
					interlace = bytes.get(dataPos + 12);
					haveHeader = true;
				case "PLTE":
					palette = bytes.sub(dataPos, length);
				case "tRNS":
					trns = bytes.sub(dataPos, length);
				case "IDAT":
					idat.addBytes(bytes, dataPos, length);
					haveData = true;
				case "IEND":
					pos = bytes.length; // stop
				default:
			}
			pos = dataPos + length + 4; // + CRC (not checked: a damaged file would fail to inflate anyway)
		}

		if (!haveHeader) throw "PNG header (IHDR) not found";
		if (!haveData) throw "PNG image data (IDAT) not found";
		if (width <= 0 || height <= 0) throw "invalid PNG size";
		if (width * height > 100000000) throw "PNG is too big";

		var channels = switch (colorType)
		{
			case 0: 1;
			case 2: 3;
			case 3: 1;
			case 4: 2;
			case 6: 4;
			default: throw "unknown PNG colour type " + colorType;
		};
		if (!validDepth(colorType, depth)) throw 'invalid PNG bit depth $depth for colour type $colorType';
		if (colorType == 3 && palette == null) throw "PNG palette is missing";

		var bitsPerPixel = channels * depth;
		var filterStep = bitsPerPixel < 8 ? 1 : (bitsPerPixel >> 3); // bytes between a byte and the one "to its left"

		// ---- inflate ----
		var passes = interlace == 1 ? PASSES : [[0, 0, 1, 1]];
		var expected = 0;
		for (p in passes)
		{
			var pw = Std.int((width - p[0] + p[2] - 1) / p[2]);
			var ph = Std.int((height - p[1] + p[3] - 1) / p[3]);
			if (pw > 0 && ph > 0) expected += ph * (1 + ((pw * bitsPerPixel + 7) >> 3));
		}
		var raw = inflate(idat.getBytes(), expected);

		// ---- unfilter + convert, pass by pass ----
		var out = Bytes.alloc(width * height * 4);
		var offset = 0;
		var ctx = new Converter(colorType, depth, palette, trns);

		for (p in passes)
		{
			var pw = Std.int((width - p[0] + p[2] - 1) / p[2]);
			var ph = Std.int((height - p[1] + p[3] - 1) / p[3]);
			if (pw <= 0 || ph <= 0) continue;

			var stride = (pw * bitsPerPixel + 7) >> 3;
			unfilter(raw, offset, stride, ph, filterStep);

			for (y in 0...ph)
			{
				var line = offset + y * (stride + 1) + 1;
				var oy = p[1] + y * p[3];
				ctx.convertLine(raw, line, pw, out, (oy * width + p[0]) * 4, p[2] * 4);
			}
			offset += ph * (stride + 1);
		}

		return {width: width, height: height, argb: out};
	}

	static inline function be32(b:Bytes, pos:Int):Int
		return (b.get(pos) << 24) | (b.get(pos + 1) << 16) | (b.get(pos + 2) << 8) | b.get(pos + 3);

	static function validDepth(colorType:Int, depth:Int):Bool
	{
		return switch (colorType)
		{
			case 0: depth == 1 || depth == 2 || depth == 4 || depth == 8 || depth == 16;
			case 3: depth == 1 || depth == 2 || depth == 4 || depth == 8;
			default: depth == 8 || depth == 16;
		};
	}

	// ------------------------------------------------------------------------------------------
	// zlib
	// ------------------------------------------------------------------------------------------

	static function inflate(data:Bytes, expected:Int):Bytes
	{
		#if js
		// pako is bundled with Lime's html5 output in some setups, it is a lot faster than the Haxe implementation
		var pako:Dynamic = js.Syntax.code("(typeof pako !== 'undefined' ? pako : null)");
		if (pako != null)
		{
			try
			{
				var result:js.lib.Uint8Array = pako.inflate(new js.lib.Uint8Array(data.getData()));
				if (result.length >= expected)
					return Bytes.ofData(result.buffer.slice(result.byteOffset, result.byteOffset + result.byteLength));
			}
			catch (e:Dynamic) {}
		}
		#end

		var out = Bytes.alloc(expected);
		var inflater = new haxe.zip.InflateImpl(new BytesInput(data), true, false);
		var position = 0;
		while (position < expected)
		{
			var read = inflater.readBytes(out, position, expected - position);
			if (read <= 0) break;
			position += read;
		}
		if (position < expected) throw "the PNG image data is incomplete";
		return out;
	}

	// ------------------------------------------------------------------------------------------
	// Scanline filters (in place). Every line starts with 1 filter-type byte followed by `stride` data bytes.
	// ------------------------------------------------------------------------------------------

	static function unfilter(b:Bytes, start:Int, stride:Int, rows:Int, step:Int):Void
	{
		var prev = -1; // start of the previous (already unfiltered) line, -1 = none (all zeros)
		for (y in 0...rows)
		{
			var line = start + y * (stride + 1);
			var type = b.get(line);
			var d = line + 1;

			switch (type)
			{
				case 0:
				case 1: // Sub
					for (i in step...stride)
						b.set(d + i, (b.get(d + i) + b.get(d + i - step)) & 0xFF);
				case 2: // Up
					if (prev >= 0)
						for (i in 0...stride)
							b.set(d + i, (b.get(d + i) + b.get(prev + 1 + i)) & 0xFF);
				case 3: // Average
					for (i in 0...stride)
					{
						var left = i >= step ? b.get(d + i - step) : 0;
						var up = prev >= 0 ? b.get(prev + 1 + i) : 0;
						b.set(d + i, (b.get(d + i) + ((left + up) >> 1)) & 0xFF);
					}
				case 4: // Paeth
					for (i in 0...stride)
					{
						var left = i >= step ? b.get(d + i - step) : 0;
						var up = prev >= 0 ? b.get(prev + 1 + i) : 0;
						var upLeft = (prev >= 0 && i >= step) ? b.get(prev + 1 + i - step) : 0;
						var pa = up - upLeft;
						var pb = left - upLeft;
						var pc = pa + pb;
						if (pa < 0) pa = -pa;
						if (pb < 0) pb = -pb;
						if (pc < 0) pc = -pc;
						var predictor = (pa <= pb && pa <= pc) ? left : (pb <= pc ? up : upLeft);
						b.set(d + i, (b.get(d + i) + predictor) & 0xFF);
					}
				default:
					throw "invalid PNG filter type " + type;
			}
			prev = line;
		}
	}
}

/** Turns one unfiltered scanline into A, R, G, B bytes. */
private class Converter
{
	var colorType:Int;
	var depth:Int;
	var palette:Bytes; // R,G,B per entry
	var paletteSize:Int;
	var trns:Bytes;
	var hasKey:Bool = false; // colour key transparency (greyscale / RGB images)
	var keyR:Int = 0;
	var keyG:Int = 0;
	var keyB:Int = 0;
	var maxValue:Int;

	public function new(colorType:Int, depth:Int, palette:Bytes, trns:Bytes)
	{
		this.colorType = colorType;
		this.depth = depth;
		this.palette = palette;
		this.paletteSize = palette == null ? 0 : Std.int(palette.length / 3);
		this.trns = trns;
		this.maxValue = (1 << depth) - 1;

		if (trns != null)
		{
			if (colorType == 0 && trns.length >= 2)
			{
				hasKey = true;
				keyR = keyG = keyB = (trns.get(0) << 8) | trns.get(1);
			}
			else if (colorType == 2 && trns.length >= 6)
			{
				hasKey = true;
				keyR = (trns.get(0) << 8) | trns.get(1);
				keyG = (trns.get(2) << 8) | trns.get(3);
				keyB = (trns.get(4) << 8) | trns.get(5);
			}
		}
	}

	/** Reads sample number `index` (0 based, counted in samples of this line) of a line starting at `line`. */
	inline function sample(b:Bytes, line:Int, index:Int):Int
	{
		return switch (depth)
		{
			case 8: b.get(line + index);
			case 16: (b.get(line + index * 2) << 8) | b.get(line + index * 2 + 1);
			default:
				var bit = index * depth;
				(b.get(line + (bit >> 3)) >> (8 - depth - (bit & 7))) & maxValue;
		};
	}

	/** 16 bit and low-depth samples to 0..255 */
	inline function to8(v:Int):Int
	{
		return switch (depth)
		{
			case 8: v;
			case 16: v >> 8;
			default: Std.int(v * 255 / maxValue);
		};
	}

	public function convertLine(b:Bytes, line:Int, count:Int, out:Bytes, outPos:Int, outStep:Int):Void
	{
		var o = outPos;
		switch (colorType)
		{
			case 6:
				if (depth == 8)
				{
					for (x in 0...count)
					{
						var s = line + x * 4;
						out.set(o, b.get(s + 3));
						out.set(o + 1, b.get(s));
						out.set(o + 2, b.get(s + 1));
						out.set(o + 3, b.get(s + 2));
						o += outStep;
					}
				}
				else
				{
					for (x in 0...count)
					{
						var s = line + x * 8; // 16 bit: take the high byte of each sample
						out.set(o, b.get(s + 6));
						out.set(o + 1, b.get(s));
						out.set(o + 2, b.get(s + 2));
						out.set(o + 3, b.get(s + 4));
						o += outStep;
					}
				}
			case 2:
				for (x in 0...count)
				{
					var r = sample(b, line, x * 3);
					var g = sample(b, line, x * 3 + 1);
					var bl = sample(b, line, x * 3 + 2);
					var a = (hasKey && r == keyR && g == keyG && bl == keyB) ? 0 : 255;
					out.set(o, a);
					out.set(o + 1, to8(r));
					out.set(o + 2, to8(g));
					out.set(o + 3, to8(bl));
					o += outStep;
				}
			case 3:
				for (x in 0...count)
				{
					var index = sample(b, line, x);
					if (index < paletteSize)
					{
						out.set(o, (trns != null && index < trns.length) ? trns.get(index) : 255);
						out.set(o + 1, palette.get(index * 3));
						out.set(o + 2, palette.get(index * 3 + 1));
						out.set(o + 3, palette.get(index * 3 + 2));
					}
					else
					{
						out.set(o, 0);
						out.set(o + 1, 0);
						out.set(o + 2, 0);
						out.set(o + 3, 0);
					}
					o += outStep;
				}
			case 0:
				for (x in 0...count)
				{
					var raw = sample(b, line, x);
					var v = to8(raw);
					out.set(o, (hasKey && raw == keyR) ? 0 : 255);
					out.set(o + 1, v);
					out.set(o + 2, v);
					out.set(o + 3, v);
					o += outStep;
				}
			case 4:
				for (x in 0...count)
				{
					var v = to8(sample(b, line, x * 2));
					var a = to8(sample(b, line, x * 2 + 1));
					out.set(o, a);
					out.set(o + 1, v);
					out.set(o + 2, v);
					out.set(o + 3, v);
					o += outStep;
				}
			default:
		}
	}
}
