package rendertest;

import haxe.io.Bytes;
import lime.graphics.Image;
import lime.graphics.PixelFormat;
import lime.math.Rectangle;

/**
	An image as RGB values (0xRRGGBB) for comparing captures with references; alpha is kept
	beside them (alpha()) for the tests that need it. Loads and saves PNG through lime.
**/
class Pixels
{
	public var width(default, null):Int;
	public var height(default, null):Int;

	/** RGBA, 4 bytes per pixel, rows top to bottom. **/
	var data:Bytes;

	public function new(width:Int, height:Int, ?data:Bytes)
	{
		this.width = width;
		this.height = height;
		this.data = data != null ? data : Bytes.alloc(width * height * 4);
	}

	public static function fromImage(image:Image):Pixels
	{
		var bytes = image.getPixels(new Rectangle(0, 0, image.width, image.height), PixelFormat.RGBA32);
		return new Pixels(image.width, image.height, bytes);
	}

	#if sys
	public static function load(path:String):Pixels
	{
		var image = Image.fromBytes(sys.io.File.getBytes(path));
		if (image == null) throw "cannot read image " + path;
		return fromImage(image);
	}

	/** Saves as PNG; opaque unless `keepAlpha`. **/
	public function save(path:String, keepAlpha:Bool = false):Void
	{
		var image = new Image(null, 0, 0, width, height, 0x00000000);
		var bytes = Bytes.alloc(data.length);
		bytes.blit(0, data, 0, data.length);
		if (!keepAlpha)
			for (i in 0...width * height) bytes.set(i * 4 + 3, 255);
		image.setPixels(new Rectangle(0, 0, width, height), bytes, PixelFormat.RGBA32);
		sys.io.File.saveBytes(path, image.encode(PNG));
	}
	#end

	public static function filled(width:Int, height:Int, rgb:Int):Pixels
	{
		var p = new Pixels(width, height);
		for (y in 0...height)
			for (x in 0...width)
				p.set(x, y, rgb);
		return p;
	}

	public inline function get(x:Int, y:Int):Int
	{
		var i = (y * width + x) * 4;
		return (data.get(i) << 16) | (data.get(i + 1) << 8) | data.get(i + 2);
	}

	public inline function set(x:Int, y:Int, rgb:Int):Void
	{
		var i = (y * width + x) * 4;
		data.set(i, (rgb >> 16) & 0xFF);
		data.set(i + 1, (rgb >> 8) & 0xFF);
		data.set(i + 2, rgb & 0xFF);
		data.set(i + 3, 255);
	}

	public inline function alpha(x:Int, y:Int):Int
	{
		return data.get((y * width + x) * 4 + 3);
	}

	public inline function setAlpha(x:Int, y:Int, value:Int):Void
	{
		data.set((y * width + x) * 4 + 3, value);
	}

	public inline function red(x:Int, y:Int):Int
	{
		return data.get((y * width + x) * 4);
	}

	public inline function green(x:Int, y:Int):Int
	{
		return data.get((y * width + x) * 4 + 1);
	}

	public inline function blue(x:Int, y:Int):Int
	{
		return data.get((y * width + x) * 4 + 2);
	}

	/** The largest of the three channel differences between a pixel here and one in `other`. **/
	public inline function channelDiff(x:Int, y:Int, other:Pixels, ox:Int, oy:Int):Int
	{
		var i = (y * width + x) * 4;
		var j = (oy * other.width + ox) * 4;
		var r = data.get(i) - other.data.get(j);
		var g = data.get(i + 1) - other.data.get(j + 1);
		var b = data.get(i + 2) - other.data.get(j + 2);
		if (r < 0) r = -r;
		if (g < 0) g = -g;
		if (b < 0) b = -b;
		return r > g ? (r > b ? r : b) : (g > b ? g : b);
	}

	public function crop(x:Int, y:Int, w:Int, h:Int):Pixels
	{
		var p = new Pixels(w, h);
		for (row in 0...h)
			p.data.blit(row * w * 4, data, ((y + row) * width + x) * 4, w * 4);
		return p;
	}

	/** Each pixel as a `factor` x `factor` block (nearest neighbour), to show small images large. **/
	public function scaled(factor:Int):Pixels
	{
		var p = new Pixels(width * factor, height * factor);
		for (y in 0...p.height)
			for (x in 0...p.width)
				p.set(x, y, get(Std.int(x / factor), Std.int(y / factor)));
		return p;
	}

	public function copy():Pixels
	{
		return new Pixels(width, height, data.sub(0, data.length));
	}

	/** Pastes `source` with its top-left at (x, y). **/
	public function paste(source:Pixels, x:Int, y:Int):Void
	{
		for (row in 0...source.height)
		{
			var ty = y + row;
			if (ty < 0 || ty >= height) continue;
			for (col in 0...source.width)
			{
				var tx = x + col;
				if (tx >= 0 && tx < width) set(tx, ty, source.get(col, row));
			}
		}
	}
}
