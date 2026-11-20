package;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.DisplayObject;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import rendertest.Harness;

/**
	A hit test must not change how a shape is drawn. The Cairo rasteriser plays a graphics'
	commands for hitTestPoint(x, y, true) with a static flag set, so the fills are measured
	instead of painted, and only a full render clears that flag again. A shape that is already
	rendered and comes under ALPHA afterwards needs its coverage, the second all-opaque render
	of its fills, and that one is made without a full render: with the flag still set from a hit
	test, the coverage is painted with nothing, the keep mask comes out solid, and ALPHA stops
	cutting the backdrop at all. The flag is static, so one hit test anywhere poisons every
	shape whose coverage is made before the next full render.

	Cells of 100 px, a four-colour backdrop under a half-transparent L that leaves one quarter
	of its box empty:
	  row 0  the case: the shape is created NORMAL and switched to ALPHA on frame 2, so its
	         coverage is made on its own, without a full render
	  row 1  the control: the shape is created with ALPHA, so its coverage is made by the full
	         render on frame 1, before any hit test
	  columns  the shape in a LAYER;  the shape on the opaque stage

	The two rows must be the same picture. On frame 2 the row 0 shapes are hit-tested with
	shapeFlag set, unless built with -Dhittest_nohits (variant _nohit), which gives the same
	scene without a hit test.

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

	function cell(column:Int, control:Bool):Sprite
	{
		var holder = new Sprite();
		var s = shape(control ? ALPHA : NORMAL);
		if (!control) switched.push(s);
		// column 0 puts the shape in a LAYER, column 1 leaves it on the opaque stage
		if (column == 0) holder.blendMode = LAYER;
		holder.addChild(backdrop());
		holder.addChild(s);
		return holder;
	}

	var frame = 0;

	public function new()
	{
		super();
		graphics.beginFill(GROUND);
		graphics.drawRect(0, 0, 2 * CELL, 2 * CELL);
		graphics.endFill();
		for (row in 0...2)
			for (column in 0...2)
			{
				var item = cell(column, row == 1);
				item.x = column * CELL;
				item.y = row * CELL;
				addChild(item);
			}
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	function onFrame(_):Void
	{
		frame++;
		if (frame == 2)
		{
			#if !hittest_nohits
			{
				// a point inside the top bar of the L, in stage coordinates, with shapeFlag set:
				// the rasteriser plays the fills to answer it
				var hits = 0;
				for (s in switched)
				{
					var p = s.localToGlobal(new Point(10, 10));
					if (s.hitTestPoint(p.x, p.y, true)) hits++;
				}
				#if sys
				Sys.println("hit tests inside the fill: " + hits + " of " + switched.length);
				#end
			}
			#end
			for (s in switched) s.blendMode = ALPHA;
		}
		// captured on frame 4: the Cairo window surface read by readPixels holds the previous frame
		if (frame < 4) return;
		removeEventListener(Event.ENTER_FRAME, onFrame);
		Harness.capture(stage, Score.score, 2 * CELL, 2 * CELL);
	}
}
