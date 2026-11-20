package;

import rendertest.Html;
import rendertest.Pixels;
import rendertest.TestRun;

/**
	Each case's live cell against AIR's live cell and its applyFilter cell against AIR's
	applyFilter cell (the two AIR cells differ: filter bounds follow the vector shape, not the
	160 x 160 bitmap). The measure is the mean absolute channel difference over the 160 x 160
	cell (0 to 255): matching filters sit at 0.0 to 0.7, a visibly wrong one at 8 to 17.
**/
class Score
{
	static inline var CELL = Main.CELL;
	static inline var GAP = 40;
	/** The signed difference image: 128 + 8 x (capture - AIR). **/
	static inline var GAIN = 8;

	public static function score(run:TestRun):Void
	{
		var air = run.reference("air", "AIR, the full sweep (reference)",
			"BitmapData.draw of AIR's stage with every case; each page is compared with the same cases here.");
		var page = Main.page();
		var first = page >= 0 ? page * Main.PER_PAGE : 0;
		var last = page >= 0 ? Std.int(Math.min(first + Main.PER_PAGE, Main.CASES.length)) : Main.CASES.length;
		var difference = Pixels.filled(run.capture.width, run.capture.height, 0x303030);
		var rows:Array<Array<Dynamic>> = [];
		var worstLive = 0.0, worstSoftware = 0.0;
		var missing:Array<String> = [];
		for (i in first...last)
		{
			if (Main.CASES[i].make() == null)
			{
				missing.push(Main.CASES[i].label);
				rows.push([i + 1, Main.CASES[i].family, Main.CASES[i].label, "not in this openfl", "not in this openfl", null]);
				continue;
			}
			var shown = Main.cellOrigin(i - first);
			var reference = Main.cellOrigin(i);
			var sx = Std.int(shown.x), sy = Std.int(shown.y), ax = Std.int(reference.x), ay = Std.int(reference.y);
			var live = cellDifference(run.capture, sx, sy, air, ax, ay);
			var software = cellDifference(run.capture, sx + CELL + GAP, sy, air, ax + CELL + GAP, ay);
			var airSelf = cellDifference(air, ax + CELL + GAP, ay, air, ax, ay);
			paintDifference(difference, run.capture, sx, sy, air, ax, ay);
			paintDifference(difference, run.capture, sx + CELL + GAP, sy, air, ax + CELL + GAP, ay);
			rows.push([
				i + 1,
				Main.CASES[i].family,
				Main.CASES[i].label,
				Html.value(live.mean, Html.fixed(live.mean, 2) + " (max " + live.max + ")"),
				Html.value(software.mean, Html.fixed(software.mean, 2) + " (max " + software.max + ")"),
				Html.value(airSelf.mean, Html.fixed(airSelf.mean, 2))
			]);
			if (live.mean > worstLive) worstLive = live.mean;
			if (software.mean > worstSoftware) worstSoftware = software.mean;
		}
		run.table("Mean channel difference against AIR over each 160 x 160 cell (0 to 255; matching filters sit at 0.0 to 0.7)",
			["case", "filter", "settings", "live shape", "applyFilter", "AIR: applyFilter vs live"], rows);
		run.score("worst live cell", worstLive, "", "mean channel difference, 0 to 255");
		run.score("worst applyFilter cell", worstSoftware, "", "mean channel difference, 0 to 255");
		run.score("cases not available", missing.length, "cases", "filters this openfl does not have" + (missing.length > 0 ? ": " + missing.join(", ") : ""));
		run.image("difference", difference, 'Each cell\'s difference against AIR: grey is equal, lighter or darker is off (x$GAIN)', "capture");
	}

	static function cellDifference(a:Pixels, ax:Int, ay:Int, b:Pixels, bx:Int, by:Int):{mean:Float, max:Int}
	{
		var sum = 0.0, max = 0;
		for (y in 0...CELL)
			for (x in 0...CELL)
			{
				var dr = Std.int(Math.abs(a.red(ax + x, ay + y) - b.red(bx + x, by + y)));
				var dg = Std.int(Math.abs(a.green(ax + x, ay + y) - b.green(bx + x, by + y)));
				var db = Std.int(Math.abs(a.blue(ax + x, ay + y) - b.blue(bx + x, by + y)));
				sum += dr + dg + db;
				if (dr > max) max = dr;
				if (dg > max) max = dg;
				if (db > max) max = db;
			}
		return {mean: sum / (CELL * CELL * 3), max: max};
	}

	/** Paints the signed difference of a cell at its place in `out` (the capture's layout). **/
	static function paintDifference(out:Pixels, a:Pixels, ax:Int, ay:Int, b:Pixels, bx:Int, by:Int):Void
	{
		for (y in 0...CELL)
			for (x in 0...CELL)
			{
				var r = signed(a.red(ax + x, ay + y) - b.red(bx + x, by + y));
				var g = signed(a.green(ax + x, ay + y) - b.green(bx + x, by + y));
				var bl = signed(a.blue(ax + x, ay + y) - b.blue(bx + x, by + y));
				out.set(ax + x, ay + y, (r << 16) | (g << 8) | bl);
			}
	}

	static inline function signed(delta:Int):Int
	{
		var v = 128 + delta * GAIN;
		return v < 0 ? 0 : (v > 255 ? 255 : v);
	}
}
