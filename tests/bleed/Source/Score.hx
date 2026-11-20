package;

import openfl.display.StageQuality;
import rendertest.Html;
import rendertest.Pixels;
import rendertest.TestRun;

/**
	Bleed: no fill in the art has any blue and the ground is magenta, so a pixel inside an element
	with blue over 8 is ground showing through a seam. The elements' body is the non-magenta area
	of AIR's LOW render at the same scale, eroded by 3 px per scale unit so the anti-aliased outer
	edge of an element does not count. Reported as percent of the body, overall and per element,
	with the mean channel difference against AIR at the same quality.
**/
class Score
{
	static inline var BLUE = 8;
	static inline var ZOOM = 8;
	static inline var CYAN = 0x00FFFF;

	/** Seam junctions shown 8x: name => [x0, y0, x1, y1] at scale 1. **/
	static var ZOOMS:Array<{name:String, box:Array<Int>}> = [
		{name: "cloud", box: [60, 60, 110, 95]},
		{name: "pie", box: [380, 90, 420, 130]},
		{name: "samecolour", box: [80, 360, 140, 400]},
		{name: "rings", box: [380, 400, 430, 440]},
		{name: "tinycloud", box: [545, 365, 595, 400]}
	];

	public static function score(run:TestRun):Void
	{
		var worst = 0.0, worstName = "";
		var rows:Array<Array<Dynamic>> = [];
		var regionRows:Array<Array<Dynamic>> = [];
		for (scale in Main.SCALES)
		{
			var body = bodyMask(run.reference("air_low_x" + scale, "AIR, LOW, scale " + scale), 3 * scale);
			for (quality in Main.QUALITIES)
			{
				var name = Main.renderName(quality, scale);
				var render = Main.renders.get(name);
				var air = run.reference("air_" + name, 'AIR, ${Std.string(quality)}, scale $scale');
				var bodyCount = 0, bleedCount = 0;
				for (i in 0...body.length)
					if (body[i])
					{
						bodyCount++;
						if (render.blue(i % render.width, Std.int(i / render.width)) > BLUE) bleedCount++;
					}
				var percent = bodyCount > 0 ? 100.0 * bleedCount / bodyCount : 0.0;
				var delta = meanDifference(render, air);
				rows.push([Std.string(quality), scale, Html.percent(percent), bleedCount, Html.value(delta, Html.fixed(delta, 2))]);
				if (percent > worst || worstName == "")
				{
					worst = percent;
					worstName = name;
				}
				if (scale == 1)
					for (region in BleedTestArt.regions)
					{
						var count = 0, inside = 0;
						for (y in region.y...region.y + region.height)
							for (x in region.x...region.x + region.width)
								if (x < render.width && y < render.height && body[y * render.width + x])
								{
									inside++;
									if (render.blue(x, y) > BLUE) count++;
								}
						regionRows.push([region.name, Std.string(quality), Html.percent(inside > 0 ? 100.0 * count / inside : 0)]);
					}
				if (scale == 1 || quality == StageQuality.HIGH)
					run.image("highlight_" + name, highlight(render, body, BLUE), 'Bleed pixels in cyan, ${Std.string(quality)}, scale $scale', "highlight " + name);
				if (scale == 1 && (quality == StageQuality.LOW || quality == StageQuality.HIGH))
					for (zoom in ZOOMS)
						run.image('zoom_${zoom.name}_${Std.string(quality).toLowerCase()}', sideBySide(air, render, zoom.box),
							'${zoom.name}, ${Std.string(quality)}: AIR (left) and this run, ${ZOOM}x', "zoom " + zoom.name);
			}
		}
		run.table('Bleed: percent of the elements\' body with blue over $BLUE (ground showing through a seam), and the mean channel difference against AIR at the same quality',
			["quality", "scale", "bleed", "bleed pixels", "mean difference vs AIR"], rows);
		run.table("Bleed per element at scale 1", ["element", "quality", "bleed"], regionRows);
		run.score("bleed", worst, "%", "the worst of the eight renders (" + worstName + ")");
	}

	/** Not magenta in AIR's LOW render (hard edges, no bleed), eroded `iterations` times with a cross. **/
	static function bodyMask(low:Pixels, iterations:Int):Array<Bool>
	{
		var w = low.width, h = low.height;
		var mask = [
			for (y in 0...h)
				for (x in 0...w)
					!(low.red(x, y) > 200 && low.blue(x, y) > 200 && low.green(x, y) < 80)
		];
		for (step in 0...iterations)
		{
			var next = mask.copy();
			for (y in 0...h)
				for (x in 0...w)
				{
					var i = y * w + x;
					if (!mask[i]) continue;
					// outside the image counts as ground, as in scipy's binary_erosion
					if (x == 0 || y == 0 || x == w - 1 || y == h - 1 || !mask[i - 1] || !mask[i + 1] || !mask[i - w] || !mask[i + w]) next[i] = false;
				}
			mask = next;
		}
		return mask;
	}

	/** The mean absolute difference over every channel of every pixel. **/
	static function meanDifference(a:Pixels, b:Pixels):Float
	{
		var sum = 0.0;
		for (y in 0...a.height)
			for (x in 0...a.width)
				sum += Math.abs(a.red(x, y) - b.red(x, y)) + Math.abs(a.green(x, y) - b.green(x, y)) + Math.abs(a.blue(x, y) - b.blue(x, y));
		return sum / (a.width * a.height * 3);
	}

	/** The render dimmed to grey with the bleed pixels in cyan. **/
	static function highlight(render:Pixels, body:Array<Bool>, blue:Int):Pixels
	{
		var out = new Pixels(render.width, render.height);
		for (y in 0...render.height)
			for (x in 0...render.width)
			{
				if (body[y * render.width + x] && render.blue(x, y) > blue)
				{
					out.set(x, y, CYAN);
				}
				else
				{
					var grey = Std.int((render.red(x, y) + render.green(x, y) + render.blue(x, y)) / 3 * 0.35 + 20);
					out.set(x, y, (grey << 16) | (grey << 8) | grey);
				}
			}
		return out;
	}

	/** The box of `left` and of `right`, each enlarged ZOOM times, 12 px apart. **/
	static function sideBySide(left:Pixels, right:Pixels, box:Array<Int>):Pixels
	{
		var w = box[2] - box[0], h = box[3] - box[1];
		var out = Pixels.filled(2 * w * ZOOM + 12, h * ZOOM, 0x18181C);
		out.paste(left.crop(box[0], box[1], w, h).scaled(ZOOM), 0, 0);
		out.paste(right.crop(box[0], box[1], w, h).scaled(ZOOM), w * ZOOM + 12, 0);
		return out;
	}
}
