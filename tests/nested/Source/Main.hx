package;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.DisplayObject;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import rendertest.Harness;

/**
	Nested blend modes: what a blended child of a LAYER does over its siblings, over a
	region an earlier mask cut, over ground nothing drew, and inside further LAYERs and
	blended containers. Twenty-four cells of 100 px in a 4 x 6 grid on a grey stage, every
	piece hard-edged so a cell either matches Adobe AIR or it does not. The cells:

	 1  layer [backdrop, red, ALPHA mask]              mask last: red cut outside the disc
	 2  layer [backdrop, ALPHA mask, red]              red drawn after the mask stays whole
	 3  layer [backdrop, ALPHA mask, ALPHA disc over the cut]   over a cut region: nothing
	 4  layer [half backdrop, ALPHA disc]              over never-drawn ground: nothing (a cutter cuts, it is never shown as it is)
	 5  layer [backdrop, ERASE mask, ADD square over the cut]   ADD shows the source there
	 6  layer [backdrop, ALPHA mask, SUBTRACT square over the cut]   black there
	 7  layer [backdrop, ALPHA mask, INVERT square over the cut]     white there
	 8  layer [half backdrop, INVERT square]           inverted over the backdrop, as it is beside it
	 9  layer [backdrop, layer [red, ALPHA mask]]      the inner cut shows the outer backdrop
	10  layer [backdrop, sprite [layer [ALPHA mask, red]]]   order inside a nested layer
	11  layer [backdrop, ADD sprite [red, green overlapping]]   a container blends as a whole
	12  layer [backdrop, ALPHA sprite [disc, square]]  a container as the mask
	13  layer [backdrop, ALPHA mask, ALPHA vector square over the cut]   a shape over a cut region
	14  layer [backdrop, ALPHA mask at alpha 0.5]      a mask with alpha
	15  layer at alpha 0.5 [backdrop, ALPHA mask]      a layer with alpha
	16  layer [backdrop, layer [ERASE mask]]           a mask alone in an empty inner layer
	17  layer [backdrop, layer [ERASE shape]]          a white ERASE shape alone in an inner layer
	18  layer [backdrop, layer [red, ALPHA shape]]     a shape cutter over a bitmap in an inner layer
	19  layer [backdrop, layer [red shape, ALPHA mask]]  a bitmap cutter over a shape in an inner layer
	20  layer [backdrop, layer [layer [ERASE mask]]]   the bitmap mask two layers down
	21  layer [layer [ERASE shape]]                    as 17 without the backdrop in the outer layer
	22  layer [backdrop, layer [sprite [ERASE shape]]] as 17 with a plain sprite between the layers
	23  layer [backdrop, layer [red shape, ERASE shape]]  as 17 with a shape before the cutter
	24  layer [layer [red, ERASE shape]]               as 23 without the backdrop in the outer layer
	On screen (AIR's window), the cells with a Bitmap cutter in an inner layer (9, 10, 16) show it as
	it is over pixels nothing has been drawn on, as BitmapData.draw does everywhere; 17 to 20 ask
	whether that is the cutter being a Bitmap, or the layer holding only bitmaps.

	Captured on frame 3 and scored by Score.hx (see rendertest.Harness).
**/
class Main extends Sprite
{
	public static inline var CELL = 100;
	public static inline var GROUND = 0xB0B0B0;

	static function disc(color:Int):BitmapData
	{
		var bd = new BitmapData(64, 64, true, 0);
		for (y in 0...64)
			for (x in 0...64)
			{
				var dx = x - 31.5, dy = y - 31.5;
				if (Math.sqrt(dx * dx + dy * dy) < 26) bd.setPixel32(x, y, 0xFF000000 | color);
			}
		return bd;
	}

	static function bitmap(bd:BitmapData, x:Float, y:Float, ?mode:BlendMode, alpha:Float = 1):Bitmap
	{
		var b = new Bitmap(bd);
		b.x = x;
		b.y = y;
		if (mode != null) b.blendMode = mode;
		b.alpha = alpha;
		return b;
	}

	static function square(color:Int, x:Float, y:Float, ?mode:BlendMode):Bitmap
		return bitmap(new BitmapData(48, 48, false, color), x, y, mode);

