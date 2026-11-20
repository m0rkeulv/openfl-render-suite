package;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.geom.Rectangle;
import rendertest.Harness;

/**
	A container with alpha below one under one of the operator modes (ADD, MULTIPLY, SCREEN,
	DIFFERENCE and the like). A container of several pieces is composed as a group and the group
	is drawn with the mode, and the container's alpha must be applied exactly once on the way.

	The test needs no reference: two bitmaps that do not overlap, drawn directly under the mode
	at alpha 0.5, give the same picture as the same two bitmaps inside a container at alpha 0.5
	under the mode, since with no overlap the group is just the two of them. Cells of 100 px on a
	grey stage, a four-colour backdrop under the bitmaps:
	  row 0  the reference: the two bitmaps as separate objects, each alpha 0.5, each with the mode
	  row 1  the case: a Sprite at alpha 0.5 with the mode holding the two bitmaps
	  columns  ADD, MULTIPLY, SCREEN, DIFFERENCE

	Captured on frame 3 and scored by Score.hx (see rendertest.Harness).
**/
class Main extends Sprite
{
	public static inline var CELL = 100;
	public static inline var GROUND = 0xB0B0B0;
	public static var MODES:Array<BlendMode> = [ADD, MULTIPLY, SCREEN, DIFFERENCE];

	static function backdrop():Bitmap
	{
		var bd = new BitmapData(60, 60, false, 0);
		bd.fillRect(new Rectangle(0, 0, 30, 30), 0xFF2040E0);
		bd.fillRect(new Rectangle(30, 0, 30, 30), 0xFFE0C020);
		bd.fillRect(new Rectangle(0, 30, 30, 30), 0xFF20A040);
		bd.fillRect(new Rectangle(30, 30, 30, 30), 0xFFA02060);
		var b = new Bitmap(bd);
		b.x = 20;
		b.y = 20;
		return b;
	}

	static function square(color:Int, x:Float, y:Float):Bitmap
	{
		var b = new Bitmap(new BitmapData(24, 24, false, color));
		b.x = x;
		b.y = y;
		return b;
	}

	static function cell(mode:BlendMode, container:Bool):Sprite
	{
		var holder = new Sprite();
		holder.addChild(backdrop());
		var a = square(0xFF8040, 26, 26), b = square(0x60C0FF, 52, 52);
		if (container)
		{
			var group = new Sprite();
			group.addChild(a);
			group.addChild(b);
			group.alpha = 0.5;
			group.blendMode = mode;
			holder.addChild(group);
		}
		else
		{
			for (s in [a, b])
			{
				s.alpha = 0.5;
				s.blendMode = mode;
				holder.addChild(s);
			}
		}
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
