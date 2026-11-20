package;

import openfl.display.CapsStyle;
import openfl.display.GradientType;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.geom.Matrix;

/**
	The stage-quality scene (from the quality harness, tools/filter-compare/harness/Main.quality.hx):
	shapes that alias badly (thin diagonals, small circles, rotated squares, stars,
	checkerboards, hairlines, sub-pixel edges) and abutting-fill clouds and a pie on a magenta
	ground, 800 x 600.
**/
class Scene
{
	public static inline var W = 800;
	public static inline var H = 600;
	public static inline var BG = 0xFF00FF;
	static var strokeShapes:Array<Shape> = [];

	public static function buildScene():Sprite
	{
		var s = new Sprite();
		var ground = shape(s);
		ground.graphics.beginFill(BG);
		ground.graphics.drawRect(0, 0, W, H);
		ground.graphics.endFill();

		// 1. line fan: 1 px lines every 10 degrees, then hairlines (thickness 0), then 3 px
		var fan = shape(s);
		strokeShapes.push(fan);
		for (i in 0...10)
		{
			var a = i * Math.PI / 18;
			fan.graphics.lineStyle(1, 0x000000, 1, false, NORMAL, CapsStyle.NONE);
			fan.graphics.moveTo(20, 130);
			fan.graphics.lineTo(20 + 110 * Math.cos(a), 130 - 110 * Math.sin(a));
		}
		for (i in 0...10)
		{
			var a = i * Math.PI / 18;
			fan.graphics.lineStyle(0, 0x0000A0, 1, false, NORMAL, CapsStyle.NONE);
			fan.graphics.moveTo(150, 130);
			fan.graphics.lineTo(150 + 110 * Math.cos(a), 130 - 110 * Math.sin(a));
		}
		for (i in 0...5)
		{
			var a = i * Math.PI / 9;
			fan.graphics.lineStyle(3, 0x006000, 1, false, NORMAL, CapsStyle.NONE);
			fan.graphics.moveTo(280, 130);
			fan.graphics.lineTo(280 + 110 * Math.cos(a), 130 - 110 * Math.sin(a));
		}

		// 2. near-horizontal and near-vertical 1 px lines (slope 1/30)
		var shallow = shape(s);
		strokeShapes.push(shallow);
		shallow.graphics.lineStyle(1, 0x000000, 1, false, NORMAL, CapsStyle.NONE);
		for (i in 0...4)
		{
			shallow.graphics.moveTo(410, 20 + i * 12);
			shallow.graphics.lineTo(530, 24 + i * 12);
		}
		for (i in 0...4)
		{
			shallow.graphics.moveTo(550 + i * 12, 20);
			shallow.graphics.lineTo(554 + i * 12, 140);
		}

		// 3. filled circles r = 2..12 and 1 px rings, one 0.5 px ring
		var circles = shape(s);
		var x = 630.0;
		for (r in [2, 3, 5, 8, 12])
		{
			circles.graphics.beginFill(0x000080);
			circles.graphics.drawCircle(x, 40, r);
			circles.graphics.endFill();
			x += r * 2 + 10;
		}
		var rings = shape(s);
		strokeShapes.push(rings);
		x = 630.0;
		for (r in [6, 10, 16])
		{
			rings.graphics.lineStyle(1, 0x000000);
			rings.graphics.drawCircle(x, 100, r);
			x += r * 2 + 12;
		}
		rings.graphics.lineStyle(0.5, 0x000000);
		rings.graphics.drawCircle(760, 100, 14);

		// 4. rotated squares (10, 22.5, 45 degrees) and 5-point stars
		var polys = shape(s);
		var px = 40.0;
		for (deg in [10.0, 22.5, 45.0])
		{
			polygon(polys, px, 200, 4, 22, deg * Math.PI / 180 + Math.PI / 4, 0x0000FF);
			px += 70;
		}
		star(polys, 300, 200, 5, 16, 7, 0x008000);
		star(polys, 380, 200, 5, 42, 18, 0x008000);
		star(polys, 470, 200, 7, 30, 12, 0x404000);

		// 5. curves: S strokes 1 px and 2 px, and a thin filled crescent
		var curves = shape(s);
		strokeShapes.push(curves);
		curves.graphics.lineStyle(1, 0x000000);
		curves.graphics.moveTo(520, 250);
		curves.graphics.curveTo(560, 150, 600, 200);
		curves.graphics.curveTo(640, 250, 680, 150);
		curves.graphics.lineStyle(2, 0x000000);
		curves.graphics.moveTo(520, 260);
		curves.graphics.curveTo(560, 160, 600, 210);
		curves.graphics.curveTo(640, 260, 680, 160);
		var crescent = shape(s);
		crescent.graphics.beginFill(0x800000);
		crescent.graphics.moveTo(720, 160);
		crescent.graphics.curveTo(780, 200, 720, 250);
		crescent.graphics.curveTo(760, 200, 720, 160);
		crescent.graphics.endFill();

		// 6. checkerboards: 2 px and 3 px cells, and 1 px lines at fractional x
		var checks = shape(s);
		for (cy in 0...12)
			for (cx in 0...12)
				if ((cx + cy) % 2 == 0)
				{
					checks.graphics.beginFill(0x000000);
					checks.graphics.drawRect(20 + cx * 2, 260 + cy * 2, 2, 2);
					checks.graphics.endFill();
				}
		for (cy in 0...8)
			for (cx in 0...8)
				if ((cx + cy) % 2 == 0)
				{
					checks.graphics.beginFill(0x000000);
					checks.graphics.drawRect(60 + cx * 3, 260 + cy * 3, 3, 3);
					checks.graphics.endFill();
				}
		for (i in 0...6)
		{
			checks.graphics.beginFill(0x000000);
			checks.graphics.drawRect(100 + i * 6 + i * 0.25, 260, 1, 30);
			checks.graphics.endFill();
		}

		// 7. gradient-filled rotated rect and radial circle, translucent overlaps
		var grad = shape(s);
		var m = new Matrix();
		m.createGradientBox(80, 40, Math.PI / 6, 160, 255);
		grad.graphics.beginGradientFill(GradientType.LINEAR, [0x0000FF, 0x00FF00], [1, 1], [0, 255], m);
		polygon(grad, 200, 275, 4, 34, Math.PI / 6 + Math.PI / 4, 0);
		grad.graphics.endFill();
		m.createGradientBox(60, 60, 0, 250, 245);
		grad.graphics.beginGradientFill(GradientType.RADIAL, [0xFFFF00, 0x004000], [1, 1], [0, 255], m);
		grad.graphics.drawCircle(280, 275, 30);
		grad.graphics.endFill();
		for (i in 0...3)
		{
			grad.graphics.beginFill([0x0000FF, 0x00FF00, 0xFFFF00][i], 0.5);
			grad.graphics.drawCircle(350 + i * 18, 275, 22);
			grad.graphics.endFill();
		}

		// 8. bleed test A: pie of 12 abutting wedges (one Graphics), no magenta in any fill
		var pie = shape(s);
		// no fill has any blue, so blue inside a body can only be the magenta background bleeding through a seam
		var cols = [0x00C000, 0xFFFF00, 0xFF8000, 0x404000, 0x80FF00, 0xC0C000];
		for (i in 0...12)
		{
			var a0 = i * Math.PI / 6, a1 = (i + 1) * Math.PI / 6;
			pie.graphics.beginFill(cols[i % cols.length]);
			pie.graphics.moveTo(560, 330);
			pie.graphics.lineTo(560 + 80 * Math.cos(a0), 330 + 80 * Math.sin(a0));
			// curved rim so the seams are also curved-vs-straight
			pie.graphics.curveTo(560 + 84 * Math.cos((a0 + a1) / 2), 330 + 84 * Math.sin((a0 + a1) / 2), 560 + 80 * Math.cos(a1), 330 + 80 * Math.sin(a1));
			pie.graphics.lineTo(560, 330);
			pie.graphics.endFill();
		}

		// 9. bleed test B: cloud of abutting jittered quads sharing vertices (one Graphics)
		var cloud = shape(s);
		var nx = 7, ny = 4, cw = 28, ch = 36;
		var vx = [], vy = [];
		for (j in 0...ny + 1)
			for (i in 0...nx + 1)
			{
				var jitterX = Math.sin(i * 1.7 + j * 2.3) * 7;
				var jitterY = Math.cos(i * 2.1 + j * 1.3) * 7;
				vx.push(40 + i * cw + jitterX);
				vy.push(430 + j * ch + jitterY);
			}
		for (j in 0...ny)
			for (i in 0...nx)
			{
				var k = i + j * (nx + 1);
				cloud.graphics.beginFill(cols[(i * 3 + j * 5) % cols.length]);
				cloud.graphics.moveTo(vx[k], vy[k]);
				cloud.graphics.lineTo(vx[k + 1], vy[k + 1]);
				cloud.graphics.lineTo(vx[k + nx + 2], vy[k + nx + 2]);
				cloud.graphics.lineTo(vx[k + nx + 1], vy[k + nx + 1]);
				cloud.graphics.lineTo(vx[k], vy[k]);
				cloud.graphics.endFill();
			}

		// 10. bleed test C: the same cloud drawn scaled 3x (bleed is worst on scaled shapes)
		var big = shape(s);
		for (j in 0...ny)
			for (i in 0...nx)
			{
				var k = i + j * (nx + 1);
				big.graphics.beginFill(cols[(i * 3 + j * 5) % cols.length]);
				big.graphics.moveTo(vx[k], vy[k]);
				big.graphics.lineTo(vx[k + 1], vy[k + 1]);
				big.graphics.lineTo(vx[k + nx + 2], vy[k + nx + 2]);
				big.graphics.lineTo(vx[k + nx + 1], vy[k + nx + 1]);
				big.graphics.lineTo(vx[k], vy[k]);
				big.graphics.endFill();
			}
		big.scaleX = big.scaleY = 1.35;
		big.x = 270 - 40 * 1.35;
		big.y = 400 - 430 * 1.35;
		big.rotation = 7;

		// 11. tiny text-like glyph strokes: 1 px rectangles and a small triangle fan
		var glyphs = shape(s);
		for (i in 0...10)
		{
			glyphs.graphics.beginFill(0x000000);
			glyphs.graphics.drawRect(660 + i * 12, 440 + (i % 3) * 0.5, 1, 40);
			glyphs.graphics.endFill();
			glyphs.graphics.beginFill(0x000000);
			glyphs.graphics.drawRect(660, 500 + i * 6 + (i % 4) * 0.25, 120, 1);
			glyphs.graphics.endFill();
		}
		return s;
	}


