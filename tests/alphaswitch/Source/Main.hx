package;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.DisplayObject;
import openfl.display.Graphics;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import rendertest.Harness;

/**
	A shape that comes to be composited with ALPHA without its own blend mode having been ALPHA
	when its graphics were rendered. ALPHA masks a shape with its fills (its coverage, a second
	render of the fills), not with its box; that coverage has to exist whenever the shape is
	composited with ALPHA, however the mode reached it.

	The shape is an L of two half-transparent rectangles filling three quarters of a 40 x 40
	box, so the empty quarter sits inside the box: a mask made of the box cuts the backdrop
	there, the right mask leaves it alone. Cells of 100 px, a four-colour backdrop:
	  row 0  the reference: the shape created with blendMode ALPHA
	  row 1  the case: the shape created NORMAL, and
	  columns  in a LAYER, switched to ALPHA on frame 2;  on the stage, switched to ALPHA on
	           frame 2;  as the child of a container drawn into a transparent BitmapData over the
	           backdrop with BitmapData.draw(container, matrix, null, ALPHA), the mode given to
	           draw reaching the child (row 0 draws a shape whose own mode is ALPHA the same way)

	Captured on frame 4 and scored by Score.hx (see rendertest.Harness).
**/
class Main extends Sprite
{
	public static inline var CELL = 100;
	public static inline var GROUND = 0xB0B0B0;

	static function backdropData():BitmapData
	{
		var bd = new BitmapData(60, 60, false, 0);
		bd.fillRect(new Rectangle(0, 0, 30, 30), 0xFF2040E0);
		bd.fillRect(new Rectangle(30, 0, 30, 30), 0xFFE0C020);
		bd.fillRect(new Rectangle(0, 30, 30, 30), 0xFF20A040);
		bd.fillRect(new Rectangle(30, 30, 30, 30), 0xFFA02060);
		return bd;
	}

	static function backdrop():Bitmap
	{
		var b = new Bitmap(backdropData());
		b.x = 20;
		b.y = 20;
		return b;
	}

	static function shape(mode:BlendMode):Shape
	{
		var s = new Shape();
		s.graphics.beginFill(0xFF8040, 0.5);
		s.graphics.drawRect(0, 0, 40, 20);
		s.graphics.drawRect(0, 20, 20, 20);
		s.graphics.endFill();
		s.x = 30;
		s.y = 30;
		s.blendMode = mode;
		return s;
	}

	var switched:Array<DisplayObject> = [];

	function cell(column:Int, reference:Bool):Sprite
	{
		var holder = new Sprite();
		var s = shape(reference ? ALPHA : NORMAL);
		if (!reference) switched.push(s);
		switch (column)
		{
			case 0:
				holder.blendMode = LAYER;
				holder.addChild(backdrop());
				holder.addChild(s);
			case 1:
				holder.addChild(backdrop());
				holder.addChild(s);
			default:
				// the backdrop copied into a transparent bitmap, then a container holding the shape
				// drawn into it with the mode given to draw (the shape is a child, so it is composited
				// with that mode; the root of a draw is drawn as it is)
				var bd = new BitmapData(60, 60, true, 0);
				bd.draw(backdropData());
				var source = new Sprite();
				source.addChild(s);
				bd.draw(source, new Matrix(1, 0, 0, 1, 10, 10), null, ALPHA);
				var b = new Bitmap(bd);
				b.x = 20;
				b.y = 20;
				holder.addChild(b);
				switched.remove(s);
		}
		return holder;
	}

	var frame = 0;

	public function new()
	{
		super();
		graphics.beginFill(GROUND);
		graphics.drawRect(0, 0, 3 * CELL, 2 * CELL);
		graphics.endFill();
		for (row in 0...2)
			for (column in 0...3)
			{
				var item = cell(column, row == 0);
				item.x = column * CELL;
				item.y = row * CELL;
				addChild(item);
			}
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	function onFrame(_):Void
	{
		frame++;
		if (frame == 2) for (s in switched) s.blendMode = ALPHA;
		// captured on frame 4: the Cairo window surface read by readPixels holds the previous frame
		if (frame < 4) return;
		removeEventListener(Event.ENTER_FRAME, onFrame);
		Harness.capture(stage, Score.score, 3 * CELL, 2 * CELL);
	}
}
