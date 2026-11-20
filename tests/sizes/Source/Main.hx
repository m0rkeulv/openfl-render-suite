package;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.DisplayObject;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.geom.Rectangle;
import rendertest.Harness;

/**
	Blended objects of varying sizes, one per cell, drawn in an order that alternates large and
	small: the renderers keep one scratch texture, group surface or canvas per nesting level and
	grow it as needed, and the composite reads only the part an object used, so a small object
	drawn after a large one must not see the large one's leftovers and a large one after a small
	one must get the full area. Every piece is an axis-aligned rectangle at integer coordinates,
	so a cell either matches Adobe AIR or it does not.

	A grid of 16 x 9 cells of 64 px. A cell is a 56 x 56 four-colour backdrop inside a LAYER (or
	on the stage for the last mode) with the blended object centred over it. Along a row the
	object's size runs through SIZES twice (columns 0-7 and 8-15 are two different cases), so
	the display list alternates 48, 6, 36, 12, 44, 20, 28, 4 px. The 18 cases, two per row:

	  kind       bitmap: a Bitmap, a transparent margin, a half-transparent fill, an opaque core
	             shape:  the same as vector fills (drawRect)
	             container: a Sprite of two Bitmaps (the half-transparent square, an opaque
	                     square inside it), which composes as a group on every renderer
	  mode       ALPHA, ERASE, SUBTRACT, INVERT, DIFFERENCE inside the LAYER, and DIFFERENCE on
	             the stage (the backdrop copy comes from the window there)

	case c = kind * 6 + mode sits in row c / 2, columns (c % 2) * 8 ... + 7.

	Captured on frame 3 and scored by Score.hx (see rendertest.Harness).
**/
class Main extends Sprite
{
	public static inline var CELL = 64;
	public static inline var COLS = 16;
	public static inline var ROWS = 9;
	public static inline var GROUND = 0xB0B0B0;
	public static var SIZES = [48, 6, 36, 12, 44, 20, 28, 4];
	public static var MODES:Array<BlendMode> = [ALPHA, ERASE, SUBTRACT, INVERT, DIFFERENCE, DIFFERENCE];

	static function backdrop():Bitmap
	{
		var bd = new BitmapData(56, 56, false, 0);
		bd.fillRect(new Rectangle(0, 0, 28, 28), 0xFF2040E0);
		bd.fillRect(new Rectangle(28, 0, 28, 28), 0xFFE0C020);
		bd.fillRect(new Rectangle(0, 28, 28, 28), 0xFF20A040);
		bd.fillRect(new Rectangle(28, 28, 28, 28), 0xFFA02060);
		var b = new Bitmap(bd);
		b.x = 4;
		b.y = 4;
		return b;
	}

	/** The object's geometry for size s: margin m, half-transparent fill, opaque core of half the fill. **/
	static function margin(s:Int):Int
		return s >> 2;

	static function core(s:Int):Int
	{
		var c = (s - 2 * margin(s)) >> 2;
		return c < 1 ? 1 : c;
	}

	static function bitmapObject(s:Int):Bitmap
	{
		var bd = new BitmapData(s, s, true, 0);
		var m = margin(s), c = core(s);
		bd.fillRect(new Rectangle(m, m, s - 2 * m, s - 2 * m), 0x80FF8040);
		bd.fillRect(new Rectangle((s >> 1) - c, (s >> 1) - c, 2 * c, 2 * c), 0xFFFF8040);
		return new Bitmap(bd);
	}

	static function shapeObject(s:Int):Shape
	{
		var sh = new Shape();
		var m = margin(s), c = core(s);
		sh.graphics.beginFill(0xFF8040, 0.5);
		sh.graphics.drawRect(m, m, s - 2 * m, s - 2 * m);
		sh.graphics.endFill();
		sh.graphics.beginFill(0xFF8040);
		sh.graphics.drawRect((s >> 1) - c, (s >> 1) - c, 2 * c, 2 * c);
		sh.graphics.endFill();
		return sh;
	}

	static function containerObject(s:Int):Sprite
	{
		var sp = new Sprite();
		var m = margin(s);
		var a = new BitmapData(s, s, true, 0);
		a.fillRect(new Rectangle(m, m, s - 2 * m, s - 2 * m), 0x80FF8040);
		sp.addChild(new Bitmap(a));
		var half = s >> 1;
		if (half < 2) half = 2;
		var b = new Bitmap(new BitmapData(half, half, false, 0x20C040));
		b.x = s >> 2;
		b.y = s >> 2;
		sp.addChild(b);
		return sp;
	}

	public static function cell(kind:Int, mode:Int, s:Int):DisplayObject
	{
		var holder = new Sprite();
		if (mode < 5) holder.blendMode = LAYER;
		holder.addChild(backdrop());
		var object:DisplayObject = switch (kind)
		{
			case 0: bitmapObject(s);
			case 1: shapeObject(s);
			default: containerObject(s);
		}
		object.x = (CELL >> 1) - (s >> 1);
		object.y = (CELL >> 1) - (s >> 1);
		object.blendMode = MODES[mode];
		holder.addChild(object);
		return holder;
	}

	var frame = 0;

	public function new()
	{
		super();
		graphics.beginFill(GROUND);
		graphics.drawRect(0, 0, COLS * CELL, ROWS * CELL);
		graphics.endFill();
		for (c in 0...18)
		{
			var kind = Std.int(c / 6), mode = c % 6;
			var row = c >> 1, group = c & 1;
			for (i in 0...SIZES.length)
			{
				var item = cell(kind, mode, SIZES[i]);
				item.x = (group * 8 + i) * CELL;
				item.y = row * CELL;
				addChild(item);
			}
		}
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	function onFrame(_):Void
	{
		if (++frame < 3) return;
		removeEventListener(Event.ENTER_FRAME, onFrame);
		Harness.capture(stage, Score.score, COLS * CELL, ROWS * CELL);
	}
}
