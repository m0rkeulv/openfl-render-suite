package;

import openfl.display.BlendMode;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import rendertest.Harness;

/**
	Formula modes straight on the stage, opaque or transparent. An opaque stage counts as drawn
	everywhere, so SUBTRACT and INVERT objects on it always get their formula. A transparent stage
	(`stage.color = null` in OpenFL, a transparent window in AIR) is the open question this kit
	answers: is it drawn everywhere too, like a transparent bitmap, or untouched, like an empty LAYER?
	ERASE and ALPHA objects straight on the stage are not drawn at all in AIR's window (the stage's
	draw() applies them, with black behind a cut on an opaque bitmap); inside a LAYER they cut.

	Cells of 120 x 100. Row 0: the objects sit directly on the stage; row 1: the same objects inside a
	LAYER on the stage. Columns, each with an orange bar (y 46..56) in the column's mode:
	  0  a blue ring, the bar SUBTRACT (through the ring, its hole and beyond it)
	  1  the ring, the bar INVERT
	  2  the ring, the bar ERASE
	  3  the ring, the bar ALPHA
	  4  the ring, a green ERASE bar across it, then the bar SUBTRACT over the cut
	  5  no ring: the bar SUBTRACT over nothing

	Built with -Dtransparent_stage the stage has no color. Captured on frame 4 and scored by Score.hx
	(see rendertest.Harness).
**/
class Main extends Sprite
{
	public static inline var CELL_W = 120;
	public static inline var CELL_H = 100;
	public static inline var COLUMNS = 6;
	public static inline var ROWS = 2;

	var frame = 0;

	public function new()
	{
		super();
		addEventListener(Event.ADDED_TO_STAGE, function(_) {
			#if transparent_stage
			#if !flash
			stage.color = null;
			#end
			#else
			stage.color = 0x808080;
			#end
			build();
			addEventListener(Event.ENTER_FRAME, onFrame);
		});
	}

	function build():Void
	{
		for (row in 0...ROWS)
		{
			for (column in 0...COLUMNS)
			{
				var holder = new Sprite();
				if (row == 1) holder.blendMode = LAYER;
				holder.x = column * CELL_W;
				holder.y = row * CELL_H;
				if (column < 5) holder.addChild(ring());
				switch (column)
				{
					case 0, 5: holder.addChild(bar(SUBTRACT));
					case 1: holder.addChild(bar(INVERT));
					case 2: holder.addChild(bar(ERASE));
					case 3: holder.addChild(bar(ALPHA));
					case 4:
						holder.addChild(across(ERASE));
						holder.addChild(bar(SUBTRACT));
				}
				addChild(holder);
			}
		}
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

	static function bar(mode:BlendMode):Shape
	{
		var s = new Shape();
		s.graphics.beginFill(0xF25A1A);
		s.graphics.drawRect(4, 46, 112, 10);
		s.graphics.endFill();
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