	// ---- the text scene (-D fsaa_text) ------------------------------------

	static inline var SAMPLE = "Quick brown fox 0123 Jjgq";

	static function shape(parent:Sprite):Shape
	{
		var sh = new Shape();
		parent.addChild(sh);
		return sh;
	}

	static function polygon(sh:Shape, cx:Float, cy:Float, n:Int, r:Float, rot:Float, color:Int):Void
	{
		if (color != 0) sh.graphics.beginFill(color);
		for (i in 0...n + 1)
		{
			var a = rot + i * 2 * Math.PI / n;
			if (i == 0) sh.graphics.moveTo(cx + r * Math.cos(a), cy + r * Math.sin(a));
			else sh.graphics.lineTo(cx + r * Math.cos(a), cy + r * Math.sin(a));
		}
		if (color != 0) sh.graphics.endFill();
	}

	static function star(sh:Shape, cx:Float, cy:Float, points:Int, outer:Float, inner:Float, color:Int):Void
	{
		sh.graphics.beginFill(color);
		for (i in 0...points * 2 + 1)
		{
			var r = (i % 2 == 0) ? outer : inner;
			var a = -Math.PI / 2 + i * Math.PI / points;
			if (i == 0) sh.graphics.moveTo(cx + r * Math.cos(a), cy + r * Math.sin(a));
			else sh.graphics.lineTo(cx + r * Math.cos(a), cy + r * Math.sin(a));
		}
		sh.graphics.endFill();
	}
}
