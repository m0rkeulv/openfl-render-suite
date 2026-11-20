package;

import openfl.display.BlendMode;
import rendertest.Compare;
import rendertest.Html;
import rendertest.Pixels;
import rendertest.TestRun;

/**
	Every blended text cell against the Flash formula for its mode, predicted from the NORMAL cell
	of the same row in the same capture, and the ink position of every row against AIR.

	Glyphs are rasterised differently by AIR and OpenFL, so cells are not compared with AIR pixel
	for pixel. Each cell is text in #F25A1A over the same backdrop, which the last column shows
	without text, so the NORMAL cell gives the text's alpha a at every pixel (the projection of the
	pixel onto the line from its backdrop colour to the text colour). That is the glyph coverage k
	times the object's alpha t (the row's alpha), and Flash treats the two differently: t goes into
	the source before the blend, and k then mixes the blended result with the backdrop d. Every
	cell is (1-k)d + k B, with B:

	  NORMAL, LAYER  (1-t)d + t c          ADD        min(1, d + t c)      SUBTRACT  max(0, d - t c)
	  MULTIPLY       (1-t)d + t c d        SCREEN     (1-t)d + t(c+d-cd)   LIGHTEN   (1-t)d + t max(c,d)
	  DARKEN         (1-t)d + t min(c,d)   DIFFERENCE (1-t)d + t|c-d|      INVERT    (1-t)d + t(1-d)
	  OVERLAY        HARDLIGHT with c and d swapped                        HARDLIGHT (1-t)d + t h(c,d)
	  ALPHA          d t                   ERASE      d(1-t)      (inside the LAYER row only)

	where h(c,d) = 2cd for c <= 0.5 and 1 - 2(1-c)(1-d) above. Outside the LAYER row Flash does not
	draw an ERASE or ALPHA field at all, so those cells are the bare backdrop.

	Scores: the worst cell against the formula, the largest shift of a blended cell's ink from its
	row's NORMAL cell, and the largest offset of a row's text against AIR's.
**/
class Score
{
	static inline var TOLERANCE = 8;
	/** A blend shift over this many pixels is what a blend group that moves the text would show. **/
	static inline var SHIFT = 0.5;
	static inline var CW = Main.CELL_W;
	static inline var CH = Main.CELL_H;
	static inline var PIXELS = CW * CH;

	// these repeat Main
	static var MODES:Array<BlendMode> = [
		NORMAL, LAYER, ADD, SUBTRACT, MULTIPLY, SCREEN, LIGHTEN, DARKEN, DIFFERENCE, INVERT, OVERLAY, HARDLIGHT, ALPHA, ERASE
	];
	static var ROWS = ["plain", "fractional", "rotated 30", "scaled 1.6", "rotated 90", "alpha 0.5", "in a sprite", "in a LAYER"];
	static var ROW_ALPHA = [1, 1, 1, 1, 1, 0.5, 1, 1];
	/** The row whose cells are LAYERs: the only one where ERASE and ALPHA are drawn. **/
	static inline var LAYER_ROW = 7;
	/** The column with the backdrop alone. **/
	static var NONE = MODES.length;
	static var TEXT = [0xF2 / 255.0, 0x5A / 255.0, 0x1A / 255.0];

