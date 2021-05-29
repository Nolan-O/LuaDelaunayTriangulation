local VPoint = { }
local VPoint_mt = { __index = VPoint }

local create = table.create

function VPoint.new(x: number, y: number): VPoint
	return setmetatable({
		X = x,
		Y = y,
		--All VPoints have exactly 3 edges and cells associated. This fact is leveraged for traversing voronoi diagrams.
		Edges = create(3),
		Neighbors = create(3),
		VCells = create(3),

	}, VPoint_mt)
end

function VPoint:addNeighboringPoint( point )
	self.Neighbors[#self.Neighbors + 1] = point
end

function VPoint:addEdge(edge)
	self.Edges[#self.Edges + 1] = edge
end

return VPoint