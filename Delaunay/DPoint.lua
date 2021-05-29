local Point = { }
local Point_mt  = { __index = Point }

type Edge = { origin: DPoint, index: integer, next: Edge }
type DPoint = { X: number, Y: number, Edge: Edge }

function Point.new(x: number, y: number): DPoint
	return setmetatable({
		X = x,
		Y = y,
		r = nil,
		theta = nil,
		Edge = nil,
		Cell = nil,
	}, Point_mt)
end

function Point:addEdge(edge: Edge)
	--No particular edge is kept. The goal is to allow us to take a point and get back to the graph.
	self.Edge = edge
end

local function polarSort(a, b)
	if a.r == b.r then
		return a.theta < b.theta
	end

    return a.r < b.r
end
local function xySort(a, b)
	if a.X == b.X then
		return a.Y < b.Y
	end

    return a.X < b.X
end

function Point.Polar_Sort( points: Array<DPoint> )
	table.sort(points, polarSort)
end

function Point.XY_Sort( points: Array<DPoint> )
	table.sort(points, xySort)
end

return Point