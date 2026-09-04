-- Suffix notation for big numbers (K, M, B, T, Qd, Qt, Sx, Sp, Oc, No, Dc...).
-- Incremental games blow past 1e6 fast, so raw numbers are unreadable without this.

local SUFFIXES = {
	"", "K", "M", "B", "T", "Qd", "Qt", "Sx", "Sp", "Oc", "No", "Dc",
	"UDc", "DDc", "TDc", "QaDc", "QiDc", "SxDc", "SpDc", "OcDc", "NoDc", "Vg",
}

local NumberFormat = {}

function NumberFormat.format(n: number): string
	if n < 1000 then
		return string.format("%.2f", n)
	end

	local tier = math.floor(math.log(n, 10) / 3)
	tier = math.min(tier, #SUFFIXES - 1)

	local scaled = n / (10 ^ (tier * 3))
	local suffix = SUFFIXES[tier + 1]

	return string.format("%.2f%s", scaled, suffix)
end

return NumberFormat
