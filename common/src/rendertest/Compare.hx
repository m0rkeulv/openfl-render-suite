package rendertest;

/** How far a region of one image is from a region of another. **/
typedef Difference =
{
	/** Percent of the pixels whose largest channel difference is over the tolerance. **/
	off:Float,
	/** The largest channel difference in the region. **/
	max:Int,
	count:Int
}

/**
	Pixel comparisons. A pixel is "off" when the largest of its three channel differences is over
	the tolerance, the measure all the tests use.
**/
class Compare
{
	public static inline var MASK_GROUND = 0x1C1C1C;
	public static inline var MASK_MARK = 0xD63E2E;

	/** Region (ax, ay, w, h) of `a` against the region of the same size at (bx, by) in `b`. **/
	public static function region(a:Pixels, ax:Int, ay:Int, b:Pixels, bx:Int, by:Int, w:Int, h:Int, tolerance:Int):Difference
	{
		var count = 0, max = 0;
		for (y in 0...h)
			for (x in 0...w)
			{
				var d = a.channelDiff(ax + x, ay + y, b, bx + x, by + y);
				if (d > max) max = d;
				if (d > tolerance) count++;
			}
		// count / n * 100 in this order, as numpy computes (pixels > tolerance).mean() * 100
		return {off: w * h > 0 ? count / (w * h) * 100 : 0.0, max: max, count: count};
	}

	/** The same region of two images of the same layout. **/
	public static inline function same(a:Pixels, b:Pixels, x:Int, y:Int, w:Int, h:Int, tolerance:Int):Difference
	{
		return region(a, x, y, b, x, y, w, h, tolerance);
	}

	/** Two whole images; they must be the same size. **/
	public static function whole(a:Pixels, b:Pixels, tolerance:Int):Difference
	{
		if (a.width != b.width || a.height != b.height)
			throw 'images differ in size: ${a.width}x${a.height} against ${b.width}x${b.height}';
		return region(a, 0, 0, b, 0, 0, a.width, a.height, tolerance);
	}

	/**
		A difference mask the size of `a`: a dim grey copy of `a`, with the pixels that are off
		against `b` in red. Optionally only a region (the rest stays dark).
	**/
	public static function mask(a:Pixels, b:Pixels, tolerance:Int, x:Int = 0, y:Int = 0, ?w:Int, ?h:Int, bx:Int = -1, by:Int = -1):Pixels
	{
		if (w == null) w = a.width - x;
		if (h == null) h = a.height - y;
		if (bx < 0) bx = x;
		if (by < 0) by = y;
		var out = Pixels.filled(a.width, a.height, MASK_GROUND);
		for (row in 0...h)
			for (col in 0...w)
			{
				var px = x + col, py = y + row;
				if (a.channelDiff(px, py, b, bx + col, by + row) > tolerance)
				{
					out.set(px, py, MASK_MARK);
				}
				else
				{
					var c = a.get(px, py);
					var grey = Std.int((((c >> 16) & 0xFF) * 3 + ((c >> 8) & 0xFF) * 6 + (c & 0xFF)) / 10 * 0.35) + 30;
					out.set(px, py, (grey << 16) | (grey << 8) | grey);
				}
			}
		return out;
	}
}
