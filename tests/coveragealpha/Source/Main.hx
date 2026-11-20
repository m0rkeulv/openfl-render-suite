package;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.DisplayObject;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.geom.Rectangle;
import rendertest.Harness;

/**
	A container under ALPHA with alpha below one, holding a shape with an anti-aliased edge.
	ALPHA keeps the backdrop by 1 - coverage + alpha, and a container's coverage is drawn in a
	pass of its own by the OpenGL renderer; that pass must draw the coverage as it is, whatever
	the container's alpha. An object's alpha applies once, to the whole object, so a container at
	alpha 0.5 holding an opaque disc renders exactly like a container at alpha 1 holding a disc
	filled at 0.5: row 0 is the latter (the reference), row 1 the former (the case), and the two
	rows must match pixel for pixel, rims included, since the same renderer rasterises both.

	Cells of 100 px on a grey stage, a four-colour backdrop inside a LAYER, the object over it:
	  column 0  a Sprite under ALPHA holding a disc shape          the coverage pass, a rim
	  column 1  a Sprite under ALPHA holding a square shape        the coverage pass, no rim (control)
	  column 2  the disc shape itself under ALPHA                  no pass: the leaf composite (control)

	Captured on frame 3 and scored by Score.hx (see rendertest.Harness).
**/
class Main extends Sprite
{
	public static inline var CELL = 100;
	public static inline var GROUND = 0xB0B0B0;

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

	static function shape(disc:Bool, fillAlpha:Float):Shape
	{
		var s = new Shape();
		s.graphics.beginFill(0xFF8040, fillAlpha);
		if (disc) s.graphics.drawCircle(20, 20, 18);
		else s.graphics.drawRect(2, 2, 36, 36);
		s.graphics.endFill();
		return s;
	}

	/** The object of a cell: `objectAlpha` on the object, `fillAlpha` in the shape; the product is 0.5 in both rows. **/
	static function object(column:Int, objectAlpha:Float, fillAlpha:Float):DisplayObject
	{
		var s = shape(column != 1, fillAlpha);
		var o:DisplayObject = s;
		if (column < 2)
		{
			var container = new Sprite();
			container.addChild(s);
			o = container;
		}
		o.x = 30;
		o.y = 30;
		o.alpha = objectAlpha;
		o.blendMode = ALPHA;
		return o;
	}

	static function cell(column:Int, reference:Bool):Sprite
	{
		var holder = new Sprite();
		holder.blendMode = LAYER;
		holder.addChild(backdrop());
		holder.addChild(reference ? object(column, 1, 0.5) : object(column, 0.5, 1));
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
		if (++frame < 3) return;
		removeEventListener(Event.ENTER_FRAME, onFrame);
		Harness.capture(stage, Score.score, 3 * CELL, 2 * CELL);
	}
}
