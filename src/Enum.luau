--!strict

--[[

Name: Enum
Authors: devlvn
Created: 17/10/2025
Description: Library for creating custom Enums, identical to how roblox' enums can be used.

Version: 1.0.0

]]

-- Services
local HttpService = game:GetService("HttpService")

-- Types
export type EnumLibrary = {
	GetEnums: (self: EnumLibrary) -> {CustomEnum},
} & (name: string, enumItems: {string}) -> CustomEnum
export type CustomEnum = {
	GetEnumItems: (self: CustomEnum) -> {CustomEnumItem},
	FromName: (self: CustomEnum, name: string) -> CustomEnumItem?,
	FromValue: (self: CustomEnum, value: number) -> CustomEnumItem?,
}
export type CustomEnumItem = {
	Name: string,
	Value: number,
	EnumType: string,
}

-- Internal Functions
local function CreateNewEnum(self: EnumLibrary, name: string, enumItems: {string}): CustomEnum
	local newEnumItems: {CustomEnumItem} = {}
	for enumValue: number, enumName: string in enumItems do
		if typeof(enumValue) == "string" then
			enumValue = tonumber(enumValue)
		end
		if typeof(enumValue) ~= "number" then
			continue
		end
		if typeof(enumName) ~= "string" then
			continue
		end
		
		local newEnumItem: CustomEnumItem = setmetatable({
			Name = enumName,
			Value = enumValue,
			EnumType = name
		}, {
			__metatable = "The metatable is locked",
			__tostring = function(self: CustomEnumItem)
				return "Enum."..self.EnumType.."."..self.Name
			end,
			__eq = function(self: CustomEnumItem, value: any): boolean
				local success, returned = pcall(function()
					if typeof(self) ~= typeof(value) then
						return false
					end
					if self.EnumType ~= value.EnumType or self.Value ~= value.Value or self.Name ~= value.Name then
						return false
					end
					return true
				end)
				
				if success then
					return returned
				else
					return false
				end
			end,
		})
		
		newEnumItems[enumValue] = newEnumItem
	end

	local newEnum: CustomEnum = setmetatable({
		GetEnumItems = function(self: CustomEnum): {CustomEnumItem}
			return newEnumItems
		end,
		FromName = function(self: CustomEnum, name: string): CustomEnumItem?
			for _, enumItem: CustomEnumItem in newEnumItems do
				if enumItem.Name ~= name then
					continue
				end
				return enumItem
			end
			return nil
		end,
		FromValue = function(self: CustomEnum, value: number): CustomEnumItem?
			return newEnumItems[value]
		end,	
	}, {
		__metatable = "The metatable is locked",
		__tostring = function(self: CustomEnum): string
			return name
		end,
		__index = function(self: CustomEnum, index: string): any
			if rawget(self, index) then
				return rawset(self, index)
			else
				return self:FromName(index)
			end
		end,
		__newindex = function() end, -- do nothing
		__eq = function(self: CustomEnum, value: any): boolean
			local success, returned = pcall(function()
				if typeof(self) ~= typeof(value) then
					return false
				end
				if self:GetEnumItems() ~= value:GetEnumItems() then
					return false
				end
				return true
			end)
			
			if success then
				return returned
			else
				return false
			end
		end,
	})
	
	return newEnum
end
local function FindEnumInEnums(self: EnumLibrary, enum: string, create: boolean?): CustomEnum?|boolean?
	local enumsString = script:GetAttribute("Enums")
	if not enumsString or typeof(enumsString) ~= "string" then
		return nil
	end
	
	local enums: {[string]: {string}} = HttpService:JSONDecode(enumsString)
	if not enums[enum] then
		return nil
	end
	
	return if create then CreateNewEnum(self, enum, enums[enum]) else true
end
local function SaveEnumToEnums(self: EnumLibrary, newEnumName: string, newEnum: CustomEnum): ()
	local enums: {[string]: {string}} = if script:GetAttribute("Enums") then HttpService:JSONDecode(script:GetAttribute("Enums")) else {}
	local enumItemTable = {}
	
	for index: number, enumItem: CustomEnumItem in newEnum:GetEnumItems() do
		enumItemTable[index] = enumItem.Name
	end
	
	enums[newEnumName] = enumItemTable
	script:SetAttribute("Enums", HttpService:JSONEncode(enums))
end
local function GetAllEnums(self: EnumLibrary): {CustomEnum}?
	local enumsString = script:GetAttribute("Enums")
	if not enumsString or typeof(enumsString) ~= "string" then
		return nil
	end

	local enums: {[string]: {string}} = HttpService:JSONDecode(enumsString)
	local enumTable: {CustomEnum} = {}
	
	for enumName: string, enumItems: {string} in enums do
		table.insert(enumTable, CreateNewEnum(self, enumName, enumItems))
	end
	
	return enumTable
end

-- Enum Object
local EnumObject = setmetatable({
	GetEnums = function(self: EnumLibrary): {CustomEnum}?
		return GetAllEnums(self)
	end,
}, {})
local EnumObjectMeta = getmetatable(EnumObject)

-- Enum Meta
EnumObjectMeta.__index = function(self: EnumLibrary, index: string): any
	if rawget(self, index) then
		return rawget(self, index)
	else
		return FindEnumInEnums(self, index, true)
	end
end

EnumObjectMeta.__newindex = function(self: EnumLibrary, index: string, value: {string}): ()
	self(index, value)
end

EnumObjectMeta.__call = function(self: EnumLibrary, name: string, enumItems: {string}): CustomEnum
	assert(typeof(name) == "string", "New index must be a string!")
	assert(not FindEnumInEnums(self, name), "Provided enum already exists! Can't override existing enums.")
	
	local newEnum: CustomEnum = CreateNewEnum(self, name, enumItems)
	SaveEnumToEnums(self, name, newEnum)
	
	return newEnum
end

EnumObjectMeta.__tostring = function(self: EnumLibrary): string
	return "EnumLibrary"
end

EnumObjectMeta.__metatable = "The metatable is locked"

return EnumObject