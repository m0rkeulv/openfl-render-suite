package;

import rendertest.Compare;
import rendertest.Html;
import rendertest.Pixels;
import rendertest.TestRun;

/**
	Every mode's four cells against the same cells of the AIR window: the live cell (blended in a
	LAYER), the drawn cell (BitmapData.draw of the same layer), the cell on the stage without a
	LAYER, and the container cell. Percent of each cell's pixels off by more than the tolerance,
	with the largest channel difference; the score is the worst cell.

	The circle variant leaves the pixels on the discs' anti-aliased rims (centre within one pixel
	of a rim) out of the percent and the max, since every rasteriser anti-aliases them in its own
	way, and counts them apart as edge pixels.
**/
class Score
{
	static inline var TOLERANCE = 8;
	static inline var CELL = Main.CELL;
	/** Mask colour of an off pixel on a disc rim. **/
	static inline var EDGE_MARK = 0xD99A2B;

	static var KINDS = ["live", "drawn", "stage", "container"];
	static var AIR_KINDS = ["AIR live", "AIR drawn", "AIR stage", "AIR"];

	public static function score(run:TestRun):Void
	{
		var capture = run.capture;
		var air = run.reference("air", "AIR window (reference)", "Every cell of the capture is compared with the same cell of this picture of the AIR window.");
		var rims = run.variant == "_circle" ? rimMask() : null;
		var worst = 0.0;
		var rows:Array<Array<Dynamic>> = [];
		for (i in 0...Main.MODES.length)
		{
			var mode:String = Main.MODES[i];
			var row:Array<Dynamic> = [mode];
			for (kind in 0...KINDS.length)
			{
				var x = cellX(i, kind), y = cellY(i, kind);
				if (rims == null)
				{
					var d = Compare.same(capture, air, x, y, CELL, CELL, TOLERANCE);
					row.push(Html.percent(d.off, d.max));
					if (d.off > worst) worst = d.off;
				}
				else
				{
					var d = rimDifference(capture, air, x, y, rims);
					row.push(Html.value(Math.round(d.off * 1000) / 1000, Html.fixed(d.off, 1) + '% (max ${d.max}, edge ${d.edge})'));
					if (d.off > worst) worst = d.off;
				}
			}
			rows.push(row);
		}
		run.table('Percent of each mode\'s cell pixels differing by more than $TOLERANCE between the two cells of each pair, with the largest channel difference'
			+ (rims != null ? "; pixels on the discs' anti-aliased rims left out and counted apart as edge pixels" : ""),
			["mode"].concat([for (kind in 0...KINDS.length) KINDS[kind] + " vs " + AIR_KINDS[kind]]), rows,
			"live: blended in a LAYER; drawn: BitmapData.draw of it; stage: on the stage without a LAYER; container: on a container.");
		run.score("worst cell", worst, "%", rims != null ? "disc rims left out" : null);

		var mask = Compare.mask(capture, air, TOLERANCE);
		if (rims != null)
		{
			for (i in 0...Main.MODES.length)
				for (kind in 0...KINDS.length)
				{
					var x0 = cellX(i, kind), y0 = cellY(i, kind);
					for (y in 0...CELL)
						for (x in 0...CELL)
							if (rims[y * CELL + x] && capture.channelDiff(x0 + x, y0 + y, air, x0 + x, y0 + y) > TOLERANCE)
								mask.set(x0 + x, y0 + y, EDGE_MARK);
				}
		}
		run.image("mask_air", mask, "Pixels off against AIR" + (rims != null ? ": red inside, amber on a disc rim" : ""), "capture");
	}

	/** Left edge of mode i's cell of `kind` (0 live, 1 drawn, 2 stage, 3 container), as Main lays them out. **/
	static function cellX(i:Int, kind:Int):Int
	{
		return kind == 3 ? (i % 10) * CELL : 8 + Std.int(i / 5) * 240 + CELL * kind;
	}

	static function cellY(i:Int, kind:Int):Int
	{
		return kind == 3 ? 608 + Std.int(i / 10) * CELL : 8 + (i % 5) * CELL;
	}

	/** Per pixel of a cell: true where its centre lies within one pixel of a disc's rim (Main.CIRCLES, foreground at 12, 12). **/
	static function rimMask():Array<Bool>
	{
		var mask = [];
		for (y in 0...CELL)
			for (x in 0...CELL)
			{
				var rim = false;
				for (c in Main.CIRCLES)
				{
					var dx = x + 0.5 - (12 + c.x), dy = y + 0.5 - (12 + c.y);
					if (Math.abs(Math.sqrt(dx * dx + dy * dy) - c.r) < 1.0) rim = true;
				}
				mask.push(rim);
			}
		return mask;
	}

	/** A cell against the same cell of `air` with the rim pixels apart: percent and max inside, the count of off rim pixels. **/
	static function rimDifference(capture:Pixels, air:Pixels, x0:Int, y0:Int, rims:Array<Bool>):{off:Float, max:Int, edge:Int}
	{
		var inside = 0, off = 0, max = 0, edge = 0;
		for (y in 0...CELL)
			for (x in 0...CELL)
			{
				var d = capture.channelDiff(x0 + x, y0 + y, air, x0 + x, y0 + y);
				if (rims[y * CELL + x])
				{
					if (d > TOLERANCE) edge++;
					continue;
				}
				inside++;
				if (d > max) max = d;
				if (d > TOLERANCE) off++;
			}
		return {off: 100.0 * (off / inside), max: max, edge: edge};
	}
}
