package;

import rendertest.Compare;
import rendertest.Html;
import rendertest.TestRun;

/**
	Within the capture the case row (the shape came under ALPHA after its render, so its coverage
	is made on its own) against the control row (the shape was created with ALPHA, so its coverage
	came from the full render), which must be the same picture, and both rows against the AIR
	window. Percent and count of each cell's pixels off by more than the tolerance; the score is
	the worst cell of the case row against the control row.
**/
class Score
{
	static inline var TOLERANCE = 8;
	static inline var CELL = Main.CELL;
	static var COLUMNS = ["in a LAYER", "on the stage"];

	public static function score(run:TestRun):Void
	{
		var capture = run.capture;
		var air = run.reference("air", "AIR window (reference)", "Both rows of the capture are compared with this picture of the AIR window.");
		var worst = 0.0;
		var rows:Array<Array<Dynamic>> = [];
		for (what in ["case row vs control row", "control row vs AIR", "case row vs AIR"])
		{
			var row:Array<Dynamic> = [what];
			for (column in 0...COLUMNS.length)
			{
				var x = column * CELL;
				var d = switch (what)
				{
					case "case row vs control row": Compare.region(capture, x, 0, capture, x, CELL, CELL, CELL, TOLERANCE);
					case "control row vs AIR": Compare.same(capture, air, x, CELL, CELL, CELL, TOLERANCE);
					default: Compare.same(capture, air, x, 0, CELL, CELL, TOLERANCE);
				}
				row.push(Html.value(Math.round(d.off * 1000) / 1000, Html.fixed(d.off, 1) + '% (${d.count} px)'));
				if (what == "case row vs control row" && d.off > worst) worst = d.off;
			}
			rows.push(row);
		}
		run.table('Percent (and count) of each cell\'s pixels off by more than $TOLERANCE: the case row (ALPHA set after the render) against the control row (created with ALPHA) of the same capture, and both rows against the AIR window',
			["comparison"].concat(COLUMNS), rows);
		run.score("worst cell", worst, "%", "worst cell, case row against the capture's own control row");
		run.image("mask_air", Compare.mask(capture, air, TOLERANCE), "Pixels differing from AIR", "capture");
		run.image("mask_rows", Compare.mask(capture, capture, TOLERANCE, 0, 0, capture.width, CELL, 0, CELL),
			"Case row: pixels differing from the control row", "rows");
	}
}
