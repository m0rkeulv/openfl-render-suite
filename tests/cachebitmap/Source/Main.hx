package;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.DisplayObject;
import openfl.display.Sprite;
import openfl.events.Event;
import rendertest.Harness;

/**
	Blend modes inside a cacheAsBitmap container. Flash renders such a container into an
	offscreen bitmap first, so an ERASE or ALPHA child only cuts its siblings inside it and
	the cut shows whatever is under the container, exactly as inside a LAYER. The renderers
	draw the cached container with a separate renderer whose target is a transparent bitmap,
	and that renderer must not take the opaque-stage shortcuts (a black backing under a cut,
	INVERT and SUBTRACT in place).

	Eight cells of 100 px on a grey stage, four modes in two rows:
	  row 0  LAYER [blue backdrop, orange disc with the mode]          the reference behaviour
	  row 1  cacheAsBitmap sprite [the same]                           must look the same
	The disc overhangs the backdrop, so part of it sits over ground the container never drew.

	Captured on frame 3 and scored by Score.hx (see rendertest.Harness).
**/
class Main extends Sprite
{
	public static inline var CELL = 100;
	public static inline var GROUND = 0xB0B0B0;
	public static var MODES:Array<BlendMode> = [ALPHA, ERASE, SUBTRACT, INVERT];

	static function disc(color:Int):BitmapData
	{
		var bd = new BitmapData(48, 48, true, 0);
		for (y in 0...48)
			for (x in 0...48)
			{
				var dx = x - 23.5, dy = y - 23.5;
				if (Math.sqrt(dx * dx + dy * dy) < 20) bd.setPixel32(x, y, 0xFF000000 | color);
			}
		return bd;
	}

	static function bitmap(bd:BitmapData, x:Float, y:Float, ?mode:BlendMode):Bitmap
	{
		var b = new Bitmap(bd);
		b.x = x;
		b.y = y;
		if (mode != null) b.blendMode = mode;
		return b;
	}

	public static function cell(mode:BlendMode, cached:Bool):Sprite
	{
		var s = new Sprite();
		if (cached) s.cacheAsBitmap = true;
		else s.blendMode = LAYER;
		s.addChild(bitmap(new BitmapData(60, 60, false, 0x2040E0), 10, 10));
		s.addChild(bitmap(disc(0xFF8040), 30, 30, mode));
		return s;
	}

	var frame = 0;

	public function new()
	{
		super();
		graphics.beginFill(GROUND);
		graphics.drawRect(0, 0, 4 * CELL, 2 * CELL);
		graphics.endFill();
		for (row in 0...2)
			for (i in 0...MODES.length)
			{
				var item = cell(MODES[i], row == 1);
				item.x = i * CELL;
				item.y = row * CELL;
				addChild(item);
			}
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	function onFrame(_):Void
	{
		if (++frame < 3) return;
		removeEventListener(Event.ENTER_FRAME, onFrame);
		Harness.capture(stage, Score.score, 4 * CELL, 2 * CELL);
	}
}
