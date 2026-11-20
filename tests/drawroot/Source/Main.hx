package;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.DisplayObject;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import rendertest.Harness;

/**
	The blend mode given to BitmapData.draw: the source is composited onto the bitmap with that
	mode, as one object, whatever the source's own blend mode. Cells of 100 px on a grey stage,
	each showing a 60 x 60 bitmap that first received the four-colour backdrop and then a source
	drawn with the mode:
	  columns  ALPHA, ERASE, SUBTRACT, INVERT: the source is a bare Shape, an L of two
	           half-transparent rectangles over the backdrop's centre, so the mode's formula has to
	           reach the root object itself;  ADD: the source is a Sprite of two overlapping
	           half-transparent squares, added once as a whole (an overlap added twice is brighter)
	  row 0    a transparent bitmap: a cut shows the stage through it
	  row 1    an opaque bitmap: Flash keeps it opaque, as it keeps the stage

	Captured on frame 3 and scored by Score.hx (see rendertest.Harness).
**/
class Main extends Sprite
{
	public static inline var CELL = 100;
	public static inline var GROUND = 0xB0B0B0;
	public static var MODES:Array<BlendMode> = [ALPHA, ERASE, SUBTRACT, INVERT, ADD];

	static function backdropData():BitmapData
	{
		var bd = new BitmapData(60, 60, false, 0);
		bd.fillRect(new Rectangle(0, 0, 30, 30), 0xFF2040E0);
		bd.fillRect(new Rectangle(30, 0, 30, 30), 0xFFE0C020);
		bd.fillRect(new Rectangle(0, 30, 30, 30), 0xFF20A040);
		bd.fillRect(new Rectangle(30, 30, 30, 30), 0xFFA02060);
		return bd;
	}

	static function source(mode:BlendMode):DisplayObject
	{
		if (mode == ADD)
		{
			var s = new Sprite();
			for (i in 0...2)
			{
				var b = new Bitmap(new BitmapData(24, 24, false, 0x60C0FF));
				b.x = 10 + i * 12;
				b.y = 10 + i * 12;
				b.alpha = 0.5;
				s.addChild(b);
			}
			return s;
		}
		var s = new Shape();
		s.graphics.beginFill(0xFF8040, 0.5);
		s.graphics.drawRect(0, 0, 40, 20);
		s.graphics.drawRect(0, 20, 20, 20);
		s.graphics.endFill();
		return s;
	}

	static function cell(mode:BlendMode, opaque:Bool):Sprite
	{
		var holder = new Sprite();
		var bd = new BitmapData(60, 60, !opaque, 0);
		bd.draw(backdropData());
		bd.draw(source(mode), new Matrix(1, 0, 0, 1, 10, 10), null, mode);
		var b = new Bitmap(bd);
		b.x = 20;
		b.y = 20;
		holder.addChild(b);
		return holder;
	}

	var frame = 0;

	public function new()
	{
		super();
		graphics.beginFill(GROUND);
		graphics.drawRect(0, 0, MODES.length * CELL, 2 * CELL);
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
		Harness.capture(stage, Score.score, MODES.length * CELL, 2 * CELL);
	}
}
