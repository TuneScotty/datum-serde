--!strict

--[[
Purpose: Declarative schema builders for type-safe validation and encoding.
Arguments: None (module exports builder functions)
Time complexity: O(1) for builder construction, O(n) for validation where n = structure size
]]

-- Schema<T> represents a typed validation and encoding specification.
export type Schema<T> = {
	kind: string,
	_inner: any?,
	validate: (value: any, path: string) -> (boolean, string?),
	encode: (value: T) -> any,
	decode: (value: any, path: string) -> (boolean, T | string),
}

local Schema = {}

--[[
Purpose: Creates a nil schema validator.
Arguments: None
Time complexity: O(1)
]]
function Schema.Nil(): Schema<nil>
	return {
		kind = "nil",
		validate = function(value: any, path: string): (boolean, string?)
			if value == nil then
				return true
			end
			return false, path .. ": expected nil, got " .. typeof(value)
		end,
		encode = function(_value: nil): any
			return nil
		end,
		decode = function(value: any, path: string): (boolean, nil | string)
			if value == nil then
				return true, nil
			end
			return false, path .. ": expected nil, got " .. typeof(value)
		end,
	}
end

--[[
Purpose: Creates a boolean schema validator.
Arguments: None
Time complexity: O(1)
]]
function Schema.boolean(): Schema<boolean>
	return {
		kind = "boolean",
		validate = function(value: any, path: string): (boolean, string?)
			if type(value) == "boolean" then
				return true
			end
			return false, path .. ": expected boolean, got " .. typeof(value)
		end,
		encode = function(value: boolean): any
			return value
		end,
		decode = function(value: any, path: string): (boolean, boolean | string)
			if type(value) == "boolean" then
				return true, value
			end
			return false, path .. ": expected boolean, got " .. typeof(value)
		end,
	}
end

--[[
Purpose: Creates a number schema validator.
Arguments: None
Time complexity: O(1)
]]
function Schema.number(): Schema<number>
	return {
		kind = "number",
		validate = function(value: any, path: string): (boolean, string?)
			if type(value) == "number" then
				if value ~= value then -- NaN check
					return false, path .. ": NaN not allowed"
				end
				if value == math.huge or value == -math.huge then
					return false, path .. ": Infinity not allowed"
				end
				return true
			end
			return false, path .. ": expected number, got " .. typeof(value)
		end,
		encode = function(value: number): any
			return value
		end,
		decode = function(value: any, path: string): (boolean, number | string)
			if type(value) == "number" then
				if value ~= value then
					return false, path .. ": NaN not allowed"
				end
				if value == math.huge or value == -math.huge then
					return false, path .. ": Infinity not allowed"
				end
				return true, value
			end
			return false, path .. ": expected number, got " .. typeof(value)
		end,
	}
end

--[[
Purpose: Creates a string schema validator.
Arguments: None
Time complexity: O(1)
]]
function Schema.string(): Schema<string>
	return {
		kind = "string",
		validate = function(value: any, path: string): (boolean, string?)
			if type(value) == "string" then
				return true
			end
			return false, path .. ": expected string, got " .. typeof(value)
		end,
		encode = function(value: string): any
			return value
		end,
		decode = function(value: any, path: string): (boolean, string | string)
			if type(value) == "string" then
				return true, value
			end
			return false, path .. ": expected string, got " .. typeof(value)
		end,
	}
end

--[[
Purpose: Creates a literal value schema validator.
Arguments: lit - the exact value to match
Time complexity: O(1)
]]
function Schema.literal<T>(lit: T): Schema<T>
	return {
		kind = "literal",
		_inner = lit,
		validate = function(value: any, path: string): (boolean, string?)
			if value == lit then
				return true
			end
			return false, path .. ": expected " .. tostring(lit) .. ", got " .. tostring(value)
		end,
		encode = function(_value: T): any
			return lit
		end,
		decode = function(value: any, path: string): (boolean, T | string)
			if value == lit then
				return true, lit
			end
			return false, path .. ": expected " .. tostring(lit) .. ", got " .. tostring(value)
		end,
	}
end

--[[
Purpose: Creates an array schema validator.
Arguments: elemSchema - schema for array elements
Time complexity: O(n) where n = array length
]]
function Schema.array<T>(elemSchema: Schema<T>): Schema<{ T }>
	return {
		kind = "array",
		_inner = elemSchema,
		validate = function(value: any, path: string): (boolean, string?)
			if type(value) ~= "table" then
				return false, path .. ": expected array, got " .. typeof(value)
			end
			-- Check it's an array-like table
			for i = 1, #value do
				local ok, err = elemSchema.validate(value[i], path .. "/" .. tostring(i - 1))
				if not ok then
					return false, err
				end
			end
			return true
		end,
		encode = function(value: { T }): any
			local result = {}
			for i, v in ipairs(value) do
				result[i] = elemSchema.encode(v)
			end
			return result
		end,
		decode = function(value: any, path: string): (boolean, { T } | string)
			if type(value) ~= "table" then
				return false, path .. ": expected array, got " .. typeof(value)
			end
			local result = {}
			for i = 1, #value do
				local ok, decoded = elemSchema.decode(value[i], path .. "/" .. tostring(i - 1))
				if not ok then
					return false, decoded
				end
				result[i] = decoded
			end
			return true, result
		end,
	}
end

