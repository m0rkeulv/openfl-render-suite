package;

import openfl.Assets;
import openfl.display.BlendMode;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.text.AntiAliasType;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import rendertest.Harness;

/**
	Blend modes on text. Every blend mode is applied to a TextField, and each row repeats one
	placement of that field across all the modes, so that offsets that only show under rotation,
	scaling or a fractional position can be told apart from the blend itself.

	AIR and OpenFL rasterise glyphs differently, so a blended cell can never equal AIR's pixel for
	pixel. Instead every cell sits on the same backdrop of colored shapes (a blue ground, a green
	band, a purple disc, a yellow block, so that every placement of the text crosses several colors
	and a blended cell can be told from plain text of some color), the last column shows that
	backdrop without text, and the text uses an embedded font (Noto Sans), which AIR draws the same
	way inside and outside a blend group. The NORMAL cell of a row then gives each renderer's own
	glyph coverage per pixel, against its own backdrop cell, and Score.hx predicts every
	other cell of that row from it with Flash's formula for the mode. AIR goes through the same
	check, which confirms the formulas, and the ink position of each row is compared against AIR
	separately.

	Cells of 100 x 80 px:
	  columns  NORMAL LAYER ADD SUBTRACT MULTIPLY SCREEN LIGHTEN DARKEN DIFFERENCE INVERT OVERLAY
	           HARDLIGHT ALPHA ERASE, then the backdrop without text
	  rows     plain;  at a fractional position;  rotated 30 degrees;  scaled 1.6;  rotated 90
	           degrees;  at alpha 0.5;  plain with the mode on a Sprite holding it;  plain in a cell
	           that is a LAYER (the text blends into a transparent group)

	A black rectangle under all cells is what ERASE and ALPHA cut through to, on every target: AIR's
	capture draws the stage without its color, OpenFL's window is white.

	The field is 56 x 44 with autoSize off, "Ag" at 28 px in #F25A1A; Score.hx repeats
	these numbers and the placements, so change them in both places.

	Captured on frame 4 and scored by Score.hx (see rendertest.Harness).
**/
class Main extends Sprite
{
	public static inline var CELL_W = 100;
	public static inline var CELL_H = 80;
	public static inline var TEXT_COLOR = 0xF25A1A;
	public static inline var FIELD_W = 56;
	public static inline var FIELD_H = 44;
	public static inline var SIZE = 28;

	static var MODES:Array<BlendMode> = [
		NORMAL, LAYER, ADD, SUBTRACT, MULTIPLY, SCREEN, LIGHTEN, DARKEN, DIFFERENCE, INVERT, OVERLAY, HARDLIGHT, ALPHA, ERASE
	];

	// x, y within the cell, rotation in degrees, scale, alpha, where the mode goes (0 the field,
	// 1 a Sprite holding the field, 2 the field in a LAYER cell)
	static var ROWS:Array<Array<Float>> = [
		[12, 14, 0, 1, 1, 0],
		[12.35, 14.6, 0, 1, 1, 0],
		[30, 4, 30, 1, 1, 0],
		[6, 4, 0, 1.6, 1, 0],
		[70, 6, 90, 1, 1, 0],
		[12, 14, 0, 1, 0.5, 0],
		[12, 14, 0, 1, 1, 1],
		[12, 14, 0, 1, 1, 2]
	];

	var frame = 0;

	public function new()
	{
		super();
		var font = Assets.getFont("assets/NotoSans-Regular.ttf");
		graphics.beginFill(0);
		graphics.drawRect(0, 0, (MODES.length + 1) * CELL_W, ROWS.length * CELL_H);
		graphics.endFill();
		for (row in 0...ROWS.length)
		{
			for (column in 0...MODES.length + 1)
			{
				var cell = new Sprite();
				cell.x = column * CELL_W;
				cell.y = row * CELL_H;
				backdrop(cell.graphics);
				if (column == MODES.length)
				{
					// the backdrop on its own, in a cell like the others
					if (ROWS[row][5] == 2) cell.blendMode = LAYER;
					addChild(cell);
					continue;
				}
				var placement = ROWS[row];
				var tf = field(font.fontName, placement, MODES[column]);
				if (placement[5] == 1)
				{
					var holder = new Sprite();
					holder.blendMode = tf.blendMode;
					tf.blendMode = NORMAL;
					holder.addChild(tf);
					cell.addChild(holder);
				}
				else
				{
					cell.addChild(tf);
					if (placement[5] == 2) cell.blendMode = LAYER;
				}
				addChild(cell);
			}
		}
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	/**
		The backdrop of every cell: a blue ground, a green band down the left, a purple disc in the
		middle and a yellow block at the bottom right, all far from the text's orange, so that every
		placement of the text crosses several colors.
	**/
	static function backdrop(g:openfl.display.Graphics):Void
	{
		g.beginFill(0x408CD9);
		g.drawRect(0, 0, CELL_W, CELL_H);
		g.endFill();
		g.beginFill(0x3CB043);
		g.drawRect(0, 0, 34, CELL_H);
		g.endFill();
		g.beginFill(0xF0D030);
		g.drawRect(40, 42, 60, 38);
		g.endFill();
		g.beginFill(0x7040C0);
		g.drawCircle(58, 26, 22);
		g.endFill();
	}

	static function field(fontName:String, placement:Array<Float>, mode:BlendMode):TextField
	{
		var tf = new TextField();
		tf.embedFonts = true;
		tf.antiAliasType = AntiAliasType.NORMAL;
		tf.selectable = false;
		tf.autoSize = TextFieldAutoSize.NONE;
		tf.width = FIELD_W;
		tf.height = FIELD_H;
		tf.defaultTextFormat = new TextFormat(fontName, SIZE, TEXT_COLOR);
		tf.text = "Ag";
		tf.x = placement[0];
		tf.y = placement[1];
		tf.rotation = placement[2];
		tf.scaleX = tf.scaleY = placement[3];
		tf.alpha = placement[4];
		tf.blendMode = mode;
		return tf;
	}

	function onFrame(_):Void
	{
		frame++;
		// captured on frame 4: the Cairo window surface read by readPixels holds the previous frame
		if (frame < 4) return;
		removeEventListener(Event.ENTER_FRAME, onFrame);
		Harness.capture(stage, Score.score, (MODES.length + 1) * CELL_W, ROWS.length * CELL_H);
	}
}
