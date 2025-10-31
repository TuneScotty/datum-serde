--!strict

--[[
Purpose: Binary codec stub (CBOR-like) - to be implemented in v0.2.
Arguments: None
Time complexity: N/A (stub)
]]

export type Codec = {
	encode: (value: any, opts: any?) -> (boolean, { number } | string),
	decode: (payload: { number }) -> (boolean, any | string),
}

local Binary: Codec = {} :: any

function Binary.encode(_value: any, _opts: any?): (boolean, { number } | string)
	return false, "E:Codec: binary codec not implemented (v0.2)"
end

function Binary.decode(_payload: { number }): (boolean, any | string)
	return false, "E:Codec: binary codec not implemented (v0.2)"
end

return Binary
