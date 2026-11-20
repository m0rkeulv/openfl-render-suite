package;

import openfl.display.BlendMode;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.filters.ColorMatrixFilter;
import openfl.geom.Rectangle;
import rendertest.Harness;

/**
	What makes an ERASE or ALPHA object cut. On screen, Flash draws an ERASE or ALPHA object only when
	an ancestor renders through a buffer of its own (a LAYER for one); straight on the stage the object
	is not drawn at all. BitmapData.draw applies the modes anyway, so the reference for this kit is what
	AIR's window shows, and its draw() is kept beside it.

	Cells of 120 x 100 on mid grey, each a container of some kind holding a blue ring (80 x 60, a 30 x
	30 hole) and an orange bar (y 46..56) across it: ERASE in row 0, ALPHA at alpha 0.5 in row 1 (an
	opaque ALPHA bar over the ring would keep it whether it cuts or not). Over the ring the bar shows
	the stage (ERASE) or a dimmed ring (ALPHA) when it cuts, the ring when the object is not drawn at
	all, and orange when it is drawn as it is. Row 2 is row 0 with the ring under the container, on the
	stage: a container that cuts only cuts what it holds. Rows 3 and 4 are rows 0 and 1 with the
	container inside a LAYER, a buffer inside a buffer, where AIR's window shows a cutter over
	untouched pixels as it is (the nested kit found this with Bitmap cutters); row 5 is row 3 with a
	green ERASE bar down through the ring before the bar, which is SUBTRACT there: over the hole under
	the green bar the orange bar is black where the ERASE bar counted as touching, orange where not.

	Columns, the container kind:
	  0  a plain Sprite
	  1  a Sprite at alpha 0.5
	  2  a Sprite in MULTIPLY
	  3  a Sprite in ADD
	  4  a Sprite with cacheAsBitmap
	  5  a Sprite with an identity ColorMatrixFilter
	  6  a Sprite with a scrollRect over the whole cell
	  7  a Sprite with a mask over the whole cell
	  8  a LAYER holding a plain Sprite that holds the ring and the bar
	  9  a plain Sprite; the bar itself has cacheAsBitmap
	  10 a plain Sprite; the bar itself has the identity filter
	  11 a Sprite at alpha 0.5 with cacheAsBitmap

	Captured on frame 4 and scored by Score.hx (see rendertest.Harness).
**/
class Main extends Sprite
{
	public static inline var CELL_W = 120;
	public static inline var CELL_H = 100;
	public static inline var COLUMNS = 12;
	public static inline var ROWS = 6;

	var frame = 0;

	public function new()
	{
		super();
		addEventListener(Event.ADDED_TO_STAGE, function(_) {
			stage.color = 0x808080;
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
				var cell = new Sprite();
				if (row >= 3) cell.blendMode = LAYER;
				cell.x = column * CELL_W;
				cell.y = row * CELL_H;
				addChild(cell);
				if (row == 2) cell.addChild(ring());

				var container = new Sprite();
				var inner = container;
				var alphaRow = row == 1 || row == 4;
				var bar = bar(row == 5 ? SUBTRACT : alphaRow ? ALPHA : ERASE, alphaRow ? 0.5 : 1);
				switch (column)
				{
					case 1: container.alpha = 0.5;
					case 2: container.blendMode = MULTIPLY;
					case 3: container.blendMode = ADD;
					case 4: container.cacheAsBitmap = true;
					case 5: container.filters = [new ColorMatrixFilter()];
					case 6: container.scrollRect = new Rectangle(0, 0, CELL_W, CELL_H);
					case 7:
						var mask = new Shape();
						mask.graphics.beginFill(0);
						mask.graphics.drawRect(0, 0, CELL_W, CELL_H);
						mask.graphics.endFill();
						cell.addChild(mask);
						container.mask = mask;
					case 8:
						container.blendMode = LAYER;
						inner = new Sprite();
						container.addChild(inner);
					case 9: bar.cacheAsBitmap = true;
					case 10: bar.filters = [new ColorMatrixFilter()];
					case 11:
						container.alpha = 0.5;
						container.cacheAsBitmap = true;
					default:
				}
				if (row != 2) inner.addChild(ring());
				if (row == 5) inner.addChild(across(ERASE));
				inner.addChild(bar);
				cell.addChild(container);
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

	static function across(mode:BlendMode):Shape
	{
		var s = new Shape();
		s.graphics.beginFill(0x3CB043);
		s.graphics.drawRect(56, 4, 8, 92);
		s.graphics.endFill();
		s.blendMode = mode;
		return s;
	}

	static function bar(mode:BlendMode, alpha:Float):Shape
	{
		var s = new Shape();
		s.graphics.beginFill(0xF25A1A);
		s.graphics.drawRect(4, 46, 112, 10);
		s.graphics.endFill();
		s.blendMode = mode;
		s.alpha = alpha;
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