--[[
Purpose: Creates a map schema validator.
Arguments: keySchema - schema for map keys, valSchema - schema for map values
Time complexity: O(n) where n = number of entries
]]
function Schema.map<K, V>(keySchema: Schema<K>, valSchema: Schema<V>): Schema<{ [K]: V }>
	return {
		kind = "map",
		_inner = { key = keySchema, value = valSchema },
		validate = function(value: any, path: string): (boolean, string?)
			if type(value) ~= "table" then
				return false, path .. ": expected map, got " .. typeof(value)
			end
			for k, v in pairs(value) do
				local okK, errK = keySchema.validate(k, path .. "/<key>")
				if not okK then
					return false, errK
				end
				local okV, errV = valSchema.validate(v, path .. "/" .. tostring(k))
				if not okV then
					return false, errV
				end
			end
			return true
		end,
		encode = function(value: { [K]: V }): any
			local result = {}
			for k, v in pairs(value) do
				local encodedKey = keySchema.encode(k)
				result[encodedKey] = valSchema.encode(v)
			end
			return result
		end,
		decode = function(value: any, path: string): (boolean, { [K]: V } | string)
			if type(value) ~= "table" then
				return false, path .. ": expected map, got " .. typeof(value)
			end
			local result = {}
			for k, v in pairs(value) do
				local okK, decodedKey = keySchema.decode(k, path .. "/<key>")
				if not okK then
					return false, decodedKey
				end
				local okV, decodedVal = valSchema.decode(v, path .. "/" .. tostring(k))
				if not okV then
					return false, decodedVal
				end
				result[decodedKey] = decodedVal
			end
			return true, result
		end,
	}
end

--[[
Purpose: Creates an object schema validator with named fields.
Arguments: shape - table mapping field names to schemas
Time complexity: O(n) where n = number of fields
]]
function Schema.object<T>(shape: { [string]: Schema<any> }): Schema<T>
	return {
		kind = "object",
		_inner = shape,
		validate = function(value: any, path: string): (boolean, string?)
			if type(value) ~= "table" then
				return false, path .. ": expected object, got " .. typeof(value)
			end
			for fieldName, fieldSchema in pairs(shape) do
				local fieldValue = (value :: any)[fieldName]
				local ok, err = fieldSchema.validate(fieldValue, path .. "/" .. fieldName)
				if not ok then
					return false, err
				end
			end
			return true
		end,
		encode = function(value: T): any
			local result = {}
			for fieldName, fieldSchema in pairs(shape) do
				local fieldValue = (value :: any)[fieldName]
				result[fieldName] = fieldSchema.encode(fieldValue)
			end
			return result
		end,
		decode = function(value: any, path: string): (boolean, T | string)
			if type(value) ~= "table" then
				return false, path .. ": expected object, got " .. typeof(value)
			end
			local result = {}
			for fieldName, fieldSchema in pairs(shape) do
				local fieldValue = (value :: any)[fieldName]
				local ok, decoded = fieldSchema.decode(fieldValue, path .. "/" .. fieldName)
				if not ok then
					return false, decoded
				end
				result[fieldName] = decoded
			end
			return true, result :: any
		end,
	}
end

--[[
Purpose: Creates a union schema validator (tries schemas in order).
Arguments: ... - variable number of schemas to try
Time complexity: O(k*n) where k = number of schemas, n = validation cost per schema
]]
function Schema.union<T>(...: Schema<any>): Schema<T>
	local schemas = { ... }
	return {
		kind = "union",
		_inner = schemas,
		validate = function(value: any, path: string): (boolean, string?)
			local errors = {}
			for i, schema in ipairs(schemas) do
				local ok, err = schema.validate(value, path)
				if ok then
					return true
				end
				table.insert(errors, err)
			end
			return false, path .. ": union failed: " .. table.concat(errors, "; ")
		end,
		encode = function(value: T): any
			for _, schema in ipairs(schemas) do
				local ok = schema.validate(value, "")
				if ok then
					return schema.encode(value)
				end
			end
			error("union encode: no matching schema")
		end,
		decode = function(value: any, path: string): (boolean, T | string)
			local errors = {}
			for _, schema in ipairs(schemas) do
				local ok, decoded = schema.decode(value, path)
				if ok then
					return true, decoded
				end
				table.insert(errors, decoded)
			end
			return false, path .. ": union failed: " .. table.concat(errors, "; ")
		end,
	}
end

--[[
Purpose: Creates an optional schema validator (nil or value).
Arguments: schema - schema for non-nil values
Time complexity: O(1) for nil, O(n) for value validation where n = schema complexity
]]
function Schema.optional<T>(schema: Schema<T>): Schema<T?>
	return {
		kind = "optional",
		_inner = schema,
		validate = function(value: any, path: string): (boolean, string?)
			if value == nil then
				return true
			end
			return schema.validate(value, path)
		end,
		encode = function(value: T?): any
			if value == nil then
				return nil
			end
			return schema.encode(value)
		end,
		decode = function(value: any, path: string): (boolean, T | nil | string)
			if value == nil then
				return true, nil
			end
			return schema.decode(value, path)
		end,
	}
end

--[[
Purpose: Creates a refined schema with additional predicate validation.
Arguments: schema - base schema, predicate - function returning true if valid, msg - optional error message
Time complexity: O(n + p) where n = base schema validation, p = predicate cost
]]
function Schema.refine<T>(schema: Schema<T>, predicate: (value: T) -> boolean, msg: string?): Schema<T>
	local errorMsg = msg or "refinement failed"
	return {
		kind = "refine",
		_inner = { schema = schema, predicate = predicate },
		validate = function(value: any, path: string): (boolean, string?)
			local ok, err = schema.validate(value, path)
			if not ok then
				return false, err
			end
			if not predicate(value) then
				return false, path .. ": " .. errorMsg
			end
			return true
		end,
		encode = function(value: T): any
			return schema.encode(value)
		end,
		decode = function(value: any, path: string): (boolean, T | string)
			local ok, decoded = schema.decode(value, path)
			if not ok then
				return false, decoded
			end
			if not predicate(decoded) then
				return false, path .. ": " .. errorMsg
			end
			return true, decoded
		end,
	}
end

return Schema
