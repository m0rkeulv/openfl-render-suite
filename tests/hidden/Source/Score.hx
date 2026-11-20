package;

import rendertest.Compare;
import rendertest.Html;
import rendertest.TestRun;

/**
	Every row against the AIR window, cell by cell, and every placeholder row against the capture's
	own row 0 (the disc as it is). Percent of each cell's pixels off by more than the tolerance;
	the score is the worst cell against AIR.
**/
class Score
{
	static inline var TOLERANCE = 8;
	static inline var CELL = Main.CELL;
	static var ROWS = ["no placeholder", "visible = false", "alpha = 0", "invisible child"];

	public static function score(run:TestRun):Void
	{
		var capture = run.capture;
		var air = run.reference("air", "AIR window (reference)", "The capture is compared with this picture of the AIR window.");
		var modes = [for (mode in Main.MODES) (mode : String).toUpperCase()];
		var worst = 0.0;
		var rows:Array<Array<Dynamic>> = [];
		for (row in 0...ROWS.length)
		{
			var values = [for (column in 0...modes.length) Compare.same(capture, air, column * CELL, row * CELL, CELL, CELL, TOLERANCE).off];
			for (v in values) if (v > worst) worst = v;
			rows.push(([ROWS[row] + " vs AIR"] : Array<Dynamic>).concat([for (v in values) Html.percent(v)]));
		}
		for (row in 1...ROWS.length)
		{
			var values = [
				for (column in 0...modes.length)
					Compare.region(capture, column * CELL, row * CELL, capture, column * CELL, 0, CELL, CELL, TOLERANCE).off
			];
			rows.push(([ROWS[row] + " vs own row 0"] : Array<Dynamic>).concat([for (v in values) Html.percent(v)]));
		}
		run.table('Percent of each cell\'s pixels off by more than $TOLERANCE: every row against the AIR window, and every placeholder row against the capture\'s own row 0 (the disc as it is)',
			["comparison"].concat(modes), rows);
		run.score("worst cell vs AIR", worst, "%");
		run.image("mask_air", Compare.mask(capture, air, TOLERANCE), "Pixels off against AIR", "capture");
	}
}
