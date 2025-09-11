local Packages = game:GetService("Packages")
local Logger = require(Packages.Logger)

return {
	logger = Logger.new(),
	inherit = function(from, to)
		for k, v in pairs(from) do
			to[k] = v
		end
	end,
}
