package;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.Graphics;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.geom.Rectangle;
import rendertest.Harness;

/**
	Blend mode check.

	Twelve blend modes, each in an 80x80 cell: a LAYER sprite holding an opaque
	background tile (grey ramp, coloured squares) and, offset so it also hangs
	over the stage ground, a foreground tile (red square with a green diagonal,
	a 50% blue square, transparent margin) drawn with the blend mode. Two cells
	per mode: the live display list (the renderer's blend path) and a Bitmap of
	BitmapData.draw of the same layer (software on HashLink, native on AIR).

	Layout: mode i sits in block i / 5 (x = 8 + block * 240) and row i % 5
	(y = 8 + row * 80); the live cell first, the drawn cell 80 px to the right.

	-D blend_vector: the foreground is a Shape with the same pixels as vector fills
	(axis-aligned integer rectangles, so the AIR reference holds), redrawn every frame so
	a GPU vector renderer (-D openfl_gpu_graphics) re-renders it each frame, as animated
	vector content would. The rectangles are moveTo / lineTo paths, which the OpenGL
	renderer draws through a texture (Cairo or the GPU vector renderer); with
	-D blend_vector_rect they are drawRect calls, which it draws as triangles directly
	(the flag implies -D blend_vector). -D blend_vector_circle (implies -D blend_vector too)
	draws discs instead of rectangles: the fills no longer cover their bounding box, so a
	blend that leaks into the empty part of the bounds shows, and the discs overhang the
	background bitmap onto bare ground (transparent inside a LAYER, the stage colour on
	the stage), so each mode is also seen without a backdrop. The anti-aliased edges are
	scored apart (Score.hx, variant _circle).
	drawCircle is not a GPU vector command, so the GPU vector renderer falls back to
	software for this variant.

	A fourth band (y = 608, ten cells per row of 80 px, x = (i % 10) * 80) holds each mode
	on a container: a LAYER with the background and a Sprite in the blend mode holding
	the foreground and a second, overlapping child, to see whether the children blend
	one by one or the container as a whole.

	Captured on frame 3 and scored by Score.hx (see rendertest.Harness).
**/
class Main extends Sprite
{
	public static inline var CELL = 80;
	public static inline var TILE = 64;
	public static inline var W = 800;
	public static inline var H = 768;
	public static inline var GROUND = 0xB0B0B0;

	public static var MODES:Array<BlendMode> = [
		NORMAL, ADD, SUBTRACT, DIFFERENCE, INVERT, ERASE, ALPHA, MULTIPLY, SCREEN, LIGHTEN, DARKEN, HARDLIGHT, OVERLAY
	];

	var frame = 0;

	/** Opaque: grey ramp on top, four coloured squares below. **/
	public static function background():BitmapData
	{
		var bd = new BitmapData(TILE, TILE, false, 0xFFFFFF);
		for (x in 0...TILE)
			for (y in 0...20)
				bd.setPixel32(x, y, 0xFF000000 | (Std.int(x * 255 / (TILE - 1)) * 0x010101));
		bd.fillRect(new Rectangle(0, 20, 32, 22), 0xFF2040E0);
		bd.fillRect(new Rectangle(32, 20, 32, 22), 0xFFE0C020);
		bd.fillRect(new Rectangle(0, 42, 32, 22), 0xFF20A040);
		bd.fillRect(new Rectangle(32, 42, 32, 22), 0xFFA02060);
		return bd;
	}

	/** Transparent margin, red square with a green diagonal, 50% blue square over the red and the margin. **/
	public static function foreground():BitmapData
	{
		var bd = new BitmapData(TILE, TILE, true, 0);
		bd.fillRect(new Rectangle(8, 8, 40, 40), 0xFFFF0000);
		for (i in 0...36)
		{
			bd.setPixel32(10 + i, 10 + i, 0xFF00FF00);
			bd.setPixel32(11 + i, 10 + i, 0xFF00FF00);
		}
		bd.fillRect(new Rectangle(32, 32, 24, 24), 0x800000FF);
		// a mid-tone patch, so HARDLIGHT / OVERLAY / MULTIPLY / SCREEN do not degenerate to NORMAL
		bd.fillRect(new Rectangle(8, 32, 16, 16), 0xFF6090C0);
		return bd;
	}

	/** The foreground as vector fills: the same pixels as foreground(), or discs with -D blend_vector_circle (see CIRCLES). **/
	public static function drawForeground(g:Graphics):Void
	{
		g.clear();
		#if blend_vector_circle
		for (c in CIRCLES)
		{
			g.beginFill(c.color, c.alpha);
			g.drawCircle(c.x, c.y, c.r);
			g.endFill();
		}
		return;
		#end
		g.beginFill(0xFF0000);
		rect(g, 8, 8, 40, 40);
		g.endFill();
		g.beginFill(0x00FF00);
		for (i in 0...36)
			rect(g, 10 + i, 10 + i, 2, 1);
		g.endFill();
		g.beginFill(0x0000FF, 0.5);
		rect(g, 32, 32, 24, 24);
		g.endFill();
		g.beginFill(0x6090C0);
		rect(g, 8, 32, 16, 16);
		g.endFill();
	}

