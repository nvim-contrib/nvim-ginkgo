local M = {
	-- default ginkgo command, can be overridden by main config
	default_cmd = "ginkgo",
}

---@class nvim-ginkgo.WatchConfig
---@field cmd? string Path to ginkgo binary
---@field args? string[] Extra arguments for ginkgo watch
---@field notify? boolean Show notifications on test completion
---@field focus_file? string File to focus on (optional)
---@field focus_pattern? string Test pattern to focus on (optional)

---Get default watch config (uses M.default_cmd which may be set by main config)
---@return nvim-ginkgo.WatchConfig
local function get_default_config()
	return {
		cmd = M.default_cmd,
		args = {},
		notify = true,
		focus_file = nil,
		focus_pattern = nil,
	}
end

-- Track active watch processes
local active_watches = {}

---Start ginkgo watch in a terminal buffer
---@param directory string Directory to watch
---@param opts? nvim-ginkgo.WatchConfig Watch options
---@return number|nil buffer Buffer number if successful
function M.start(directory, opts)
	opts = vim.tbl_deep_extend("force", get_default_config(), opts or {})

	-- build the command
	local cmd = { opts.cmd, "watch", "-v" }

	-- add focus options
	if opts.focus_file then
		table.insert(cmd, "--focus-file")
		table.insert(cmd, opts.focus_file)
	end

	if opts.focus_pattern then
		table.insert(cmd, "--focus")
		table.insert(cmd, opts.focus_pattern)
	end

	-- add extra args
	for _, arg in ipairs(opts.args) do
		table.insert(cmd, arg)
	end

	-- add the directory
	table.insert(cmd, directory)

	-- create a new terminal buffer
	local buf = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_buf_set_name(buf, "ginkgo-watch://" .. directory)

	-- open in a split
	vim.cmd("split")
	vim.api.nvim_win_set_buf(0, buf)

	-- start the terminal
	local job_id = vim.fn.termopen(cmd, {
		cwd = directory,
		on_exit = function(_, exit_code, _)
			active_watches[directory] = nil
			if opts.notify then
				if exit_code == 0 then
					vim.notify("Ginkgo watch stopped", vim.log.levels.INFO)
				else
					vim.notify("Ginkgo watch exited with code " .. exit_code, vim.log.levels.WARN)
				end
			end
		end,
	})

	if job_id <= 0 then
		vim.notify("Failed to start ginkgo watch", vim.log.levels.ERROR)
		vim.api.nvim_buf_delete(buf, { force = true })
		return nil
	end

	-- track the active watch
	active_watches[directory] = {
		buf = buf,
		job_id = job_id,
	}

	if opts.notify then
		vim.notify("Ginkgo watch started for " .. directory, vim.log.levels.INFO)
	end

	return buf
end

---Stop ginkgo watch for a directory
---@param directory string Directory to stop watching
function M.stop(directory)
	local watch = active_watches[directory]
	if watch then
		vim.fn.jobstop(watch.job_id)
		active_watches[directory] = nil
	end
end

---Stop all active ginkgo watches
function M.stop_all()
	for directory, _ in pairs(active_watches) do
		M.stop(directory)
	end
end

---Check if a directory is being watched
---@param directory string Directory to check
---@return boolean
function M.is_watching(directory)
	return active_watches[directory] ~= nil
end

---Get all active watch directories
---@return string[]
function M.get_active_watches()
	local dirs = {}
	for directory, _ in pairs(active_watches) do
		table.insert(dirs, directory)
	end
	return dirs
end

---Toggle watch mode for a directory
---@param directory string Directory to toggle
---@param opts? nvim-ginkgo.WatchConfig Watch options
function M.toggle(directory, opts)
	if M.is_watching(directory) then
		M.stop(directory)
	else
		M.start(directory, opts)
	end
end

return M
