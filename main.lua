local socket = require("socket")

---@class ExprLike
---@field sample fun(self: ExprLike): string[]
---@field id string
---@operator call(number): UsableExpr
---@operator mul(ExprLike): Prod

---@class Unit: ExprLike
---@field id "Unit"
---@field spell string
---@operator call(number): UsableExpr
---@operator mul(ExprLike): Prod

---@class Sum: ExprLike
---@field id "Sum"
---@field children UsableExpr[]
---@operator call(number): UsableExpr
---@operator add(UsableExpr | Sum): Sum
---@operator mul(ExprLike): Prod

---@class Prod: ExprLike
---@field id "Prod"
---@field children ExprLike[]
---@operator call(number): UsableExpr
---@operator mul(ExprLike): Prod

---@class Maybe: ExprLike
---@field id "Maybe"
---@field element UsableExpr
---@operator call(number): UsableExpr
---@operator mul(ExprLike): Prod

---@class UsableExpr: ExprLike
---@field weight number
---@operator add(UsableExpr | Sum): Sum
---@operator unm(): Maybe

---@generic T
---@param t T
---@return T
local function copy(t)
	if type(t) ~= "table" then
		return t
	end
	local o = {}
	for k, v in pairs(t) do
		o[k] = copy(v)
	end
	setmetatable(o, getmetatable(t))
	return o
end

local expr_mt

local function mergerFunction(self, other, key)
	if other.id == key and self.id ~= key then
		return mergerFunction(other, self, key)
	end
	if self.id == key and other.id ~= key then
		local s = copy(self)
		table.insert(s.children, other)
		return s
	elseif self.id == key and other.id == key then
		local s = copy(self)
		for _, child in ipairs(other.children) do
			table.insert(s.children, child)
		end
		return s
	end
	return setmetatable({ id = key, children = { self, other } }, expr_mt)
end

---@param self UsableExpr
---@param other UsableExpr
---@return Sum
local function sum(self, other)
	return mergerFunction(self, other, "Sum")
end

---@param self Prod | ExprLike
---@param other ExprLike
---@return Prod
local function prod(self, other)
	return mergerFunction(self, other, "Prod")
end

---@param self ExprLike
---@param weight number
---@return UsableExpr
local function call(self, weight)
	local modifiable = copy(self)
	---@cast modifiable UsableExpr
	modifiable.weight = weight
	return modifiable
end

---@param id string
---@return Unit
local function unit(id)
	return setmetatable({ id = "Unit", spell = id }, expr_mt)
end

---@param self UsableExpr
---@return Maybe
local function maybe(self)
	return setmetatable({ id = "Maybe", element = self }, expr_mt)
end

expr_mt = {
	__add = sum,
	__mul = prod,
	__call = call,
	__unm = maybe,
	__index = {
		---@param self ExprLike
		---@return string[]
		sample = function(self)
			if self.id == "Sum" then
				---@cast self Sum
				local sigma = 0
				for _, v in ipairs(self.children) do
					sigma = sigma + v.weight
				end
				local sample = math.random() * sigma
				---@type UsableExpr?
				local choice
				local cumulative = 0
				for _, v in ipairs(self.children) do
					cumulative = cumulative + v.weight
					if cumulative >= sample then
						choice = v
						break
					end
				end
				if choice == nil then
					error("random sample of sum failed")
				end
				return choice:sample()
			elseif self.id == "Prod" then
				---@cast self Prod
				local many = {}
				for _, child in ipairs(self.children) do
					local child_elems = child:sample()
					for _, child_elem in ipairs(child_elems) do
						table.insert(many, child_elem)
					end
				end
				return many
			elseif self.id == "Unit" then
				---@cast self Unit
				return { self.spell }
			elseif self.id == "Maybe" then
				---@cast self Maybe
				local rng = math.random()
				if self.element.weight > rng then
					return self.element:sample()
				end
				return {}
			else
				error("invalid instance of expr " .. self.id)
			end
		end,
	},
}

local function sample(e)
	local s = ""
	for _, v in ipairs(e:sample()) do
		s = s .. v .. " "
	end
	print(s)
end

math.randomseed(socket.gettime())
local chainsaw = unit("CHAINSAW")
local spark = unit("LIGHT_BULLET")
local sparkt = unit("LIGHT_BULLET_TRIGGER")
local proj = chainsaw(1) + spark(1) + sparkt(1)
sample(proj)
local maybe_chainsaw = -chainsaw(0.5)
local probably_chainsaw = maybe_chainsaw(0.5) + chainsaw(0.5)
local might_be_2_chainsaws = chainsaw * probably_chainsaw
for _, v in ipairs(might_be_2_chainsaws:sample()) do
	print(v)
end
