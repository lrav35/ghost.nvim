local M = {}

M.config = {
	debug = false,
	log_file = "/tmp/debug.log",
}

function M.setup(user_config)
	user_config = user_config or {}
	for key, value in pairs(user_config) do
		M.config[key] = value
	end
end

function M.write_debug(message)
	if M.config.debug then
		local debug_file = io.open("/tmp/debug.log", "a")
		if debug_file then
			debug_file:write(os.date() .. " - " .. message .. "\n")
			debug_file:close()
		end
	end
end

return M
