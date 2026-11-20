package;

import openfl.display.Shape;
import openfl.display.Sprite;

/**
	Vector art for the fill-seam "bleed" test.

	Every element is built from abutting fills (shapes that share an edge) on a
	magenta background. No fill colour contains any blue, so any blue found
	inside the body of an element is background that leaked through a seam: a
	renderer that anti-aliases each fill separately (Cairo with antialiasing on)
	composites the soft edge of one fill over the soft edge of its neighbour and
	lets the background show through along the shared edge. Flash / AIR and a
	supersampled render show no seam at all.

	The scene is deterministic (fixed pseudo-random jitter), 800 x 600, and each
	element records its bounding box in `regions` so a scorer can report per
	element. Build with `BleedTestArt.build()` and add the returned sprite to
	the display list or draw it with `BitmapData.draw`.
**/
class BleedTestArt
{
	public static inline var WIDTH:Int = 800;
	public static inline var HEIGHT:Int = 600;
	public static inline var BACKGROUND:Int = 0xFF00FF;

	/**
		Fill colours: none has a blue component. Most elements use a few close
		tones of one hue so that adjacent fills differ little and the magenta seam
		is the most contrasting thing in the element (green is magenta's
		complement: the mix greys out). Two elements use dark olives, where the
		seam shows as a bright pink line; one keeps a busy mixed palette so the
		report also shows what a typical multi-coloured asset looks like.
	**/
	public static var GREENS:Array<Int> = [0x00C000, 0x00A800, 0x40D000];
	public static var DARKS:Array<Int> = [0x203000, 0x404000, 0x304000];
	public static var MIXED:Array<Int> = [0x00C000, 0xFFFF00, 0xFF8000, 0x404000, 0x80FF00, 0xC0C000, 0xFF0000, 0x808000];

	// the tone set the element being built picks its fills from
	private static var tones:Array<Int> = GREENS;

	/** Bounding box and description of every element, filled by `build()`. **/
	public static var regions(default, null):Array<BleedRegion> = [];

	// deterministic pseudo-random sequence so every run draws the same scene
	private static var seed:Int = 1;

	private static function rnd():Float
	{
		seed = (seed * 1103515245 + 12345) & 0x7fffffff;
		return (seed % 10000) / 10000;
	}

	public static function build():Sprite
	{
		seed = 1;
		regions = [];

		var root = new Sprite();
		var ground = shape(root);
		ground.graphics.beginFill(BACKGROUND);
		ground.graphics.drawRect(0, 0, WIDTH, HEIGHT);
		ground.graphics.endFill();

		tones = GREENS;
		cloud(root, 20, 20, 12, 8, 20, "cloud", "12 x 8 grid of jittered abutting quads, every cell its own fill (three greens)");
		pie(root, 400, 110, 80, 16, "pie", "16 wedges sharing edges that all meet at the centre (three greens)");
		stripes(root, 520, 20, 37, 7.3, 160, "stripes", "37 abutting vertical stripes 7.3 px wide, fractional edges (three greens)");
		tones = DARKS;
		zigzag(root, 20, 210, 12, 20, 100, "triangles", "triangle strip: alternating up / down triangles sharing both sides (dark olives)");
		tones = GREENS;
		curveTiles(root, 300, 210, 6, 40, 100, "curves", "tiles separated by shared quadratic curves, same curve drawn twice reversed (three greens)");
		tones = MIXED;
		diamonds(root, 580, 200, 6, 4, 26, "diamonds", "square grid rotated 30 degrees and scaled 0.7, all edges off-pixel (mixed palette, the busy case)");
		tones = GREENS;
		sameColour(root, 20, 340, 8, 30.5, 80, "samecolour", "8 abutting rectangles of one colour, 30.5 px wide: a seam here is a line inside a flat area");
		rings(root, 400, 420, 4, 8, 20, 100, "rings", "4 concentric rings of 8 abutting segments each (three greens)");
		cloudScaled(root, 540, 360, "tinycloud", "the cloud scaled 0.35: cells 7 px wide with sub-pixel jitter (three greens)");
		tones = DARKS;
		spikes(root, 540, 440, 16, 15, 140, "spikes", "tall narrow triangles alternating up and down, sharing their long edges (dark olives)");

		return root;
	}

	/** The regions as a JSON array (name, x, y, width, height, note) for scorers. **/
	public static function regionsJson():String
	{
		var parts = [];
		for (r in regions)
		{
			parts.push('{"name":"' + r.name + '","x":' + r.x + ',"y":' + r.y + ',"width":' + r.width + ',"height":' + r.height + ',"note":"'
				+ StringTools.replace(r.note, '"', "'") + '"}');
		}
		return "[" + parts.join(",\n") + "]";
	}

