local wezterm = require("wezterm")
local act = wezterm.action

return {
	-- toggle window opacity
	{ key = "o", mods = "CTRL|ALT", action = wezterm.action.EmitEvent("toggle-opacity") },

	-- create tab
	{ key = "n", mods = "CMD", action = wezterm.action.SpawnTab("DefaultDomain") },
	-- create pane
	{ key = "n", mods = "ALT", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "N", mods = "ALT", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },

	-- close tab
	{ key = "x", mods = "CMD", action = wezterm.action.CloseCurrentTab({ confirm = true }) },
	-- close pane
	{ key = "x", mods = "ALT", action = wezterm.action.CloseCurrentPane({ confirm = true }) },

	-- switch tab activeate
	{ key = "j", mods = "CMD", action = wezterm.action.ActivateTabRelative(-1) },
	{ key = "k", mods = "CMD", action = wezterm.action.ActivateTabRelative(1) },
	-- switch tab activeate by number
	{ key = "1", mods = "CMD", action = wezterm.action.ActivateTab(0) },
	{ key = "2", mods = "CMD", action = wezterm.action.ActivateTab(1) },
	{ key = "3", mods = "CMD", action = wezterm.action.ActivateTab(2) },
	{ key = "4", mods = "CMD", action = wezterm.action.ActivateTab(3) },
	{ key = "5", mods = "CMD", action = wezterm.action.ActivateTab(4) },
	{ key = "6", mods = "CMD", action = wezterm.action.ActivateTab(5) },
	{ key = "7", mods = "CMD", action = wezterm.action.ActivateTab(6) },
	{ key = "8", mods = "CMD", action = wezterm.action.ActivateTab(7) },
	{ key = "9", mods = "CMD", action = wezterm.action.ActivateTab(-1) },
	-- switch pane
	{ key = "h", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Left") },
	{ key = "j", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Down") },
	{ key = "k", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Up") },
	{ key = "l", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Right") },
	{ key = "LeftArrow", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Left") },
	{ key = "RightArrow", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Right") },
	{ key = "UpArrow", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Up") },
	{ key = "DownArrow", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Down") },

	-- resize pane
	{ key = "H", mods = "ALT", action = wezterm.action.AdjustPaneSize({ "Left", 5 }) },
	{ key = "J", mods = "ALT", action = wezterm.action.AdjustPaneSize({ "Down", 5 }) },
	{ key = "K", mods = "ALT", action = wezterm.action.AdjustPaneSize({ "Up", 5 }) },
	{ key = "L", mods = "ALT", action = wezterm.action.AdjustPaneSize({ "Right", 5 }) },
	-- equalize all panes (rebuild split tree, proportional allocation, multi-pass convergence)
	{
		key = "=",
		mods = "ALT",
		action = wezterm.action_callback(function(window, pane)
			local tab = pane:tab()

			-- Reconstruct binary split tree from pane positions
			local function build_tree(rects)
				if #rects == 1 then
					return { type = "leaf", rect = rects[1] }
				end
				local ml, mt, mr, mb = math.huge, math.huge, 0, 0
				for _, r in ipairs(rects) do
					ml = math.min(ml, r.left)
					mt = math.min(mt, r.top)
					mr = math.max(mr, r.left + r.width)
					mb = math.max(mb, r.top + r.height)
				end
				-- Try vertical split (left | right)
				local tried_x = {}
				for _, r in ipairs(rects) do
					local x = r.left + r.width
					if x > ml and x < mr and not tried_x[x] then
						tried_x[x] = true
						local lg, rg = {}, {}
						local ok = true
						for _, r2 in ipairs(rects) do
							if r2.left + r2.width <= x then
								table.insert(lg, r2)
							elseif r2.left >= x then
								table.insert(rg, r2)
							else
								ok = false
								break
							end
						end
						if ok and #lg > 0 and #rg > 0 then
							return {
								type = "v",
								pos = x,
								a = build_tree(lg),
								b = build_tree(rg),
							}
						end
					end
				end
				-- Try horizontal split (top / bottom)
				local tried_y = {}
				for _, r in ipairs(rects) do
					local y = r.top + r.height
					if y > mt and y < mb and not tried_y[y] then
						tried_y[y] = true
						local tg, bg = {}, {}
						local ok = true
						for _, r2 in ipairs(rects) do
							if r2.top + r2.height <= y then
								table.insert(tg, r2)
							elseif r2.top >= y then
								table.insert(bg, r2)
							else
								ok = false
								break
							end
						end
						if ok and #tg > 0 and #bg > 0 then
							return {
								type = "h",
								pos = y,
								a = build_tree(tg),
								b = build_tree(bg),
							}
						end
					end
				end
				return { type = "leaf", rect = rects[1] }
			end

			local function count_leaves(node)
				if node.type == "leaf" then
					return 1
				end
				return count_leaves(node.a) + count_leaves(node.b)
			end

			-- Find leaf pane adjacent to a split boundary for AdjustPaneSize
			-- For vsplit: rightmost leaf of left subtree (its right edge touches the split)
			-- For hsplit: bottommost leaf of top subtree (its bottom edge touches the split)
			local function find_adj_leaf(node, split_type)
				if node.type == "leaf" then
					return node.rect
				end
				if node.type == split_type then
					return find_adj_leaf(node.b, split_type)
				end
				return find_adj_leaf(node.a, split_type)
			end

			-- Run multiple passes to converge (each pass re-reads actual positions)
			for _ = 1, 3 do
				local ps = tab:panes_with_info()
				if #ps <= 1 then
					return
				end

				local rects = {}
				for _, p in ipairs(ps) do
					table.insert(rects, {
						index = p.index,
						pane_obj = p.pane,
						left = p.left,
						top = p.top,
						width = p.width,
						height = p.height,
					})
				end

				local tree = build_tree(rects)
				local tw, th = 0, 0
				for _, r in ipairs(rects) do
					tw = math.max(tw, r.left + r.width)
					th = math.max(th, r.top + r.height)
				end

				local adjustments = {}

				-- Walk tree: at each split, allocate space proportional to leaf count
				local function compute(node, al, at, aw, ah)
					if node.type == "leaf" then
						return
					end
					local ca = count_leaves(node.a)
					local cb = count_leaves(node.b)
					if node.type == "v" then
						local target_w = math.floor(aw * ca / (ca + cb))
						local target_pos = al + target_w
						local delta = target_pos - node.pos
						if delta ~= 0 then
							local leaf = find_adj_leaf(node.a, "v")
							table.insert(adjustments, {
								index = leaf.index,
								pane_obj = leaf.pane_obj,
								dir = delta > 0 and "Right" or "Left",
								amount = math.abs(delta),
							})
						end
						compute(node.a, al, at, target_w, ah)
						compute(node.b, target_pos, at, aw - target_w, ah)
					else -- "h"
						local target_h = math.floor(ah * ca / (ca + cb))
						local target_pos = at + target_h
						local delta = target_pos - node.pos
						if delta ~= 0 then
							local leaf = find_adj_leaf(node.a, "h")
							table.insert(adjustments, {
								index = leaf.index,
								pane_obj = leaf.pane_obj,
								dir = delta > 0 and "Down" or "Up",
								amount = math.abs(delta),
							})
						end
						compute(node.a, al, at, aw, target_h)
						compute(node.b, al, target_pos, aw, ah - target_h)
					end
				end

				compute(tree, 0, 0, tw, th)

				if #adjustments == 0 then
					break
				end

				-- Apply: activate the pane adjacent to each split boundary, then adjust
				for _, adj in ipairs(adjustments) do
					window:perform_action(act.ActivatePaneByIndex(adj.index), adj.pane_obj)
					window:perform_action(act.AdjustPaneSize({ adj.dir, adj.amount }), adj.pane_obj)
				end
			end

			-- Restore focus to the original pane
			for _, p in ipairs(tab:panes_with_info()) do
				if p.pane == pane then
					window:perform_action(act.ActivatePaneByIndex(p.index), pane)
					break
				end
			end
		end),
	},

	-- pass shift+enter to applications (for Claude Code newline, CSI u encoding)
	{ key = "Enter", mods = "SHIFT", action = wezterm.action.SendString("\x1b[13;2u") },

	-- rename tab
	{
		key = "R",
		mods = "CMD",
		action = act.PromptInputLine({
			description = "Enter new name for tab",
			action = wezterm.action_callback(function(window, pane, line)
				-- line will be `nil` if they hit escape without entering anything
				-- An empty string if they just hit enter
				-- Or the actual line of text they wrote
				if line then
					window:active_tab():set_title(line)
				end
			end),
		}),
	},
}
