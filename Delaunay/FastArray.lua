--[[
	A simple structure that removes indices without shifting the array.
	The tradeoff is that inserting into a specific index is no longer possible.
]]

local FA = { }

local function push_stack(stack, val)
	stack[#stack + 1] = val
end

local function pop_stack(stack)
	local len = #stack

	--It's important to allow underflows with this particular stack! Just return nil, though.
	if len == 0 then
		return nil
	end

	local ret = stack[len]
	stack[len] = nil

	return ret
end

function FA.new( opt_len: number ): FastArray
	local n = {
		Contents = opt_len and table.create(opt_len) or { },
		insert_stack = { },
		insert = FA.insert,
		remove = FA.remove,
		find_remove = FA.find_remove
	}

	return n
end

function FA.insert(fa: FastArray, item: any): number
	local insert_idx = pop_stack(fa.insert_stack) or (#fa.Contents + 1)
	fa.Contents[ insert_idx ] = item

	return insert_idx
end

function FA.remove(fa: FastArray, idx: number)
	local store = fa.Contents[idx]

	if store == nil then
		error("Fast array removed unfilled index")
	end

	push_stack(fa.insert_stack, idx)
	fa.Contents[idx] = nil

	return store
end

function FA.find_remove(fa: FastArray, item: any): boolean
	for i,v in pairs(fa.Contents) do
		if v == item then
			FA.remove(fa, i)
			return true
		end
	end

	--Wasn't found
	return false
end

return FA