	// ---- elements ------------------------------------------------------------

	private static function cloud(parent:Sprite, x0:Float, y0:Float, nx:Int, ny:Int, cell:Float, name:String, note:String):Void
	{
		var s = shape(parent);
		var vx = [], vy = [];
		for (j in 0...ny + 1)
			for (i in 0...nx + 1)
			{
				vx.push(x0 + i * cell + (rnd() - 0.5) * cell * 0.4);
				vy.push(y0 + j * cell + (rnd() - 0.5) * cell * 0.4);
			}
		for (j in 0...ny)
			for (i in 0...nx)
			{
				var k = i + j * (nx + 1);
				s.graphics.beginFill(tones[(i * 3 + j * 5) % tones.length]);
				s.graphics.moveTo(vx[k], vy[k]);
				s.graphics.lineTo(vx[k + 1], vy[k + 1]);
				s.graphics.lineTo(vx[k + nx + 2], vy[k + nx + 2]);
				s.graphics.lineTo(vx[k + nx + 1], vy[k + nx + 1]);
				s.graphics.lineTo(vx[k], vy[k]);
				s.graphics.endFill();
			}
		region(name, x0 - 5, y0 - 5, nx * cell + 10, ny * cell + 10, note);
	}

	private static function pie(parent:Sprite, cx:Float, cy:Float, r:Float, n:Int, name:String, note:String):Void
	{
		var s = shape(parent);
		for (i in 0...n)
		{
			var a0 = i * 2 * Math.PI / n, a1 = (i + 1) * 2 * Math.PI / n;
			s.graphics.beginFill(tones[i % tones.length]);
			s.graphics.moveTo(cx, cy);
			s.graphics.lineTo(cx + r * Math.cos(a0), cy + r * Math.sin(a0));
			// approximate the arc with a few straight segments
			var steps = 4;
			for (k in 1...steps + 1)
			{
				var a = a0 + (a1 - a0) * k / steps;
				s.graphics.lineTo(cx + r * Math.cos(a), cy + r * Math.sin(a));
			}
			s.graphics.lineTo(cx, cy);
			s.graphics.endFill();
		}
		region(name, cx - r - 5, cy - r - 5, 2 * r + 10, 2 * r + 10, note);
	}

	private static function stripes(parent:Sprite, x0:Float, y0:Float, n:Int, w:Float, h:Float, name:String, note:String):Void
	{
		var s = shape(parent);
		for (i in 0...n)
		{
			s.graphics.beginFill(tones[i % tones.length]);
			s.graphics.drawRect(x0 + i * w, y0, w, h);
			s.graphics.endFill();
		}
		region(name, x0 - 5, y0 - 5, n * w + 10, h + 10, note);
	}

	private static function zigzag(parent:Sprite, x0:Float, y0:Float, n:Int, w:Float, h:Float, name:String, note:String):Void
	{
		var s = shape(parent);
		for (i in 0...n)
		{
			// up triangle then down triangle, sharing the slanted edges
			s.graphics.beginFill(tones[(2 * i) % tones.length]);
			s.graphics.moveTo(x0 + i * w, y0 + h);
			s.graphics.lineTo(x0 + i * w + w / 2, y0);
			s.graphics.lineTo(x0 + (i + 1) * w, y0 + h);
			s.graphics.lineTo(x0 + i * w, y0 + h);
			s.graphics.endFill();
			s.graphics.beginFill(tones[(2 * i + 1) % tones.length]);
			s.graphics.moveTo(x0 + i * w + w / 2, y0);
			s.graphics.lineTo(x0 + (i + 1) * w + w / 2, y0);
			s.graphics.lineTo(x0 + (i + 1) * w, y0 + h);
			s.graphics.lineTo(x0 + i * w + w / 2, y0);
			s.graphics.endFill();
		}
		region(name, x0 - 5, y0 - 5, n * w + w / 2 + 10, h + 10, note);
	}

