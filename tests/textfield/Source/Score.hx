package;

import rendertest.Compare;
import rendertest.Html;
import rendertest.Pixels;
import rendertest.TestRun;

/**
	Device text differs between AIR and OpenFL, so pixels are only compared within a capture:
	every blended cell against the NORMAL cell of its row. A cell's outcome is "as NORMAL" when
	under 1% of its pixels are off, else "differs"; the score is the number of cells whose
	outcome is not the AIR window's.
**/
class Score
{
	static inline var TOLERANCE = 8;
	static inline var CELL = Main.CELL;
	/** Percent of pixels off under which a cell counts as the same picture as its NORMAL cell. **/
	static inline var SAME = 1.0;
	static var COLUMNS = ["DIFFERENCE", "ALPHA", "ERASE", "SUBTRACT", "INVERT", "DIFFERENCE over black"];

	/** The cells compared, as [x, y, x of the NORMAL cell, y of the NORMAL cell]: row 0's blended cells, then DIFFERENCE over black. **/
	static var CELLS = [for (column in 1...6) [column * CELL, 0, 0, 0]].concat([[CELL, CELL, 0, CELL]]);

	public static function score(run:TestRun):Void
	{
		var capture = run.capture;
		var air = run.reference("air", "AIR window (reference)", "Only the outcome of each cell (as its row's NORMAL cell or not) is compared with this picture.");
		var offs = [for (c in CELLS) Compare.region(capture, c[0], c[1], capture, c[2], c[3], CELL, CELL, TOLERANCE).off];
		var outcomes = outcomesOf(offs);
		var airOutcomes = outcomesOf([for (c in CELLS) Compare.region(air, c[0], c[1], air, c[2], c[3], CELL, CELL, TOLERANCE).off]);
		run.table('Percent of each blended text cell\'s pixels off the NORMAL cell of its row in the same capture, by more than $TOLERANCE',
			["capture"].concat(COLUMNS), [([run.label] : Array<Dynamic>).concat([for (v in offs) Html.percent(v)])]);
		var airDiffers = [for (i in 0...COLUMNS.length) if (airOutcomes[i] == "differs") COLUMNS[i]];
		run.table('Outcome of each cell: the same picture as its row\'s NORMAL cell (under $SAME% off) or not', ["capture"].concat(COLUMNS),
			[([run.label] : Array<Dynamic>).concat(outcomes)],
			"On screen ERASE and ALPHA in a LAYER that holds only the text have nothing to cut and show nothing, in AIR's window as well. "
			+ "In AIR's window " + (airDiffers.length > 0 ? airDiffers.join(" and ") + " differ" : "every cell is as NORMAL") + ".");
		var mismatched = 0;
		for (i in 0...outcomes.length)
			if (outcomes[i] != airOutcomes[i]) mismatched++;
		run.score("cells off AIR's outcome", mismatched, "cells", "cells whose outcome differs from the AIR window's");

		var mask = Pixels.filled(capture.width, capture.height, Compare.MASK_GROUND);
		for (c in CELLS)
			mask.paste(Compare.mask(capture, capture, TOLERANCE, c[0], c[1], CELL, CELL, c[2], c[3]).crop(c[0], c[1], CELL, CELL), c[0], c[1]);
		run.image("mask_normal", mask, "Pixels differing from the NORMAL cell of the row", "capture");
	}

	static function outcomesOf(offs:Array<Float>):Array<String>
	{
		return [for (v in offs) v < SAME ? "as NORMAL" : "differs"];
	}
}
