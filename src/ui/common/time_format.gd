class_name TimeFormat
## Static text helpers for the HUD and leaderboards.

const ROMAN := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]


## Survival time as seconds with two decimals, Devil Daggers style ("123.45").
static func seconds(value: float) -> String:
	return "%.2f" % maxf(value, 0.0)


## Tier index (0-based) as a roman numeral; falls back to decimal past X.
static func roman(index: int) -> String:
	var number := index + 1
	if number < 1:
		return "-"
	if number <= ROMAN.size():
		return ROMAN[number - 1]
	return str(number)