	/**
		The circle variant's discs, in foreground coordinates (the foreground sits at 12, 12
		in its cell, the background covers cell 4..68, the cell is 80): a red disc, a green
		dot on it, a 50% blue disc over the red and the margin, and a mid-tone disc so the
		light-dependent modes do not degenerate to NORMAL. The red, blue and mid-tone discs
		reach past the background to cell 76 and 72, onto bare ground. Score.hx builds the
		edge mask from this list.
	**/
	public static var CIRCLES = [
		{x: 40, y: 40, r: 24, color: 0xFF0000, alpha: 1.0},
		{x: 40, y: 40, r: 4, color: 0x00FF00, alpha: 1.0},
		{x: 52, y: 20, r: 12, color: 0x0000FF, alpha: 0.5},
		{x: 20, y: 52, r: 8, color: 0x6090C0, alpha: 1.0}
	];

	static function rect(g:Graphics, x:Float, y:Float, width:Float, height:Float):Void
	{
		#if blend_vector_rect
		g.drawRect(x, y, width, height);
		#else
		g.moveTo(x, y);
		g.lineTo(x + width, y);
		g.lineTo(x + width, y + height);
		g.lineTo(x, y + height);
		g.lineTo(x, y);
		#end
	}

	/** The mode on a container of two overlapping children: the foreground and, over its red square, a green / 50% white tile. **/
	static function container(mode:BlendMode):Sprite
	{
		var s = new Sprite();
		s.blendMode = LAYER;
		var back = new Bitmap(background());
		back.x = 4;
		back.y = 4;
		s.addChild(back);
		var group = new Sprite();
		group.blendMode = mode;
		group.x = 12;
		group.y = 12;
		group.addChild(new Bitmap(foreground()));
		var tile = new BitmapData(24, 24, true, 0xFF00FF00);
		tile.fillRect(new Rectangle(12, 0, 12, 24), 0x80FFFFFF);
		var top = new Bitmap(tile);
		top.x = 20;
		top.y = 20;
		group.addChild(top);
		s.addChild(group);
		return s;
	}

	static var shapes:Array<Shape> = [];

	static function layer(mode:BlendMode):Sprite
	{
		var s = new Sprite();
		s.blendMode = LAYER;
		var back = new Bitmap(background());
		back.x = 4;
		back.y = 4;
		s.addChild(back);
		#if (blend_vector || blend_vector_rect || blend_vector_circle)
		var front = new Shape();
		drawForeground(front.graphics);
		shapes.push(front);
		#else
		var front = new Bitmap(foreground());
		#end
		front.x = 12;
		front.y = 12;
		front.blendMode = mode;
		s.addChild(front);
		return s;
	}

	/** The same two bitmaps straight on the stage: no LAYER, so the mode works on the opaque stage itself. **/
	public static function onStage(mode:BlendMode):Sprite
	{
		var s = layer(mode);
		s.blendMode = NORMAL;
		return s;
	}

	public function new()
	{
		super();
		var ground = new Shape();
		ground.graphics.beginFill(GROUND);
		ground.graphics.drawRect(0, 0, W, H);
		ground.graphics.endFill();
		addChild(ground);

		for (i in 0...MODES.length)
		{
			var ax = 8 + Std.int(i / 5) * 240, ay = 8 + (i % 5) * CELL;

			var live = layer(MODES[i]);
			live.x = ax;
			live.y = ay;
			addChild(live);

			// drawn through BitmapData.draw onto a transparent bitmap with the ground colour
			var drawn = new BitmapData(CELL, CELL, true, 0xFF000000 | GROUND);
			drawn.draw(layer(MODES[i]));
			var bitmap = new Bitmap(drawn);
			bitmap.x = ax + CELL;
			bitmap.y = ay;
			addChild(bitmap);

			// the third cell: on the stage, without a LAYER
			var direct = onStage(MODES[i]);
			direct.x = ax + CELL * 2;
			direct.y = ay;
			addChild(direct);

			// the fourth band: the mode on a container
			var nested = container(MODES[i]);
			nested.x = (i % 10) * CELL;
			nested.y = 608 + Std.int(i / 10) * CELL;
			addChild(nested);
		}
		addEventListener(Event.ADDED_TO_STAGE, function(_)
		{
			#if ((blend_vector || blend_vector_rect || blend_vector_circle) && !blend_vector_static)
			addEventListener(Event.ENTER_FRAME, function(_) for (shape in shapes) drawForeground(shape.graphics));
			#end
			addEventListener(Event.ENTER_FRAME, onFrame);
		});
	}

	function onFrame(_):Void
	{
		if (++frame < 3) return;
		removeEventListener(Event.ENTER_FRAME, onFrame);
		Harness.capture(stage, Score.score, W, H);
	}
}
