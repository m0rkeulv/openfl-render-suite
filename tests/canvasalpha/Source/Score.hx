package;

import rendertest.Compare;
import rendertest.Html;
import rendertest.TestRun;

/**
	Within the capture the container row against the row of separate objects (they must be the
	same picture), and both rows against the AIR window. Percent of each cell's pixels off by more
	than the tolerance; the score is the worst cell.
**/
class Score
{
	static inline var TOLERANCE = 8;
	static inline var CELL = Main.CELL;

	public static function score(run:TestRun):Void
	{
		var capture = run.capture;
		var air = run.reference("air", "AIR window (reference)", "Both rows of the capture are compared with this picture of the AIR window.");
		var modes = [for (mode in Main.MODES) (mode : String).toUpperCase()];
		var worst = 0.0;
		var rows:Array<Array<Dynamic>> = [];
		for (what in ["container row vs separate row", "separate row vs AIR", "container row vs AIR"])
		{
			var row:Array<Dynamic> = [what];
			for (column in 0...modes.length)
			{
				var x = column * CELL;
				var d = switch (what)
				{
					case "container row vs separate row": Compare.region(capture, x, CELL, capture, x, 0, CELL, CELL, TOLERANCE);
					case "separate row vs AIR": Compare.same(capture, air, x, 0, CELL, CELL, TOLERANCE);
					default: Compare.same(capture, air, x, CELL, CELL, CELL, TOLERANCE);
				}
				row.push(Html.percent(d.off));
				if (d.off > worst) worst = d.off;
			}
			rows.push(row);
		}
		run.table('Percent of each cell\'s pixels off by more than $TOLERANCE: the container row against the row of separate objects in the same capture, and both rows against the AIR window',
			["comparison"].concat(modes), rows);
		run.score("worst cell", worst, "%", "worst cell over all three comparisons");
		run.image("mask_air", Compare.mask(capture, air, TOLERANCE), "Pixels off against AIR", "capture");
		run.image("mask_rows", Compare.mask(capture, capture, TOLERANCE, 0, CELL, capture.width, CELL, 0, 0),
			"Container row: pixels off against the separate row", "rows");
	}
}
