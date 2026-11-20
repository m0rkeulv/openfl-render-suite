package;

import rendertest.Compare;
import rendertest.Html;
import rendertest.TestRun;

/**
	Every cell against the AIR window: percent of its pixels off by more than the tolerance. The
	score is the worst cell.
**/
class Score
{
	static inline var TOLERANCE = 8;
	static inline var CELL = Main.CELL;
	static var COLUMNS = ["ALPHA", "ERASE", "SUBTRACT", "INVERT", "ADD container"];
	static var ROWS = ["transparent bitmap", "opaque bitmap"];

	public static function score(run:TestRun):Void
	{
		var capture = run.capture;
		var air = run.reference("air", "AIR window (reference)", "Every cell of the capture is compared with this picture of the AIR window.");
		var worst = 0.0;
		var rows:Array<Array<Dynamic>> = [];
		for (r in 0...ROWS.length)
		{
			var row:Array<Dynamic> = [ROWS[r]];
			for (column in 0...COLUMNS.length)
			{
				var d = Compare.same(capture, air, column * CELL, r * CELL, CELL, CELL, TOLERANCE);
				row.push(Html.percent(d.off));
				if (d.off > worst) worst = d.off;
			}
			rows.push(row);
		}
		run.table('Percent of each cell\'s pixels off the AIR window by more than $TOLERANCE', ["bitmap"].concat(COLUMNS), rows);
		run.score("worst cell", worst, "%", "worst cell against the AIR window");
		run.image("mask_air", Compare.mask(capture, air, TOLERANCE), "Pixels differing from AIR", "capture");
	}
}
