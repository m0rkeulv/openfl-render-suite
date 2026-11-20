package;

import rendertest.Compare;
import rendertest.Html;
import rendertest.TestRun;

/**
	The LAYER and cacheAsBitmap rows against the AIR window per cell, and the cached row against
	the capture's own LAYER row (they must be the same picture). Percent of each cell's pixels off
	by more than the tolerance; the score is the worst cell against AIR.
**/
class Score
{
	static inline var TOLERANCE = 8;
	static inline var CELL = Main.CELL;

	public static function score(run:TestRun):Void
	{
		var capture = run.capture;
		var air = run.reference("air", "AIR window (reference)", "The capture is compared with this picture of the AIR window.");
		var modes = [for (mode in Main.MODES) (mode : String).toUpperCase()];
		var worst = 0.0;
		var rows:Array<Array<Dynamic>> = [];
		for (what in ["LAYER row vs AIR", "cacheAsBitmap row vs AIR", "cached row vs own LAYER row"])
		{
			var values = [
				for (column in 0...modes.length)
				{
					var x = column * CELL;
					switch (what)
					{
						case "LAYER row vs AIR": Compare.same(capture, air, x, 0, CELL, CELL, TOLERANCE).off;
						case "cacheAsBitmap row vs AIR": Compare.same(capture, air, x, CELL, CELL, CELL, TOLERANCE).off;
						default: Compare.region(capture, x, CELL, capture, x, 0, CELL, CELL, TOLERANCE).off;
					}
				}
			];
			if (what != "cached row vs own LAYER row") for (v in values) if (v > worst) worst = v;
			rows.push(([what] : Array<Dynamic>).concat([for (v in values) Html.percent(v)]));
		}
		run.table('Percent of each cell\'s pixels off by more than $TOLERANCE: the LAYER and cacheAsBitmap rows against the AIR window, the cached row against the capture\'s own LAYER row',
			["comparison"].concat(modes), rows);
		run.score("worst cell vs AIR", worst, "%");
		run.image("mask_air", Compare.mask(capture, air, TOLERANCE), "Pixels off against AIR", "capture");
	}
}
