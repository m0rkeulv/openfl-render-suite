package;

import openfl.Assets;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.text.AntiAliasType;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import rendertest.Harness;

/**
	What counts as "drawn" inside a LAYER. Where nothing has been drawn into a LAYER yet, Flash draws
	a SUBTRACT or INVERT object as it is; where something has, it applies the mode, even over pixels
	that are transparent. This asks whether "drawn" follows the shape of what was drawn, or its
	bounding box. ERASE and ALPHA cut wherever they are drawn, which over the untouched part is
	nothing; on screen, that is (the stage's draw() shows them as they are there, see the cutters kit).

	Each cell is a LAYER holding a blue ring (80 x 60, a 30 x 30 hole) and an orange bar in the
	cell's mode that crosses it: along the bar, outside the ring's box, over the ring, over the hole,
	over the ring, outside the box. In the hole, a SUBTRACT or INVERT bar as it is (orange) means the
	hole counts as never drawn, the mode's result over a transparent backdrop (black, white) means the
	ring's box counts as drawn. An ERASE or ALPHA bar shows nothing there either way.

	Cells of 120 x 100 on mid grey:
	  columns  NORMAL SUBTRACT INVERT ERASE ALPHA, and a sixth column without the bar (or, in the
	           row where text is the object under the mode, without the text): the layer's content on
	           its own, from which Score.hx predicts the text rows' blended cells
	  rows     the ring is the LAYER's own graphics;  the ring is a Shape child drawn before the bar;
	           the ring is that child at alpha 0.5 (drawn, but the backdrop stays partly transparent);
	           a disc child instead of the ring (its anti-aliased rim is partly covered);  a Bitmap child
	           with the ring's shape (its hole is transparent bitmap pixels, which a bitmap still blits);
	           text drawn first instead of the ring (its glyphs are what it covers, not its box);  the
	           ring, then text in the column's mode instead of the bar;  the ring, then text drawn NORMAL
	           over it, then the bar

	The text is "Ag" in embedded Noto Sans at 44 px, so that its glyphs are drawn the same way inside
	and outside a group on every target.

	Captured on frame 4 and scored by Score.hx (see rendertest.Harness).
**/
class Main extends Sprite
{
	public static inline var CELL_W = 120;
	public static inline var CELL_H = 100;

	public static inline var ROWS = 8;

	public static var MODES:Array<BlendMode> = [NORMAL, SUBTRACT, INVERT, ERASE, ALPHA];
	public static inline var COLUMNS = 6; // the modes and the bar-less reference

	var frame = 0;

	public function new()
	{
		super();
		graphics.beginFill(0x808080);
		graphics.drawRect(0, 0, COLUMNS * CELL_W, ROWS * CELL_H);
		graphics.endFill();
		var fontName = Assets.getFont("assets/NotoSans-Regular.ttf").fontName;

		for (row in 0...ROWS)
		{
			for (column in 0...COLUMNS)
			{
				var layer = new Sprite();
				layer.blendMode = LAYER;
				layer.x = column * CELL_W;
				layer.y = row * CELL_H;
				if (row == 0)
				{
					ring(layer.graphics);
				}
				else if (row == 4)
				{
					var data = new BitmapData(80, 60, true, 0xFF408CD9);
					data.fillRect(new openfl.geom.Rectangle(25, 15, 30, 30), 0);
					var bitmap = new openfl.display.Bitmap(data);
					bitmap.x = 20;
					bitmap.y = 20;
					layer.addChild(bitmap);
				}
				else if (row == 5)
				{
					layer.addChild(text(fontName, 0x408CD9, NORMAL));
				}
				else if (row >= 6)
				{
					var shape = new Shape();
					ring(shape.graphics);
					layer.addChild(shape);
					if (row == 6)
					{
						// the text is the object under the mode: no bar in this row
						if (column < MODES.length) layer.addChild(text(fontName, 0xF25A1A, MODES[column]));
						addChild(layer);
						continue;
					}
					layer.addChild(text(fontName, 0x3CB043, NORMAL));
				}
				else
				{
					var shape = new Shape();
					if (row == 3)
					{
						shape.graphics.beginFill(0x408CD9);
						shape.graphics.drawCircle(60, 50, 30);
						shape.graphics.endFill();
					}
					else
					{
						ring(shape.graphics);
					}
					if (row == 2) shape.alpha = 0.5;
					layer.addChild(shape);
				}
				if (column < MODES.length)
				{
					var bar = new Shape();
					bar.graphics.beginFill(0xF25A1A);
					bar.graphics.drawRect(4, 44, 112, 12);
					bar.graphics.endFill();
					bar.blendMode = MODES[column];
					layer.addChild(bar);
				}
				addChild(layer);
			}
		}
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	static function text(fontName:String, color:Int, mode:BlendMode):TextField
	{
		var tf = new TextField();
		tf.embedFonts = true;
		tf.antiAliasType = AntiAliasType.NORMAL;
		tf.selectable = false;
		tf.autoSize = TextFieldAutoSize.NONE;
		tf.width = 90;
		tf.height = 70;
		tf.defaultTextFormat = new TextFormat(fontName, 44, color);
		tf.text = "Ag";
		tf.x = 18;
		tf.y = 12;
		tf.blendMode = mode;
		return tf;
	}

	static function ring(g:openfl.display.Graphics):Void
	{
		g.beginFill(0x408CD9);
		g.drawRect(20, 20, 80, 60);
		g.drawRect(45, 35, 30, 30);
		g.endFill();
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
