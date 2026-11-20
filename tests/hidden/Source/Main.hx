package;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.DisplayObject;
import openfl.display.Sprite;
import openfl.events.Event;
import rendertest.Harness;

/**
	An object that draws nothing, next to a sibling under a formula mode. Inside a LAYER the four
	SUBTRACT and INVERT draw their object as it is where nothing has ever been drawn (ERASE and ALPHA cut
	nothing there), and run their
	formula against the transparent backdrop where something was drawn and then cut (ALPHA and
	ERASE show nothing there, SUBTRACT and INVERT a silhouette). The renderers keep the union of
	what was drawn into the layer to tell the two apart, and an object that drew nothing must not
	widen it.

	Cells of 100 px on a grey stage, each a LAYER holding a placeholder square (40 x 40 at 10, 10)
	and an orange disc (48 px at 30, 30) under the mode, overlapping the square's box:
	  row 0  no placeholder                                the reference: the disc as it is
	  row 1  the square with visible = false
	  row 2  the square with alpha = 0
	  row 3  a Sprite whose only child is the square with visible = false
	  columns  ALPHA, ERASE, SUBTRACT, INVERT

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

	static function square():Bitmap
	{
		var b = new Bitmap(new BitmapData(40, 40, false, 0x2040E0));
		b.x = 10;
		b.y = 10;
		return b;
	}

	static function placeholder(row:Int):DisplayObject
	{
		switch (row)
		{
			case 1:
				var s = square();
				s.visible = false;
				return s;
			case 2:
				var s = square();
				s.alpha = 0;
				return s;
			case 3:
				var s = square();
				s.visible = false;
				var container = new Sprite();
				container.addChild(s);
				return container;
			default:
				return null;
		}
	}

	static function cell(mode:BlendMode, row:Int):Sprite
	{
		var layer = new Sprite();
		layer.blendMode = LAYER;
		var p = placeholder(row);
		if (p != null) layer.addChild(p);
		var d = new Bitmap(disc(0xFF8040));
		d.x = 30;
		d.y = 30;
		d.blendMode = mode;
		layer.addChild(d);
		return layer;
	}

	var frame = 0;

	public function new()
	{
		super();
		graphics.beginFill(GROUND);
		graphics.drawRect(0, 0, MODES.length * CELL, 4 * CELL);
		graphics.endFill();
		for (row in 0...4)
			for (i in 0...MODES.length)
			{
				var item = cell(MODES[i], row);
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
		Harness.capture(stage, Score.score, MODES.length * CELL, 4 * CELL);
	}
}