	public static function score(run:TestRun):Void
	{
		var capture = run.capture;
		var air = run.reference("air", "AIR window (reference)", "Only the position of each row's text is compared with this picture; the cells are checked against the formula.");
		var names = [for (m in MODES) (m : String).toUpperCase()];

		// every cell against the formula
		var mask = Compare.mask(capture, capture, 0);
		var worst = 0.0;
		var rows:Array<Array<Dynamic>> = [];
		for (r in 0...ROWS.length)
		{
			var backdrop = backdropOf(capture, r);
			var coverage = coverageOf(capture, r, backdrop);
			var rowWorst = 0.0;
			var cells:Array<Dynamic> = [];
			for (m in 0...MODES.length)
			{
				var predicted = predict(MODES[m], coverage, ROW_ALPHA[r], r == LAYER_ROW, backdrop);
				var count = 0;
				for (i in 0...PIXELS)
				{
					var x = m * CW + i % CW, y = r * CH + Std.int(i / CW);
					var off = Math.max(Math.abs(capture.red(x, y) - predicted[i * 3]),
						Math.max(Math.abs(capture.green(x, y) - predicted[i * 3 + 1]), Math.abs(capture.blue(x, y) - predicted[i * 3 + 2])));
					if (off > TOLERANCE)
					{
						count++;
						mask.set(x, y, Compare.MASK_MARK);
					}
				}
				var percent = 100.0 * (count / PIXELS);
				cells.push(Html.percent(percent));
				if (percent > rowWorst) rowWorst = percent;
			}
			if (rowWorst > worst) worst = rowWorst;
			rows.push(([ROWS[r], Html.percent(rowWorst)] : Array<Dynamic>).concat(cells));
		}
		run.table('Percent of each text cell\'s pixels off the Flash formula for its mode by more than $TOLERANCE (predicted from the NORMAL cell of the same row and capture)',
			["row", "worst mode"].concat(names), rows,
			"Glyphs are rasterized differently by AIR and OpenFL, so every capture is checked against its own NORMAL cell; the AIR window's rows check the formulas.");

		// where the ink is: each row's text against AIR's, and each blended cell's against its row's NORMAL cell
		var shift = 0.0, placement = 0.0;
		var inkRows:Array<Array<Dynamic>> = [];
		for (r in 0...ROWS.length)
		{
			var backdrop = backdropOf(capture, r);
			var coverage = coverageOf(capture, r, backdrop);
			var base = centroid(coverage);
			var airBase = centroid(coverageOf(air, r, backdropOf(air, r)));
			var dx = base[0] - airBase[0], dy = base[1] - airBase[1];
			placement = Math.max(placement, Math.max(Math.abs(dx), Math.abs(dy)));
			var blend = 0.0, which = "";
			for (m in 1...MODES.length)
			{
				var mode = MODES[m];
				// ALPHA on opaque text leaves the cell as it is, so it has no ink to place; outside a
				// LAYER, ALPHA and ERASE are not drawn at all
				if (mode == ALPHA && ROW_ALPHA[r] == 1) continue;
				if ((mode == ALPHA || mode == ERASE) && r != LAYER_ROW) continue;
				var cuts = r == LAYER_ROW;
				var expected = predict(mode, null, ROW_ALPHA[r], cuts, backdrop);
				var ink = new Array<Float>(), supported = new Array<Float>();
				var cell = cellOf(capture, m, r);
				for (i in 0...PIXELS)
				{
					var reach = 0.0, moved = 0.0;
					for (c in 0...3)
					{
						reach += Math.abs(expected[i * 3 + c] / 255 - backdrop[i * 3 + c]);
						moved += Math.abs(cell[i * 3 + c] / 255.0 - backdrop[i * 3 + c]);
					}
					var support = reach > 0.1;
					ink.push(support ? clip(moved / Math.max(reach, 1e-6)) : 0);
					supported.push(support ? coverage[i] : 0);
				}
				var inkCentre = centroid(ink), baseCentre = centroid(supported);
				if (inkCentre == null || baseCentre == null) continue;
				var s = Math.max(Math.abs(inkCentre[0] - baseCentre[0]), Math.abs(inkCentre[1] - baseCentre[1]));
				if (s > blend)
				{
					blend = s;
					which = names[m];
				}
			}
			shift = Math.max(shift, blend);
			inkRows.push([ROWS[r], signed(dx), signed(dy), Html.value(round3(blend), Html.fixed(blend, 2)), which]);
		}
		run.table("Ink centroid per row: the NORMAL cell's text against AIR's (dx, dy px), and the largest shift of a blended cell's ink from its row's NORMAL cell (px)",
			["row", "dx vs AIR", "dy vs AIR", "largest blend shift", "mode"], inkRows,
			'Where the text is laid out is the same for every mode; a blend shift over ${Html.fixed(SHIFT, 1)} px is what a blend group that moves the text would show.');
		run.table("Summary: worst cell against the formula, largest blend shift, and largest text placement offset against AIR",
			["capture", "worst cell vs formula", "largest blend shift (px)", "text placement vs AIR (px)"], [
				[
					run.label,
					Html.percent(worst),
					Html.value(round3(shift), Html.fixed(shift, 2)),
					Html.value(round3(placement), Html.fixed(placement, 2))
				]
			]);
		run.score("worst cell vs formula", worst, "%", "worst cell against the Flash formula (not against AIR's pixels)");
		run.score("largest blend shift", shift, "px", "largest shift of a blended cell's ink from its row's NORMAL cell");
		run.score("text placement vs AIR", placement, "px", "largest offset of a row's NORMAL text against AIR's");
		run.image("mask_formula", mask, "Pixels off the formula", "capture");
	}

