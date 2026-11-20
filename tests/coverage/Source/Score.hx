package;

import rendertest.Compare;
import rendertest.Html;
import rendertest.TestRun;

/**
	Within the capture the redrawn row against the static row (they must be the same picture),
	and both rows against the AIR window. Percent of each cell's pixels off by more than the
	tolerance; the score is the worst cell.
**/
class Score
{
	static inline var TOLERANCE = 8;
	static inline var CELL = Main.CELL;
	static var COLUMNS = ["ALPHA in LAYER", "ALPHA on stage", "ALPHA container", "NORMAL"];

	public static function score(run:TestRun):Void
	{
		var capture = run.capture;
		var air = run.reference("air", "AIR window (reference)", "Both rows of the capture are compared with this picture of the AIR window.");
		var worst = 0.0;
		var rows:Array<Array<Dynamic>> = [];
		for (what in ["redrawn row vs static row", "static row vs AIR", "redrawn row vs AIR"])
		{
			var row:Array<Dynamic> = [what];
			for (column in 0...COLUMNS.length)
			{
				var x = column * CELL;
				var d = switch (what)
				{
					case "redrawn row vs static row": Compare.region(capture, x, CELL, capture, x, 0, CELL, CELL, TOLERANCE);
					case "static row vs AIR": Compare.same(capture, air, x, 0, CELL, CELL, TOLERANCE);
					default: Compare.same(capture, air, x, CELL, CELL, CELL, TOLERANCE);
				}
				row.push(Html.percent(d.off));
				if (d.off > worst) worst = d.off;
			}
			rows.push(row);
		}
		run.table('Percent of each cell\'s pixels off by more than $TOLERANCE: the redrawn row against the static row of the same capture, and both rows against the AIR window',
			["comparison"].concat(COLUMNS), rows);
		run.score("worst cell", worst, "%", "over all three comparisons");
		run.image("mask_air", Compare.mask(capture, air, TOLERANCE), "Pixels off against AIR", "capture");
		run.image("mask_rows", Compare.mask(capture, capture, TOLERANCE, 0, CELL, capture.width, CELL, 0, 0),
			"Redrawn row: pixels off against the static row", "rows");
	}
}
