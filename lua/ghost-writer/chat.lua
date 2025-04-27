local M = {}
local debug_log = require("ghost-writer.debug_log")

local SAVE_DIR = os.getenv("HOME") .. "/saved_chats"
local SAVE_FILENAME = SAVE_DIR .. "/current_chat.json" -- Fixed filename for now

local function ensure_save_dir_exists()
	if vim.fn.isdirectory(SAVE_DIR) == 0 then
		vim.fn.mkdir(SAVE_DIR, "p")
	end
end

function M.save_chat(context, conversation_history)
	if not context or not vim.api.nvim_buf_is_valid(context.buf) then
		print("no active chat buffer to save.")
		return
	end

	ensure_save_dir_exists()
	local buffer_lines = vim.api.nvim_buf_get_lines(context.buf, 0, -1, false)
	local buffer_content = table.concat(buffer_lines, "\n")

	local data_to_save = {
		buffer_content = buffer_content,
		conversation_history = conversation_history,
	}

	local json_success, json_data = pcall(vim.json.encode, data_to_save)
	if not json_success then
		print("failed to encode chat data to JSON.")
		debug_log.write_debug("JSON encoding failed: " .. tostring(json_data))
		return
	end

	local file, err = io.open(SAVE_FILENAME, "w")
	if not file then
		print("could not open save file for writing: " .. SAVE_FILENAME)
		debug_log.write_debug("File open error: " .. tostring(err))
		return
	end

	local write_success, write_err = file:write(json_data)
	file:close()

	if not write_success then
		print("failed to write chat data to file: " .. SAVE_FILENAME)
		debug_log.write_debug("File write error: " .. tostring(write_err))
		return
	end

	print("Chat saved successfully to " .. SAVE_FILENAME)
end

function M.load_chat(context, conversation_history, open_window_fn)
	ensure_save_dir_exists()
	if vim.fn.filereadable(SAVE_FILENAME) == 0 then
		print("save file not found: " .. SAVE_FILENAME)
		debug_log.write_debug("Load failed: File not found " .. SAVE_FILENAME)
		return
	end

	local file, err = io.open(SAVE_FILENAME, "r")
	if not file then
		print("could not open save file for reading: " .. SAVE_FILENAME)
		debug_log.write_debug("File open error (read): " .. tostring(err))
		return
	end
	local json_data = file:read("*a")
	file:close()

	if not json_data then
		print("failed to read data from file: " .. SAVE_FILENAME)
		return
	end

	local decode_success, loaded_data = pcall(vim.json.decode, json_data)
	if not decode_success or type(loaded_data) ~= "table" then
		print("failed to decode JSON data from save file.")
		return
	end

	if not loaded_data.buffer_content or not loaded_data.conversation_history then
		print("invalid data format in save file.")
		return
	end

	context = open_window_fn()
	if not context or not vim.api.nvim_buf_is_valid(context.buf) then
		print("failed to ensure chat window/buffer is ready for loading.")
		return
	end

	conversation_history = loaded_data.conversation_history
	debug_log.write_debug("Loaded conversation history: " .. vim.inspect(conversation_history))

	local buffer_lines = vim.split(loaded_data.buffer_content, "\n", { plain = true, trimempty = false })
	-- Use nvim_buf_set_text for potentially better performance/undo handling
	-- vim.api.nvim_buf_set_text(context.buf, 0, 0, 0, 0, buffer_lines)
	-- Or stick with set_lines for simplicity:
	vim.api.nvim_buf_set_lines(context.buf, 0, -1, false, buffer_lines)
	debug_log.write_debug("Loaded buffer content.")
	print("Chat loaded successfully from " .. SAVE_FILENAME)
	return context, conversation_history
end

return M