	/** A cell's pixels as r, g, b values 0..255, row by row. **/
	static function cellOf(image:Pixels, column:Int, row:Int):Array<Float>
	{
		var values = new Array<Float>();
		for (y in row * CH...(row + 1) * CH)
			for (x in column * CW...(column + 1) * CW)
			{
				values.push(image.red(x, y));
				values.push(image.green(x, y));
				values.push(image.blue(x, y));
			}
		return values;
	}

	/** The backdrop column of a row, 0..1. **/
	static function backdropOf(image:Pixels, row:Int):Array<Float>
	{
		return [for (v in cellOf(image, NONE, row)) v / 255.0];
	}

	/**
		The glyph coverage of each pixel of a row: where the NORMAL cell sits on the line from the
		pixel's backdrop colour to the text colour, divided by the row's alpha.
	**/
	static function coverageOf(image:Pixels, row:Int, backdrop:Array<Float>):Array<Float>
	{
		var normal = cellOf(image, 0, row);
		return [
			for (i in 0...PIXELS)
			{
				var along = 0.0, length = 0.0;
				for (c in 0...3)
				{
					var line = TEXT[c] - backdrop[i * 3 + c];
					along += (normal[i * 3 + c] / 255.0 - backdrop[i * 3 + c]) * line;
					length += line * line;
				}
				clip(clip(along / length) / ROW_ALPHA[row]);
			}
		];
	}

	/**
		The predicted cell, r, g, b 0..255 per pixel, for glyph coverage `coverage` (null: full
		coverage) of an object with alpha `t` over `backdrop`; `cuts` is whether an ERASE or ALPHA
		field is drawn at all (only inside a LAYER).
	**/
	static function predict(mode:BlendMode, coverage:Array<Float>, t:Float, cuts:Bool, backdrop:Array<Float>):Array<Float>
	{
		var out = new Array<Float>();
		for (i in 0...PIXELS)
		{
			var k = coverage != null ? coverage[i] : 1.0;
			for (c in 0...3)
			{
				var d = backdrop[i * 3 + c];
				if ((mode == ERASE || mode == ALPHA) && !cuts)
				{
					out.push(d * 255);
					continue;
				}
				var blended = switch (mode)
				{
					case ADD: Math.min(1, d + t * TEXT[c]);
					case SUBTRACT: Math.max(0, d - t * TEXT[c]);
					case ERASE: d * (1 - t);
					case ALPHA: d * t;
					default: (1 - t) * d + t * full(mode, TEXT[c], d);
				}
				out.push(((1 - k) * d + k * blended) * 255);
			}
		}
		return out;
	}

	/** The colour a mixing mode gives where text of colour `c` is fully drawn at full alpha over `d`. **/
	static function full(mode:BlendMode, c:Float, d:Float):Float
	{
		return switch (mode)
		{
			case MULTIPLY: c * d;
			case SCREEN: c + d - c * d;
			case LIGHTEN: Math.max(c, d);
			case DARKEN: Math.min(c, d);
			case DIFFERENCE: Math.abs(c - d);
			case INVERT: 1 - d;
			case OVERLAY: hard(d, c);
			case HARDLIGHT: hard(c, d);
			default: c; // NORMAL, LAYER
		}
	}

	static inline function hard(c:Float, d:Float):Float
	{
		return c <= 0.5 ? 2 * c * d : 1 - 2 * (1 - c) * (1 - d);
	}

	/** The weighted centre (x, y) of a cell's weights, or null when they sum to under 1. **/
	static function centroid(weights:Array<Float>):Array<Float>
	{
		var sum = 0.0, sx = 0.0, sy = 0.0;
		for (i in 0...PIXELS)
		{
			sum += weights[i];
			sx += (i % CW) * weights[i];
			sy += Std.int(i / CW) * weights[i];
		}
		return sum < 1 ? null : [sx / sum, sy / sum];
	}

	static inline function clip(v:Float):Float
	{
		return v < 0 ? 0 : (v > 1 ? 1 : v);
	}

	static inline function round3(v:Float):Float
	{
		return Math.round(v * 1000) / 1000;
	}

	/** An offset with its sign, two decimals ("+0.94", "-0.00"). **/
	static function signed(v:Float):Dynamic
	{
		return Html.value(round3(v), (v < 0 ? "-" : "+") + Html.fixed(Math.abs(v), 2));
	}
}