	static function backdrop(width:Int = 80):Bitmap
		return bitmap(new BitmapData(width, 80, false, 0x2040E0), 10, 10);

	static function maskDisc(?mode:BlendMode, alpha:Float = 1):Bitmap
		return bitmap(disc(0xFFFFFF), 26, 26, mode == null ? ALPHA : mode, alpha);

	static function layer(children:Array<DisplayObject>, alpha:Float = 1):Sprite
	{
		var s = new Sprite();
		s.blendMode = LAYER;
		s.alpha = alpha;
		for (c in children) s.addChild(c);
		return s;
	}

	static function sprite(children:Array<DisplayObject>, ?mode:BlendMode):Sprite
	{
		var s = new Sprite();
		if (mode != null) s.blendMode = mode;
		for (c in children) s.addChild(c);
		return s;
	}

	static function vectorSquare(color:Int, x:Float, y:Float, ?mode:BlendMode):Shape
	{
		var s = new Shape();
		s.graphics.beginFill(color);
		s.graphics.drawRect(0, 0, 40, 40);
		s.graphics.endFill();
		s.x = x;
		s.y = y;
		if (mode != null) s.blendMode = mode;
		return s;
	}

	public static function cells():Array<DisplayObject>
	{
		var red = 0xE02020, green = 0x20C040, orange = 0xFF8040;
		return [
			layer([backdrop(), square(red, 10, 10), maskDisc()]),
			layer([backdrop(), maskDisc(), square(red, 10, 10)]),
			layer([backdrop(), maskDisc(), bitmap(disc(orange), 6, 6, ALPHA)]),
			layer([backdrop(40), bitmap(disc(orange), 14, 14, ALPHA)]),
			layer([backdrop(), maskDisc(ERASE), square(green, 34, 34, ADD)]),
			layer([backdrop(), maskDisc(), square(green, 34, 34, SUBTRACT)]),
			layer([backdrop(), maskDisc(), square(green, 34, 34, INVERT)]),
			layer([backdrop(40), square(green, 30, 30, INVERT)]),
			layer([backdrop(), layer([square(red, 10, 10), maskDisc()])]),
			layer([backdrop(), sprite([layer([maskDisc(), square(red, 10, 10)])])]),
			layer([backdrop(), sprite([square(red, 20, 20), square(green, 44, 44)], ADD)]),
			layer([backdrop(), sprite([bitmap(disc(orange), 10, 10), square(red, 50, 50)], ALPHA)]),
			layer([backdrop(), maskDisc(), vectorSquare(orange, 40, 40, ALPHA)]),
			layer([backdrop(), maskDisc(ALPHA, 0.5)]),
			layer([backdrop(), maskDisc()], 0.5),
			layer([backdrop(), layer([maskDisc(ERASE)])]),
			layer([backdrop(), layer([vectorSquare(0xFFFFFF, 26, 26, ERASE)])]),
			layer([backdrop(), layer([square(red, 10, 10), vectorSquare(0xFFFFFF, 30, 30, ALPHA)])]),
			layer([backdrop(), layer([vectorSquare(red, 10, 10), maskDisc()])]),
			layer([backdrop(), layer([layer([maskDisc(ERASE)])])]),
			layer([layer([vectorSquare(0xFFFFFF, 26, 26, ERASE)])]),
			layer([backdrop(), layer([sprite([vectorSquare(0xFFFFFF, 26, 26, ERASE)])])]),
			layer([backdrop(), layer([vectorSquare(red, 10, 10), vectorSquare(0xFFFFFF, 30, 30, ERASE)])]),
			layer([layer([square(red, 10, 10), vectorSquare(0xFFFFFF, 30, 30, ERASE)])])
		];
	}

	var frame = 0;

	public function new()
	{
		super();
		graphics.beginFill(GROUND);
		graphics.drawRect(0, 0, 4 * CELL, 6 * CELL);
		graphics.endFill();
		var list = cells();
		for (i in 0...list.length)
		{
			list[i].x = (i % 4) * CELL;
			list[i].y = Std.int(i / 4) * CELL;
			addChild(list[i]);
		}
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	function onFrame(_):Void
	{
		if (++frame < 3) return;
		removeEventListener(Event.ENTER_FRAME, onFrame);
		Harness.capture(stage, Score.score, 4 * CELL, 6 * CELL);
	}
}