	private static function curveTiles(parent:Sprite, x0:Float, y0:Float, n:Int, w:Float, h:Float, name:String, note:String):Void
	{
		var s = shape(parent);
		var bulge = w * 0.75;
		for (i in 0...n)
		{
			var xa = x0 + i * w, xb = x0 + (i + 1) * w;
			s.graphics.beginFill(tones[i % tones.length]);
			s.graphics.moveTo(xa, y0);
			s.graphics.curveTo(xa + bulge, y0 + h / 2, xa, y0 + h); // left boundary, downwards
			s.graphics.lineTo(xb, y0 + h);
			s.graphics.curveTo(xb + bulge, y0 + h / 2, xb, y0); // right boundary, upwards (the next tile's left one, reversed)
			s.graphics.lineTo(xa, y0);
			s.graphics.endFill();
		}
		region(name, x0 - 5, y0 - 5, n * w + bulge / 2 + 10, h + 10, note);
	}

	private static function diamonds(parent:Sprite, x0:Float, y0:Float, nx:Int, ny:Int, cell:Float, name:String, note:String):Void
	{
		var s = shape(parent);
		for (j in 0...ny)
			for (i in 0...nx)
			{
				s.graphics.beginFill(tones[(i + j * 3) % tones.length]);
				s.graphics.drawRect(i * cell, j * cell, cell, cell);
				s.graphics.endFill();
			}
		s.rotation = 30;
		s.scaleX = s.scaleY = 0.7;
		s.x = x0 + 40;
		s.y = y0;
		region(name, x0 - 5, y0 - 5, 200, 150, note);
	}

	private static function sameColour(parent:Sprite, x0:Float, y0:Float, n:Int, w:Float, h:Float, name:String, note:String):Void
	{
		var s = shape(parent);
		for (i in 0...n)
		{
			s.graphics.beginFill(tones[0]);
			s.graphics.drawRect(x0 + i * w, y0, w, h);
			s.graphics.endFill();
		}
		region(name, x0 - 5, y0 - 5, n * w + 10, h + 10, note);
	}

	private static function rings(parent:Sprite, cx:Float, cy:Float, nRings:Int, nSeg:Int, rInner:Float, rOuter:Float, name:String, note:String):Void
	{
		var s = shape(parent);
		var step = (rOuter - rInner) / nRings;
		for (ring in 0...nRings)
		{
			var r0 = rInner + ring * step, r1 = r0 + step;
			for (i in 0...nSeg)
			{
				var a0 = i * 2 * Math.PI / nSeg, a1 = (i + 1) * 2 * Math.PI / nSeg;
				s.graphics.beginFill(tones[(i + ring * 3) % tones.length]);
				s.graphics.moveTo(cx + r0 * Math.cos(a0), cy + r0 * Math.sin(a0));
				var steps = 6;
				for (k in 0...steps + 1)
				{
					var a = a0 + (a1 - a0) * k / steps;
					s.graphics.lineTo(cx + r1 * Math.cos(a), cy + r1 * Math.sin(a));
				}
				for (k in 0...steps + 1)
				{
					var a = a1 - (a1 - a0) * k / steps;
					s.graphics.lineTo(cx + r0 * Math.cos(a), cy + r0 * Math.sin(a));
				}
				s.graphics.endFill();
			}
		}
		region(name, cx - rOuter - 5, cy - rOuter - 5, 2 * rOuter + 10, 2 * rOuter + 10, note);
	}

	private static function cloudScaled(parent:Sprite, x0:Float, y0:Float, name:String, note:String):Void
	{
		var holder = new Sprite();
		parent.addChild(holder);
		cloud(holder, 0, 0, 12, 8, 20, name, note);
		regions.pop(); // replace the unscaled region with the placed one
		holder.scaleX = holder.scaleY = 0.35;
		holder.x = x0;
		holder.y = y0;
		region(name, x0 - 5, y0 - 5, 12 * 20 * 0.35 + 10, 8 * 20 * 0.35 + 10, note);
	}

	// the triangle strip again, but tall and narrow: the shared edges meet at
	// very acute angles, so the seams are long and nearly vertical
	private static function spikes(parent:Sprite, x0:Float, y0:Float, n:Int, w:Float, h:Float, name:String, note:String):Void
	{
		zigzag(parent, x0, y0, n, w, h, name, note);
	}

	// ---- helpers -------------------------------------------------------------

	private static function shape(parent:Sprite):Shape
	{
		var s = new Shape();
		parent.addChild(s);
		return s;
	}

	private static function region(name:String, x:Float, y:Float, w:Float, h:Float, note:String):Void
	{
		regions.push({name: name, x: Math.floor(x), y: Math.floor(y), width: Math.ceil(w), height: Math.ceil(h), note: note});
	}
}

typedef BleedRegion =
{
	name:String,
	x:Int,
	y:Int,
	width:Int,
	height:Int,
	note:String
}
