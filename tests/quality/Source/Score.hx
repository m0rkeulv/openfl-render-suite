package;

import rendertest.Html;
import rendertest.Pixels;
import rendertest.TestRun;

/**
	Each quality's render against AIR at the same quality: the mean channel difference (0 to 255)
	over the whole scene and over the edge pixels only (where AIR's LOW and BEST differ, so where
	anti-aliasing acts), per element, and the bleed of the abutting-fill elements: the share of
	their body (from AIR LOW, eroded by 3 px) whose blue is over 8, which is ground showing
	through a seam (no fill there has any blue).
**/
class Score
{
	static inline var BLUE = 8;

	/** Elements of the scene: name, x0, y0, x1, y1. **/
	static var REGIONS:Array<{name:String, box:Array<Int>}> = [
		{name: "fan", box: [0, 0, 400, 150]},
		{name: "shallow", box: [400, 0, 620, 150]},
		{name: "circles", box: [620, 0, 800, 150]},
		{name: "polys", box: [0, 150, 520, 250]},
		{name: "curves", box: [510, 140, 800, 260]},
		{name: "checks", box: [0, 250, 140, 300]},
		{name: "grad", box: [150, 240, 420, 310]},
		{name: "pie", box: [470, 240, 650, 420]},
		{name: "clouds", box: [20, 380, 480, 600]},
		{name: "glyphs", box: [650, 430, 800, 560]}
	];

	public static function score(run:TestRun):Void
	{
		var air = [for (q in Main.QUALITIES) Std.string(q).toLowerCase() => run.reference("air_" + Std.string(q).toLowerCase(), "AIR, " + Std.string(q))];
		var low = air.get("low"), best = air.get("best");
		var w = low.width, h = low.height;
		var edge = [for (y in 0...h) for (x in 0...w) low.get(x, y) != best.get(x, y)];
		var interior = bleedInterior(low);
		var rows:Array<Array<Dynamic>> = [];
		var regionRows:Array<Array<Dynamic>> = [];
		var worstBleed = 0.0;
		var edgeByQuality:Array<Float> = [];
		for (q in Main.QUALITIES)
		{
			var name = Std.string(q).toLowerCase();
			var render = Main.renders.get(name);
			var reference = air.get(name);
			var all = meanDifference(render, reference, null);
			var edgeOnly = meanDifference(render, reference, edge);
			var bleed = bleedPercent(render, interior);
			rows.push([Std.string(q), Html.value(all, Html.fixed(all, 2)), Html.value(edgeOnly, Html.fixed(edgeOnly, 2)), Html.percent(bleed),
				Html.percent(bleedPercent(reference, interior))]);
			edgeByQuality.push(edgeOnly);
			if (bleed > worstBleed) worstBleed = bleed;
			var row:Array<Dynamic> = [Std.string(q)];
			for (region in REGIONS)
			{
				var b = region.box;
				var d = regionDifference(render, reference, b[0], b[1], b[2], b[3]);
				row.push(Html.value(d, Html.fixed(d, 2)));
			}
			regionRows.push(row);
			run.image("render_" + name, render, "This run, " + Std.string(q), "render " + name);
		}
		run.table("Mean channel difference (0 to 255) against AIR at the same quality, over the whole scene and over the edge pixels (where AIR LOW and BEST differ); bleed of the abutting-fill elements",
			["quality", "whole scene", "edge pixels", "bleed", "AIR's own bleed"], rows);
		run.table("Mean channel difference per element against AIR at the same quality", ["quality"].concat([for (r in REGIONS) r.name]), regionRows);
		run.score("bleed", worstBleed, "%", "the worst quality");
		for (i in 0...Main.QUALITIES.length)
			run.score("edge " + Std.string(Main.QUALITIES[i]), edgeByQuality[i], "", "mean channel difference over the anti-aliased edge pixels, 0 to 255");
	}

	/** The body of the bleed elements (pie, small and big cloud) in AIR LOW, eroded 3 times with a cross. **/
	static function bleedInterior(low:Pixels):Array<Bool>
	{
		var w = low.width, h = low.height;
		var mask = [
			for (y in 0...h)
				for (x in 0...w)
				{
					var ground = low.red(x, y) > 200 && low.blue(x, y) > 200 && low.green(x, y) < 80;
					var inPie = (x - 560) * (x - 560) + (y - 330) * (y - 330) < 78 * 78;
					var inSmallCloud = x >= 30 && x <= 250 && y >= 415 && y <= 590;
					var inBigCloud = x >= 170 && x <= 480 && y >= 385 && y <= 600;
					!ground && (inPie || inSmallCloud || inBigCloud);
				}
		];
		for (step in 0...3)
		{
			var next = mask.copy();
			for (y in 0...h)
				for (x in 0...w)
				{
					var i = y * w + x;
					if (mask[i] && (x == 0 || y == 0 || x == w - 1 || y == h - 1 || !mask[i - 1] || !mask[i + 1] || !mask[i - w] || !mask[i + w]))
						next[i] = false;
				}
			mask = next;
		}
		return mask;
	}

	static function bleedPercent(image:Pixels, interior:Array<Bool>):Float
	{
		var inside = 0, bleed = 0;
		for (i in 0...interior.length)
			if (interior[i])
			{
				inside++;
				if (image.blue(i % image.width, Std.int(i / image.width)) > BLUE) bleed++;
			}
		return inside > 0 ? 100.0 * bleed / inside : 0;
	}

	/** Mean absolute channel difference over the pixels where `mask` is true (every pixel without one). **/
	static function meanDifference(a:Pixels, b:Pixels, mask:Array<Bool>):Float
	{
		var sum = 0.0, count = 0;
		for (y in 0...a.height)
			for (x in 0...a.width)
			{
				if (mask != null && !mask[y * a.width + x]) continue;
				sum += Math.abs(a.red(x, y) - b.red(x, y)) + Math.abs(a.green(x, y) - b.green(x, y)) + Math.abs(a.blue(x, y) - b.blue(x, y));
				count++;
			}
		return count > 0 ? sum / (count * 3) : 0;
	}

	static function regionDifference(a:Pixels, b:Pixels, x0:Int, y0:Int, x1:Int, y1:Int):Float
	{
		var sum = 0.0;
		for (y in y0...y1)
			for (x in x0...x1)
				sum += Math.abs(a.red(x, y) - b.red(x, y)) + Math.abs(a.green(x, y) - b.green(x, y)) + Math.abs(a.blue(x, y) - b.blue(x, y));
		return sum / ((x1 - x0) * (y1 - y0) * 3);
	}
}
