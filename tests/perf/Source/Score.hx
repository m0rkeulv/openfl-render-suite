package;

import rendertest.Html;
import rendertest.TestRun;

/**
	The timings, per set: the median and the fastest of the iterations, what HashLink allocated per
	call, and a CRC of the result (equal CRCs between two builds mean the same pixels). The scores
	are the sum of the medians of each set, in milliseconds; they have no limit, since a time
	depends on the machine. Compare builds with the suite runner's --baseline.
**/
class Score
{
	public static function score(run:TestRun):Void
	{
		var sets:Array<String> = [];
		for (r in Main.results)
			if (sets.indexOf(r.set) < 0) sets.push(r.set);
		for (set in sets)
		{
			var total = 0.0;
			var rows:Array<Array<Dynamic>> = [];
			for (r in Main.results)
			{
				if (r.set != set) continue;
				total += r.median;
				rows.push([
					r.name,
					Html.value(r.median, Html.fixed(r.median, 1)),
					Html.value(r.min, Html.fixed(r.min, 1)),
					Html.value(r.mbPerCall, Html.fixed(r.mbPerCall, 1)),
					Math.round(r.allocsPerCall),
					r.crc
				]);
			}
			run.table('$set: milliseconds per call (median and fastest of ${Main.iterations}), MB and allocations per call (HashLink), CRC of the result',
				["case", "median ms", "fastest ms", "MB per call", "allocations per call", "CRC"], rows);
			run.score(set, total, "ms", "the sum of the set's medians");
		}
		run.note("Times depend on the machine and on what else runs on it; compare two builds on the same machine, run after run.");
	}
}
