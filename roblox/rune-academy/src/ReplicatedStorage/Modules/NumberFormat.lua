-- Number display rule (as specified): plain comma-separated whole numbers
-- below a million ("0", "10", "999,000"), then a 2-decimal suffix from a
-- million up - "5.32B" for 5,324,222,143, not the full digit string.
-- Suffix ladder: M, B, T, Qd, Qt, St, SEt, Oc, No, Dc.

local SUFFIX_BY_TIER = {
	[2] = "M",
	[3] = "B",
	[4] = "T",
	[5] = "Qd",
	[6] = "Qt",
	[7] = "St",
	[8] = "SEt",
	[9] = "Oc",
	[10] = "No",
	[11] = "Dc",
}
local MAX_TIER = 11 -- Dc; anything past this just keeps climbing in Dc

local NumberFormat = {}

local function withCommas(n: number): string
	local rounded = math.floor(n + 0.5)
	local sign = ""
	if rounded < 0 then
		sign = "-"
		rounded = -rounded
	end

	local digits = tostring(rounded)
	local reversed = digits:reverse():gsub("(%d%d%d)", "%1,")
	local withSeparators = reversed:reverse():gsub("^,", "")

	return sign .. withSeparators
end

function NumberFormat.format(n: number): string
	if n < 1000000 then
		return withCommas(n)
	end

	local tier = math.min(math.floor(math.log(n, 10) / 3), MAX_TIER)
	local scaled = n / (10 ^ (tier * 3))
	local suffix = SUFFIX_BY_TIER[tier] or ""

	return string.format("%.2f%s", scaled, suffix)
end

return NumberFormat
