local Cell = { }
local Cell_mt = { __index = Cell }

local create = table.create
local Vector2New = Vector2.new

function Cell.new(center: DPoint)
	local t = setmetatable({
		origin = center,
		Center = Vector2New(center.X, center.Y),

		Edges = create(6),
		--CW ordered list of VPoints
		Points = create(6),
	}, Cell_mt)

	center.Cell = t

	return t
end

function Cell:addEdge(Edge: VEdge)
	local Edges = self.Edges
	Edges[#Edges + 1] = Edge
end

--Returns the cell opposite this one across a given edge, based on the direction the edge is facing
function Cell:getNeighborFromEdge(Edge: VEdge): Cell
	local thisCell = self
	if thisCell == Edge.LeftCell then
		return Edge.RightCell
	elseif thisCell == Edge.RightCell then
		return Edge.LeftCell
	else
		warn("Tried to get opposite cell from edge not part of this cell")
	end
end

return Cell