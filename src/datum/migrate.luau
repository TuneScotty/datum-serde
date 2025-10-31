--!strict

--[[
Purpose: DAG-based migration system for versioned data with determinism guarantees.
Arguments: None (module exports plan builder and apply function)
Time complexity: O(V + E) for topological sort, O(n) for each migration step where n = data size
]]

export type MigrationFn = (value: any) -> (boolean, any | string)

type GraphNode = {
	edges: { [string]: MigrationFn },
}

export type MigrationPlan = {
	graph: { [string]: GraphNode },
	locked: boolean,
	add: (self: MigrationPlan, fromVer: string, toVer: string, fn: MigrationFn) -> (),
	lock: (self: MigrationPlan) -> (),
}

local Migrate = {}

--[[
Purpose: Creates a new migration plan (DAG of version transitions).
Arguments: None
Time complexity: O(1)
]]
function Migrate.plan(): MigrationPlan
	local self: MigrationPlan = {
		graph = {},
		locked = false,
		add = nil :: any,
		lock = nil :: any,
	}

	function self:add(fromVer: string, toVer: string, fn: MigrationFn)
		if self.locked then
			error("E:Migration: plan is locked")
		end

		if not self.graph[fromVer] then
			self.graph[fromVer] = { edges = {} }
		end

		if self.graph[fromVer].edges[toVer] then
			error("E:Migration: duplicate edge " .. fromVer .. " -> " .. toVer)
		end

		self.graph[fromVer].edges[toVer] = fn
	end

	function self:lock()
		self.locked = true
	end

	return self
end

--[[
Purpose: Finds shortest path using BFS in migration graph.
Arguments: plan - migration plan, fromVer - starting version, toVer - target version
Time complexity: O(V + E) where V = versions, E = edges
]]
local function findPath(plan: MigrationPlan, fromVer: string, toVer: string): ({ string }?, string?)
	if fromVer == toVer then
		return {}
	end

	local queue = { { ver = fromVer, path = { fromVer } } }
	local visited = { [fromVer] = true }
	local head = 1

	while head <= #queue do
		local current = queue[head]
		head = head + 1

		local node = plan.graph[current.ver]
		if not node then
			continue
		end

		for nextVer, _ in pairs(node.edges) do
			if visited[nextVer] then
				continue
			end

			local newPath = table.clone(current.path)
			table.insert(newPath, nextVer)

			if nextVer == toVer then
				return newPath
			end

			visited[nextVer] = true
			table.insert(queue, { ver = nextVer, path = newPath })
		end
	end

	return nil, "E:Migration: no path from " .. fromVer .. " to " .. toVer
end

--[[
Purpose: Checks for cycles in the migration graph using DFS.
Arguments: plan - migration plan
Time complexity: O(V + E) where V = versions, E = edges
]]
local function detectCycle(plan: MigrationPlan): (boolean, string?)
	local visiting = {}
	local visited = {}

	local function dfs(ver: string): (boolean, string?)
		if visiting[ver] then
			return false, "E:Migration: cycle detected at " .. ver
		end
		if visited[ver] then
			return true
		end

		visiting[ver] = true

		local node = plan.graph[ver]
		if node then
			for nextVer, _ in pairs(node.edges) do
				local ok, err = dfs(nextVer)
				if not ok then
					return false, err
				end
			end
		end

		visiting[ver] = nil
		visited[ver] = true
		return true
	end

	for ver, _ in pairs(plan.graph) do
		if not visited[ver] then
			local ok, err = dfs(ver)
			if not ok then
				return false, err
			end
		end
	end

	return true
end

--[[
Purpose: Applies a migration plan to transform data from one version to another.
Arguments: plan - migration plan, value - data to migrate, fromVer - starting version, toVer - target version
Time complexity: O(V + E + k*n) where k = path length, n = data transformation cost per step
]]
function Migrate.apply(plan: MigrationPlan, value: any, fromVer: string, toVer: string): (boolean, any | string)
	-- Check for cycles
	local okCycle, errCycle = detectCycle(plan)
	if not okCycle then
		return false, errCycle :: string
	end

	-- Find path
	local path, pathErr = findPath(plan, fromVer, toVer)
	if not path then
		return false, pathErr :: string
	end

	-- Apply migrations along path
	local current = value
	for i = 1, #path - 1 do
		local from = path[i]
		local to = path[i + 1]

		local node = plan.graph[from]
		if not node then
			return false, "E:Migration: missing node " .. from
		end

		local fn = node.edges[to]
		if not fn then
			return false, "E:Migration: missing edge " .. from .. " -> " .. to
		end

		local ok, result = fn(current)
		if not ok then
			return false, "E:Migration: step " .. from .. " -> " .. to .. " failed: " .. tostring(result)
		end

		current = result
	end

	return true, current
end

return Migrate
