package;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;
import rendertest.Harness;

/**
	A TextField under a blend mode, with its text changing every frame. A text field is drawn
	from a texture its own rasteriser refreshes, so a composite that reads the texture directly
	has to go through that rasteriser or it shows the text of an earlier frame, or nothing.

	Cells of 100 px on a grey stage. Row 0: a LAYER holding only the text field, so nothing was
	drawn under it: DIFFERENCE, SUBTRACT and INVERT draw the text as it is and must equal cell 0,
	NORMAL, pixel for pixel; on screen ERASE and ALPHA have nothing to cut there and show nothing
	(BitmapData.draw of the stage shows them as the text). Row 1: the text over an opaque black
	square on the stage, NORMAL (reference) and DIFFERENCE (equal to NORMAL over black). The text
	reads the frame number and is captured on frame 3, so a stale texture shows "1" or "2"
	instead of "3".

	Device text differs between AIR and OpenFL, so Score.hx compares the cells within the
	capture, and each cell's outcome with AIR's (see rendertest.Harness for the capture).
**/
class Main extends Sprite
{
	public static inline var CELL = 100;
	public static inline var GROUND = 0xB0B0B0;
	public static var MODES:Array<BlendMode> = [NORMAL, DIFFERENCE, ALPHA, ERASE, SUBTRACT, INVERT];

	var fields:Array<TextField> = [];

	function text(mode:BlendMode):TextField
	{
		var t = new TextField();
		t.defaultTextFormat = new TextFormat("_sans", 40, 0xFF8040, true);
		t.width = 80;
		t.height = 60;
		t.x = 10;
		t.y = 20;
		t.text = "0";
		t.blendMode = mode;
		fields.push(t);
		return t;
	}

	var frame = 0;

	public function new()
	{
		super();
		graphics.beginFill(GROUND);
		graphics.drawRect(0, 0, 6 * CELL, 2 * CELL);
		graphics.endFill();
		for (i in 0...MODES.length)
		{
			var layer = new Sprite();
			layer.blendMode = LAYER;
			layer.addChild(text(MODES[i]));
			layer.x = i * CELL;
			addChild(layer);
		}
		for (i in 0...2)
		{
			var holder = new Sprite();
			holder.addChild(new Bitmap(new BitmapData(80, 80, false, 0x000000)));
			holder.getChildAt(0).x = 10;
			holder.getChildAt(0).y = 10;
			holder.addChild(text(i == 0 ? NORMAL : DIFFERENCE));
			holder.x = i * CELL;
			holder.y = CELL;
			addChild(holder);
		}
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	function onFrame(_):Void
	{
		frame++;
		for (t in fields) t.text = Std.string(frame);
		if (frame < 3) return;
		removeEventListener(Event.ENTER_FRAME, onFrame);
		Harness.capture(stage, Score.score, 6 * CELL, 2 * CELL);
	}
}
