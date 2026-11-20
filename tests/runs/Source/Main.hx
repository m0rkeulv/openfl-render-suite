package;

import openfl.display.BlendMode;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import rendertest.Harness;

/**
	Runs of SUBTRACT/INVERT objects inside a LAYER, and what interrupts them. The Cairo renderer keeps a
	layer's alpha in a plane of its own while such a run lasts and writes it back when anything else
	is drawn into the layer, so every kind of interruption is here, and every renderer is checked
	against AIR.

	Each cell is a LAYER on mid grey holding a blue ring (80 x 60, a 30 x 30 hole) and a sequence of
	orange bars at three heights (A, B through the hole, C), each in a mode:
	  column 0  ring; A, B, C all SUBTRACT                          a run of three
	  column 1  ring; A SUBTRACT, a green NORMAL bar across, B SUBTRACT   a run, a normal child, a run
	  column 2  ring; A SUBTRACT, B INVERT, C SUBTRACT                the two modes in one run
	  column 3  ring; A SUBTRACT, a green ERASE bar across, B SUBTRACT, C ALPHA   cutters after a run
	  column 4  ring; A SUBTRACT, a nested LAYER (green rect, B SUBTRACT inside), C SUBTRACT
	  column 5  ring; A SUBTRACT at alpha .5, B INVERT at alpha .5, C SUBTRACT    translucent objects
	  row 0     as above
	  row 1     bar A comes first, over nothing, and the ring is drawn after it
	  row 2     as row 0 with the LAYER at alpha .6 and a second SUBTRACT bar overlapping bar B
	  row 4     as row 0 with the ring at alpha .5: SUBTRACT and INVERT objects over a translucent
	            backdrop, translucent themselves in the last column
	  row 5     as row 4 with the ring at alpha .25, where the object's and the backdrop's alpha
	            add up to less than 1
	  row 3     what a formula object drawn over nothing leaves behind: a green vertical bar in a mode
	            over an empty layer (a SUBTRACT or INVERT bar shown as it is, an ERASE or ALPHA bar
	            not at all), crossed by bar B in another mode:
	            ERASE then NORMAL at alpha .5 (white); INVERT then NORMAL at alpha .5 (white);
	            SUBTRACT then INVERT; ALPHA then INVERT; ERASE then INVERT; INVERT then ALPHA

	Captured on frame 4 and scored by Score.hx (see rendertest.Harness).
**/
class Main extends Sprite
{
	public static inline var CELL_W = 120;
	public static inline var CELL_H = 100;
	public static inline var COLUMNS = 6;
	public static inline var ROWS = 6;

	var frame = 0;

	public function new()
	{
		super();
		graphics.beginFill(0x808080);
		graphics.drawRect(0, 0, COLUMNS * CELL_W, ROWS * CELL_H);
		graphics.endFill();

		for (row in 0...ROWS)
		{
			for (column in 0...COLUMNS)
			{
				var layer = new Sprite();
				layer.blendMode = LAYER;
				layer.x = column * CELL_W;
				layer.y = row * CELL_H;
				if (row == 2) layer.alpha = 0.6;

				if (row == 3)
				{
					var first:Array<BlendMode> = [ERASE, INVERT, SUBTRACT, ALPHA, ERASE, INVERT];
					layer.addChild(across(first[column]));
					switch (column)
					{
						case 0, 1: layer.addChild(bar(46, 0.5, NORMAL, 0xFFFFFF));
						case 2, 3, 4: layer.addChild(bar(46, 1, INVERT));
						case 5: layer.addChild(bar(46, 1, ALPHA));
					}
					addChild(layer);
					continue;
				}

				if (row == 1)
				{
					layer.addChild(bar(26, column == 5 ? 0.5 : 1, SUBTRACT));
					layer.addChild(ring());
				}
				else
				{
					var shape = ring();
					if (row == 4) shape.alpha = 0.5;
					if (row == 5) shape.alpha = 0.25;
					layer.addChild(shape);
					layer.addChild(bar(26, column == 5 ? 0.5 : 1, SUBTRACT));
				}

				switch (column)
				{
					case 0:
						layer.addChild(bar(46, 1, SUBTRACT));
						layer.addChild(bar(66, 1, SUBTRACT));
					case 1:
						layer.addChild(across(NORMAL));
						layer.addChild(bar(46, 1, SUBTRACT));
					case 2:
						layer.addChild(bar(46, 1, INVERT));
						layer.addChild(bar(66, 1, SUBTRACT));
					case 3:
						layer.addChild(across(ERASE));
						layer.addChild(bar(46, 1, SUBTRACT));
						layer.addChild(bar(66, 1, ALPHA));
					case 4:
						var nested = new Sprite();
						nested.blendMode = LAYER;
						nested.graphics.beginFill(0x3CB043);
						nested.graphics.drawRect(30, 40, 60, 20);
						nested.graphics.endFill();
						nested.addChild(bar(46, 1, SUBTRACT));
						layer.addChild(nested);
						layer.addChild(bar(66, 1, SUBTRACT));
					case 5:
						layer.addChild(bar(46, 0.5, INVERT));
						layer.addChild(bar(66, 1, SUBTRACT));
				}
				if (row == 2) layer.addChild(bar(50, 1, SUBTRACT));
				addChild(layer);
			}
		}
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	static function ring():Shape
	{
		var s = new Shape();
		s.graphics.beginFill(0x408CD9);
		s.graphics.drawRect(20, 20, 80, 60);
		s.graphics.drawRect(45, 35, 30, 30);
		s.graphics.endFill();
		return s;
	}

	static function bar(y:Float, alpha:Float, mode:BlendMode, color:Int = 0xF25A1A):Shape
	{
		var s = new Shape();
		s.graphics.beginFill(color);
		s.graphics.drawRect(4, y, 112, 10);
		s.graphics.endFill();
		s.alpha = alpha;
		s.blendMode = mode;
		return s;
	}

	static function across(mode:BlendMode):Shape
	{
		var s = new Shape();
		s.graphics.beginFill(0x3CB043);
		s.graphics.drawRect(56, 4, 8, 92);
		s.graphics.endFill();
		s.blendMode = mode;
		return s;
	}

	function onFrame(_):Void
	{
		frame++;
		// captured on frame 4: the Cairo window surface read by readPixels holds the previous frame
		if (frame < 4) return;
		removeEventListener(Event.ENTER_FRAME, onFrame);
		Harness.capture(stage, Score.score, COLUMNS * CELL_W, ROWS * CELL_H);
	}
}
