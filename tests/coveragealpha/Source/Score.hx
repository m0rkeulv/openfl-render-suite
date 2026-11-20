package;

import rendertest.Compare;
import rendertest.Html;
import rendertest.TestRun;

/**
	Within the capture the case row (object alpha 0.5, opaque fill) against the reference row
	(object alpha 1, fill 0.5), which must be the same picture on the same renderer, rims
	included; and both rows against the AIR window for information (rims differ by rasteriser).
	Percent and count of each cell's pixels off by more than the tolerance; the score is the
	worst cell of the case row against the reference row.
**/
class Score
{
	static inline var TOLERANCE = 8;
	static inline var CELL = Main.CELL;
	static var COLUMNS = ["container, disc", "container, square", "disc alone"];

	public static function score(run:TestRun):Void
	{
		var capture = run.capture;
		var air = run.reference("air", "AIR window (reference)", "Both rows of the capture are compared with this picture of the AIR window.");
		var worst = 0.0;
		var rows:Array<Array<Dynamic>> = [];
		for (what in ["case row vs reference row", "reference row vs AIR", "case row vs AIR"])
		{
			var row:Array<Dynamic> = [what];
			for (column in 0...COLUMNS.length)
			{
				var x = column * CELL;
				var d = switch (what)
				{
					case "case row vs reference row": Compare.region(capture, x, CELL, capture, x, 0, CELL, CELL, TOLERANCE);
					case "reference row vs AIR": Compare.same(capture, air, x, 0, CELL, CELL, TOLERANCE);
					default: Compare.same(capture, air, x, CELL, CELL, CELL, TOLERANCE);
				}
				row.push(Html.value(Math.round(d.off * 1000) / 1000, Html.fixed(d.off, 1) + '% (${d.count} px)'));
				if (what == "case row vs reference row" && d.off > worst) worst = d.off;
			}
			rows.push(row);
		}
		run.table('Percent (and count) of each cell\'s pixels off by more than $TOLERANCE: the case row (object alpha 0.5) against the reference row (fill alpha 0.5) of the same capture, and both rows against the AIR window',
			["comparison"].concat(COLUMNS), rows,
			"The case row must match the capture's own reference row, rims included; against AIR the rims differ by rasterizer.");
		run.score("worst cell", worst, "%", "worst cell, case row against the capture's own reference row");
		run.image("mask_air", Compare.mask(capture, air, TOLERANCE), "Pixels off against AIR", "capture");
		run.image("mask_rows", Compare.mask(capture, capture, TOLERANCE, 0, CELL, capture.width, CELL, 0, 0),
			"Case row: pixels off against the reference row", "rows");
	}
}
