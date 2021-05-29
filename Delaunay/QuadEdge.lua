local ReplicatedFirst = game.ReplicatedFirst
local Modules = ReplicatedFirst.Modules
local PSA = _G.require(Modules.PackedSparseArray)

local QEdge = { }
QEdge.__index = QEdge

function QEdge.newQuad( )
	local Edges = table.create(5)
	Edges[1] = QEdge.new(1, Edges)
	Edges[2] = QEdge.new(2, Edges)
	Edges[3] = QEdge.new(3, Edges)
	Edges[4] = QEdge.new(4, Edges)
	Edges.gloablIndex = nil

	Edges[1].next = Edges[1]
	Edges[2].next = Edges[4]
	Edges[3].next = Edges[3]
	Edges[4].next = Edges[2]
	return Edges
end

function QEdge.new( index: integer, list: Array<Edge> )
	return setmetatable({
		index = index,
		next = nil,
		listRef = list,
		origin = nil,
	}, QEdge)
end

function QEdge:ONext(): Edge
	return self.next
end

function QEdge:LNext(): Edge
	return self:InvRot().next:Rot()
end

function QEdge:RNext(): Edge
	return self:Rot().next:InvRot()
end

function QEdge:RPrev(): Edge
	return self:Sym().next
end

function QEdge:LPrev(): Edge
	return self.next:Sym()
end

function QEdge:DNext(): Edge
	return self:Sym().next:Sym()
end

function QEdge:OPrev(): Edge
	return self:Rot().next:Rot()
end

function QEdge:DPrev(): Edge
	return self:InvRot().next:InvRot()
end

function QEdge:Rot(): Edge
	local idx = self.index < 4 and self.index + 1 or self.index - 3
	return self.listRef[idx]
end

function QEdge:InvRot(): Edge
	local idx = self.index > 1 and self.index - 1 or self.index + 3
	return self.listRef[idx]
end

function QEdge:Sym(): Edge
	local idx = self.index < 3 and self.index + 2 or self.index - 2
	return self.listRef[idx]
end

function QEdge:setOrigin(p)
	self.origin = p
	p:addEdge(self)
end

function QEdge:setDestination(p: DPoint)
	local sym: Edge = self:Sym()
	sym:setOrigin(p)
end

--[[
	Very tricky function. Makes e1 "left" of e2, and e2's previous left become's e1's left.

	Pay close attention to the names of each edge as we walk through this:
	Imagine that you have a single point with 2 edges (e2, e3) extending from it. You wish to add another edge (e1) to
		that point between the two existing edges.

	What to do?
		QuadEdge.Splice(e1, e3)
		e1 will be inserted as the ONext of e3. e2 will be made into the ONext of e1.
		Thus e1:ONext == e2. e2:ONext == e3. e3:ONext == e1.

	Alternatively, e1 may originate elsewhere and have the vertex between e2 and e3 as a destination. In this case just do
		QuadEdge.Splice(e1:Sym(), e3)

	See Delaunay's Connect function for how this can be used to form a coherent triangle.
		Doing it manually each time is less mental load though.
]]
function QEdge.Splice(e1: Edge, e2: Edge)
	local alpha = e1:ONext():Rot()
	local beta = e2:ONext():Rot()

	local t1 = e1:ONext()
	local t2 = e2:ONext()
	local t3 = beta:ONext()
	local t4 = alpha:ONext()

	e1.next = t2
	e2.next = t1
	alpha.next = t3
	beta.next = t4
end

return QEdge