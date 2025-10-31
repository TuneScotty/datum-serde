--!strict

--[[
Purpose: High-level encode/decode operations combining schemas and codecs.
Arguments: None (module exports encode/decode functions)
Time complexity: O(n) where n = data structure size
]]

local Schema = require(script.Parent.schema)

export type Schema<T> = Schema.Schema<T>
export type Codec = {
	encode: (value: any, opts: any?) -> (boolean, string | string),
	decode: (payload: string) -> (boolean, any | string),
}

local Serde = {}

--[[
Purpose: Encodes a typed value using its schema and a codec.
Arguments: schema - schema to validate and encode with, value - value to encode, codec - codec to use for serialization
Time complexity: O(n) where n = structure size
]]
function Serde.encode<T>(schema: Schema<T>, value: T, codec: Codec): (boolean, string | string)
	-- Validate
	local okValidate, errValidate = schema.validate(value, "")
	if not okValidate then
		return false, "E:Validation: " .. (errValidate :: string)
	end

	-- Schema encode (to AST)
	local ast = schema.encode(value)

	-- Codec encode (to payload)
	local okCodec, payloadOrErr = codec.encode(ast)
	if not okCodec then
		return false, payloadOrErr
	end

	return true, payloadOrErr
end

--[[
Purpose: Decodes a payload using a schema and codec.
Arguments: schema - schema to decode and validate with, payload - serialized payload, codec - codec to use for deserialization
Time complexity: O(n) where n = payload size
]]
function Serde.decode<T>(schema: Schema<T>, payload: string, codec: Codec): (boolean, T | string)
	-- Codec decode (to AST)
	local okCodec, astOrErr = codec.decode(payload)
	if not okCodec then
		return false, astOrErr
	end

	-- Schema decode (to typed value)
	local okDecode, valueOrErr = schema.decode(astOrErr, "")
	if not okDecode then
		return false, "E:Decode: " .. (valueOrErr :: string)
	end

	return true, valueOrErr
end

return Serde
