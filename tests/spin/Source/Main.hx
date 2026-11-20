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
	Blended objects that spin. A rotated object's texture coordinates no longer line up with
	the backdrop under it, so the composite has to find the backdrop by where each pixel lands,
	the copy of the backdrop has to cover the rotated quad, and a rotated container's coverage
	has to follow its leaves' transforms. Every object turns by SPEED degrees per frame from
	its own starting angle and the frame is captured on frame 3, at the same angles on every
	renderer.

	A grid of 16 x 9 cells of 64 px. A cell is a 56 x 56 four-colour backdrop inside a LAYER (or
	on the stage for the last mode) with a 32 px object spinning about the cell's centre. Along
	a row the starting angle runs through ANGLES twice (columns 0-7 and 8-15 are two different
	cases). The 18 cases, two per row:

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
	public static inline var SIZE = 32;
	public static inline var SPEED = 7;
	public static inline var CAPTURE_FRAME = 3;
	public static inline var GROUND = 0xB0B0B0;
	public static var ANGLES = [0, 12, 30, 45, 60, 75, 90, 200];
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
	static inline function margin(s:Int):Int
		return s >> 2;

	static inline function core(s:Int):Int
		return (s - 2 * margin(s)) >> 2;

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
		var b = new Bitmap(new BitmapData(s >> 1, s >> 1, false, 0x20C040));
		b.x = s >> 2;
		b.y = s >> 2;
		sp.addChild(b);
		return sp;
	}

	/** Places `object`, whose local centre is (SIZE / 2, SIZE / 2), so that centre sits on the cell's centre at `angle`. **/
	public static function place(object:DisplayObject, angle:Float):Void
	{
		var r = angle * Math.PI / 180, h = SIZE / 2;
		object.rotation = angle;
		object.x = (CELL >> 1) - (Math.cos(r) * h - Math.sin(r) * h);
		object.y = (CELL >> 1) - (Math.sin(r) * h + Math.cos(r) * h);
	}

	var objects:Array<DisplayObject> = [];
	var angles:Array<Float> = [];

	public static function cell(kind:Int, mode:Int):Sprite
	{
		var holder = new Sprite();
		if (mode < 5) holder.blendMode = LAYER;
		holder.addChild(backdrop());
		var object:DisplayObject = switch (kind)
		{
			case 0: bitmapObject(SIZE);
			case 1: shapeObject(SIZE);
			default: containerObject(SIZE);
		}
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
			for (i in 0...ANGLES.length)
			{
				var item = cell(kind, mode);
				item.x = (group * 8 + i) * CELL;
				item.y = row * CELL;
				addChild(item);
				var object = item.getChildAt(1);
				objects.push(object);
				angles.push(ANGLES[i]);
				place(object, ANGLES[i]);
			}
		}
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	function onFrame(_):Void
	{
		frame++;
		for (i in 0...objects.length) place(objects[i], angles[i] + frame * SPEED);
		if (frame < CAPTURE_FRAME) return;
		removeEventListener(Event.ENTER_FRAME, onFrame);
		Harness.capture(stage, Score.score, COLS * CELL, ROWS * CELL);
	}
}
