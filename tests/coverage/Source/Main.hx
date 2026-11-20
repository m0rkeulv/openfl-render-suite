package;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.DisplayObject;
import openfl.display.Graphics;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.geom.Rectangle;
import rendertest.Harness;

/**
	A shape under ALPHA whose fills change from frame to frame inside the same bounds. ALPHA
	keeps the backdrop by 1 - coverage + alpha, and the coverage of a shape is a second render
	of its fills that the OpenGL renderer uploads as a texture; when the fills move the
	texture must follow, or the mask is the one of an earlier frame.

	The shape's box is 40 x 40 with two 2 px anchor dots in opposite corners (so the bounds
	never change), and a half-transparent fill over the left half on frames 1 and 2 and over
	the right half from frame 3 on, when the frame is captured. Cells of 100 px on a grey
	stage, a four-colour backdrop under the shape:
	  row 0  the shape drawn once with the frame-3 geometry (the reference)
	  row 1  the shape redrawn every frame
	  columns  in a LAYER (the composite reads the coverage texture); on the stage (the
	           display shader reads it); inside a Sprite under ALPHA in a LAYER (the coverage
	           pass draws it); and NORMAL in a LAYER, where coverage plays no part (control)

	Captured on frame 4 and scored by Score.hx (see rendertest.Harness).
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

	/** The fills for `frame`: the anchors, and the half-transparent half that moves on frame 3. **/
	public static function draw(g:Graphics, frame:Int):Void
	{
		g.clear();
		g.beginFill(0xFF8040, 0.5);
		g.drawRect(0, 0, 2, 2);
		g.drawRect(38, 38, 2, 2);
		g.drawRect(frame < 3 ? 0 : 20, 0, 20, 40);
		g.endFill();
	}

	var redrawn:Array<Shape> = [];

	function shape(live:Bool):Shape
	{
		var s = new Shape();
		s.x = 30;
		s.y = 30;
		draw(s.graphics, live ? 1 : 3);
		if (live) redrawn.push(s);
		return s;
	}

	function cell(column:Int, live:Bool):Sprite
	{
		var holder = new Sprite();
		holder.addChild(backdrop());
		var s = shape(live);
		switch (column)
		{
			case 0:
				holder.blendMode = LAYER;
				s.blendMode = ALPHA;
				holder.addChild(s);
			case 1:
				s.blendMode = ALPHA;
				holder.addChild(s);
			case 2:
				holder.blendMode = LAYER;
				var container = new Sprite();
				container.blendMode = ALPHA;
				container.addChild(s);
				holder.addChild(container);
			default:
				holder.blendMode = LAYER;
				holder.addChild(s);
		}
		return holder;
	}

	var frame = 0;

	public function new()
	{
		super();
		graphics.beginFill(GROUND);
		graphics.drawRect(0, 0, 4 * CELL, 2 * CELL);
		graphics.endFill();
		for (row in 0...2)
			for (column in 0...4)
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
		for (s in redrawn) draw(s.graphics, frame);
		// captured on frame 4, one frame after the geometry settled: the Cairo window surface read
		// by readPixels holds the previous frame (see the README)
		if (frame < 4) return;
		removeEventListener(Event.ENTER_FRAME, onFrame);
		Harness.capture(stage, Score.score, 4 * CELL, 2 * CELL);
	}
}
