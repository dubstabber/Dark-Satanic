extends GameTest


func test_seconds_two_decimals() -> void:
	assert_eq(TimeFormat.seconds(0.0), "0.00")
	assert_eq(TimeFormat.seconds(123.456), "123.46")
	assert_eq(TimeFormat.seconds(-5.0), "0.00")


func test_roman_numerals() -> void:
	assert_eq(TimeFormat.roman(0), "I")
	assert_eq(TimeFormat.roman(3), "IV")
	assert_eq(TimeFormat.roman(9), "X")
	assert_eq(TimeFormat.roman(10), "11")
	assert_eq(TimeFormat.roman(-1), "-")
