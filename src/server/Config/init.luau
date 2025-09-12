local Config = {}
Config.__index = Config

function Config.new()
	local self = setmetatable({}, Config)
	self.configurations = {}
	return self
end

function Config:init()
	for _, configModule in ipairs(script:GetChildren()) do
		local config = require(configModule)
		self.configurations[configModule.Name] = config
	end
	warn("Initialized the Config instance")
end

return Config
