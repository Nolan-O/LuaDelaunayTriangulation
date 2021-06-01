local DPoint = require(script.DPoint)
local QuadEdge = require(script.QuadEdge)
local FA = require(script.FastArray)

local Delaunay = { }
local EdgeList

local function NewQEdge(): Edge
	local edges: Array<Edge> = QuadEdge.newQuad()
	edges.globalIndex = FA.insert(EdgeList, edges)

	return edges
end

local function Kill(edge)
	QuadEdge.Splice(edge, edge:OPrev())
	QuadEdge.Splice(edge:Sym(), edge:Sym():OPrev())

	FA.remove(EdgeList, edge.listRef.globalIndex)
end

local function CCW(p1, p2, p3): boolean
	local x1, x2 = p2.X - p1.X, p3.X - p2.X
	local y1, y2 = p2.Y - p1.Y, p3.Y - p2.Y
	local t = (y1 * x2 - x1 * y2)
	return t > 0.0
end

--[[
	Some general purpose functions which are no longer useful

local function CCW_inclusive(p1, p2, p3): boolean
	local x1, x2 = p2.X - p1.X, p3.X - p2.X
	local y1, y2 = p2.Y - p1.Y, p3.Y - p2.Y
	local t = (y1 * x2 - x1 * y2)
	return t >= 0.0
end

--Forms a triangle from 2 edges
local function Connect(e1: Edge, e2: Edge)
	local e3: Edge = NewQEdge()[1]

	e3:setOrigin(e1:Sym().origin)
	e3:setDestination(e2.origin)

	QuadEdge.Splice(e3, e1:LNext())
	QuadEdge.Splice(e3:Sym(), e2)

	return e3
end
]]

local function MakeEdgeBetween(a: DPoint, b: DPoint)
	local edge: Edge = NewQEdge()[1]
	edge:setOrigin(a)
	edge:setDestination(b)

	return edge
end

local function TriangleFromPoints(points: Array<DPoint>)
	local e1 = MakeEdgeBetween(points[1], points[2])
	local e2 = MakeEdgeBetween(points[2], points[3])
	local e3 = MakeEdgeBetween(points[3], points[1])

	QuadEdge.Splice(e1:Sym(), e2)
	QuadEdge.Splice(e2:Sym(), e3)
	QuadEdge.Splice(e3:Sym(), e1)

	--The initial edge must be CW around the origin.
	if CCW(e1.origin, e2.origin, e3.origin) then
		return e3:Sym()
	else
		return e1
	end

	return e1
end

local function GetCircumCircle(p1, p2, p3)
	local p1x, p2x, p3x = p1.X, p2.X, p3.X
	local p1y, p2y, p3y = p1.Y, p2.Y, p3.Y
	local D =  2 * ( p1x * (p2y - p3y) +
				 p2x * (p3y - p1y) +
				 p3x * (p1y - p2y))
	local x = (( p1x * p1x + p1y * p1y) * (p2y - p3y) +
			   ( p2x * p2x + p2y * p2y) * (p3y - p1y) +
			   ( p3x * p3x + p3y * p3y) * (p1y - p2y))
	local y = (( p1x * p1x + p1y * p1y) * (p3x - p2x) +
			   ( p2x * p2x + p2y * p2y) * (p1x - p3x) +
			   ( p3x * p3x + p3y * p3y) * (p2x - p1x))

	x = x / D
	y = y / D

	local r = math.abs(p1x - x) ^ 2 + math.abs(p1y - y) ^ 2

	return x, y, r
end

local function IsInCircle(p1, p2, p3, oPoint)
	local x, y, r = GetCircumCircle(p1, p2, p3)
	local dist = Vector2.new(oPoint.X - x, oPoint.Y - y).Magnitude

	--r is still squared
	return (dist * dist) < r
end

local VEdge = _G.require(script.VoronoiEdge)
local VPoint = _G.require(script.VPoint)
local Cell = _G.require(script.Cell)
local function GetVoronoi(QEdges: Array<Edge>) : (Array<VCell>, Array<VEdge>, FastArray, Array<VPoint>)
	--The number of edges is 4x due to them being quad edges.
	local VEdges: Array<VEdge> = table.create( #QEdges.Contents / 4 )
	local VCells: Array<VCell> = table.create( #QEdges.Contents / 4 )
	local CircumCenters: Array<VPoint> = table.create(#QEdges.Contents / 4)

	for i, Qedge in pairs(QEdges.Contents) do
		local edge = Qedge[1]
		if CCW(edge.origin, edge:Sym().origin, edge:ONext():Sym().origin) and
			CCW(edge.origin, edge:OPrev():Sym().origin, edge:Sym().origin) then

			--Acquire the *unset* origin points that we are going to set
			local LeftVPoint = edge:ONext():InvRot().origin or edge:LNext():Rot().origin
			local RightVPoint = edge:OPrev():Rot().origin or edge:RPrev():InvRot().origin

			--Acquire the Edges in the QEdge which will become Voronoi Edges
			local alpha = Qedge[edge.index + 1] 	--same as Rot
			local beta = Qedge[edge.index + 3]  	--same as InvRot

			--The main takeaway of this loop is that a QEdge:Rot().origin get's a VPoint as opposed to a DPoint
			if not LeftVPoint then
				local x, y, _ = GetCircumCircle(edge.origin, edge:Sym().origin, edge:ONext():Sym().origin)
				LeftVPoint = VPoint.new(x, y)
				CircumCenters[#CircumCenters + 1] = LeftVPoint
			end
			if not RightVPoint then
				local x, y, _ = GetCircumCircle(edge.origin, edge:Sym().origin, edge:OPrev():Sym().origin)
				RightVPoint = VPoint.new(x, y)
				CircumCenters[#CircumCenters + 1] = RightVPoint
			end

			--@Important We don't call QEdge:setOrigin because it also adds the edge to the point's edge table.
			--	For VPoints, we don't want them pointing at DEdges.
			alpha.origin = LeftVPoint
			beta.origin = RightVPoint
		end
	end

	--The diagram is already finished, but we're merging symetric dual edges into a more concrete structure and
	--	creating cell objects to contain them.
	--It's technically a less general form, but the general form of quad edges is complex to navigate and fragile if changed.
	--If you do not want this processing, copying and pasting a specialized version of this function is ez pz.
	for i, edge in pairs(QEdges.Contents) do
		local TriEdge = edge[1]

		--Skip over outer edges again. They make weird artifacts.
		if TriEdge:Rot().origin == nil or TriEdge:InvRot().origin == nil then
			continue
		end

		local thisCell, otherCell = TriEdge.origin.Cell, TriEdge:Sym().origin.Cell
		if not thisCell then
			thisCell = Cell.new(TriEdge.origin)
			VCells[#VCells + 1] = thisCell
		end
		if not otherCell then
			otherCell = Cell.new(TriEdge:Sym().origin)
			VCells[#VCells + 1] = otherCell
		end

		local vEdge_a = TriEdge:Rot()
		local vEdge_b = TriEdge:InvRot()
		local vEdge = VEdge.new(vEdge_a.origin, vEdge_b.origin, thisCell, otherCell)

		VEdges[#VEdges + 1] = vEdge
	end

	for i = 1, #CircumCenters, 1 do
		local vPoint = CircumCenters[i]
		for j = 1, #vPoint.Edges, 1 do
			--Just do left cells to not add duplicates
			local cell = vPoint.Edges[j].LeftCell
			vPoint.VCells[#vPoint.VCells + 1] = cell
		end
	end

	--This loop is necessary because it's important to IslandGen that each cell has a duplicate-free complete list of points.
	--We're looping over cells because looping over the edges requires the edges to be made in a CW or CCW order that is consistent.
	for i = 1, #VCells, 1 do
		local cell = VCells[i]
		local firstEdge = cell.origin.Edge
		local curEdge = firstEdge
		repeat
			cell.Points[#cell.Points + 1] = curEdge:Rot().origin
			curEdge = curEdge:ONext()
		until curEdge == firstEdge
	end

	return VCells, VEdges, QEdges, CircumCenters
end

local PI_half = math.pi / 2
local PI = math.pi
local PI_2 = math.pi * 2
local PI_3 = math.pi * 3

local function RelativeAngles(p1, p2, hinge)
	local angleA = math.atan2(p1.X - hinge.X, p1.Y - hinge.Y)
	local angleB = math.atan2(p2.X - hinge.X, p2.Y - hinge.Y)

	local shortest_angle = ((((angleA - angleB) % PI_2) + PI_3) % PI_2) - PI

	return shortest_angle
end

--The final step of the triangulation, the edges are flipped if doing so would result in a lower aspect ratio triangle
local function MakeValid_recursive(e)
	if e.listRef.deleted == true then print(e.listRef.from) end
	local p1, p2 = e.origin, e:Sym().origin
	local eL, eR = e:LPrev(), e:DNext()
	local pL, pR = eL.origin, eR.origin

	if CCW(p1, p2, pL) then
		if CCW(p1, p2, pR) then
			return
		end
	elseif CCW(p2, p1, pR) then
		return
	end

	local new_edge
	if IsInCircle(p1, p2, pL, pR) then
		Kill(e)
		new_edge = MakeEdgeBetween(pL, pR)

		QuadEdge.Splice(new_edge, eL)
		QuadEdge.Splice(new_edge:Sym(), eR)

		--If the origin of parts of this edge were pointing to the deleted edge, we need to have them point to *some*
		--  valid connected edge
		eL:Sym().origin.Edge = eL:Sym()
		eL.origin.Edge = eL
		eR:Sym().origin.Edge = eR:Sym()
		eR.origin.Edge = eR

		MakeValid_recursive(new_edge:LPrev())
		MakeValid_recursive(new_edge:DPrev())
		MakeValid_recursive(new_edge:DNext())
		MakeValid_recursive(new_edge:RNext())

	elseif IsInCircle(p1, p2, pR, pL) then
		Kill(e)
		new_edge = MakeEdgeBetween(pL, pR)


		QuadEdge.Splice(new_edge, eL)
		QuadEdge.Splice(new_edge:Sym(), eR)

		eL:Sym().origin.Edge = eL:Sym()
		eL.origin.Edge = eL
		eR:Sym().origin.Edge = eR:Sym()
		eR.origin.Edge = eR

		MakeValid_recursive(new_edge:LPrev())
		MakeValid_recursive(new_edge:DPrev())
		MakeValid_recursive(new_edge:DNext())
		MakeValid_recursive(new_edge:RNext())
	end
end

--This function is used during triangulation, as opposed to the recursive version, because the recursive version
--	doesn't play well with unfinished triangulations.
local function MakeValid(e)
	local p1, p2 = e.origin, e:Sym().origin
	local eL, eR = e:LPrev(), e:DNext()
	local pL, pR = eL.origin, eR.origin

	local new_edge
	if IsInCircle(p1, p2, pL, pR) then
		Kill(e)
		new_edge = MakeEdgeBetween(pL, pR)

		QuadEdge.Splice(new_edge, eL)
		QuadEdge.Splice(new_edge:Sym(), eR)

		eL:Sym().origin.Edge = eL:Sym()
		eL.origin.Edge = eL
		eR:Sym().origin.Edge = eR:Sym()
		eR.origin.Edge = eR

	elseif IsInCircle(p1, p2, pR, pL) then
		Kill(e)
		new_edge = MakeEdgeBetween(pL, pR)

		QuadEdge.Splice(new_edge, eL)
		QuadEdge.Splice(new_edge:Sym(), eR)

		eL:Sym().origin.Edge = eL:Sym()
		eL.origin.Edge = eL
		eR:Sym().origin.Edge = eR:Sym()
		eR.origin.Edge = eR
	end
end

function Delaunay.Triangulate(points: Array<DPoint>)
	EdgeList = FA.new()

	--Select O: the origin of the sweeping circle
	local maxx, minx, maxy, miny = 0, math.huge, 0, math.huge
	for i = 1, #points, 1 do
		local p = points[i]
		if p.X < minx then minx = p.X end
		if p.X > maxx then maxx = p.X end
		if p.Y < miny then miny = p.Y end
		if p.Y > maxy then maxy = p.Y end
	end

	local O = { X = ( maxx + minx ) / 2, Y = ( maxy + miny ) / 2 }

	--Assign points radius and thetas relative to O. So, polar coordinates are centered at point O.
	local Ox, Oy = O.X, O.Y
	for i = 1, #points, 1 do
		local p = points[i]
		local px = p.X
		local py = p.Y

		local r = math.sqrt( (px - Ox) ^ 2 + (py - Oy) ^ 2)
		local theta
		--TODO: Check for the case of py - Oy == 0
		if px - Ox > 0 then
			theta = math.acos( (py - Oy) / r )
		else
			theta = math.acos( (Oy - py) / r )
			theta += PI
		end
		p.r = r
		p.theta = theta
	end

	--Sort by radius; theta is used as backup for sorting
	DPoint.Polar_Sort(points)

	--Forming the initial triangle. We first have to determine which point will be the third, because it must be the
	--  first point which in a linear search which can form a triangle containing the origin, O
	--The paper suggests that the first 3 points are always available as the basis for the first triangle, but this has
	--  proven false in this implementation, somehow. Logically, I'm not sure how it could be true, anyway.
	local first, second, third = points[1], points[2], points[3]
	local third_idx = 3
	if CCW(first, second, O) then
		for i = 3, #points, 1 do
			third = points[i]
			if CCW(second, third, O) then
				if CCW(third, first, O) then
					third_idx = i
					break
				end
			end
		end
	elseif CCW(second, first, O) then
		for i = 3, #points, 1 do
			third = points[i]
			if CCW(third, second, O) then
				if CCW(first, third, O) then
					third_idx = i
					break
				end
			end
		end
	end

	--Note that the first and second points aren't removed, because that's slower than just skipping over them.
	--But since the third point can, in theory, be anywhere, we remove it to keep the array of points cohesive
	table.remove(points, third_idx)

	local hull_edge = TriangleFromPoints({first, second, third})

	for i = 3, #points, 1 do
		local P = points[i]

		--[[
			Find the edge that P is across from
		]]
		local candidate = hull_edge
		local final_edge = nil
		repeat
			local CCPoint = candidate.origin
			local CPoint = candidate:Sym().origin

			--Angle increases as we move CW, so if CPoint.theta < CCPoint.theta, CPoint has crossed over 2*pi
			if CCPoint.theta < CPoint.theta then
				--Bit of a trick here: Since CCPoint and CPoint are on opposite sides of P (when it is found), we only
				--  need to know if P is on the correct side of *either* point
				if CCPoint.theta > P.theta or P.theta > CPoint.theta then
					final_edge = candidate
					break
				end
			elseif CCPoint.theta > P.theta and P.theta > CPoint.theta then
				final_edge = candidate
				break
			end

			candidate = candidate:LNext()
		until candidate.origin == hull_edge.origin

		--This shouldn't happen, but if it does, lets not crash.
		if final_edge == nil then break end

		local CWEdge = MakeEdgeBetween(final_edge.origin, P)
		QuadEdge.Splice(CWEdge, final_edge)

		--The `Connect` function is causing a lot of trouble so I'm splicing manually after the re-write.
		local CCWEdge = MakeEdgeBetween(P, final_edge:Sym().origin)
		QuadEdge.Splice(CCWEdge:Sym(), final_edge:LNext())
		QuadEdge.Splice(CCWEdge, CWEdge:Sym())

		--Now that we have a new triangle, we need to validate the edge that this triangle stems from.
		--	It may need to be flipped.
		--	Also, the benchmarks show that it's faster to always call the recursive validation even if we call it on
		--		all edges again after the triangulation is finished.
		--  However, to reduce the probability of bugs we've reverted back to normal MakeValid. The recursive one seems to not like unfinished hulls. No idea why.
		MakeValid(final_edge)

		--Left-side walk.
		while true do
			local ang = RelativeAngles(CCWEdge:DPrev().origin, CCWEdge.origin, CCWEdge:Sym().origin)
			if ang > -( PI_half ) and ang < 0.0 then
				local NewLeftEdge = MakeEdgeBetween(CCWEdge.origin, CCWEdge:DPrev().origin)

				--Remember, splicing makes arg1 the LEFT / CCW of arg2, relative to the origin point they share.
				QuadEdge.Splice(NewLeftEdge:Sym(), CCWEdge:DPrev():OPrev())
				QuadEdge.Splice(NewLeftEdge, CCWEdge)

				MakeValid(CCWEdge:DNext())
				CCWEdge = NewLeftEdge
			else
				break
			end
		end

		--Right-side walk.
		while true do
			local ang = RelativeAngles(CWEdge:LPrev().origin, CWEdge:Sym().origin, CWEdge.origin)
			--opposite check as walking left
			if ang < ( PI_half ) and ang > 0.0 then
				local NewRightEdge = MakeEdgeBetween(CWEdge:LPrev().origin, CWEdge:Sym().origin)

				QuadEdge.Splice(NewRightEdge:Sym(), CCWEdge)
				QuadEdge.Splice(NewRightEdge, CWEdge:LPrev())

				MakeValid(CWEdge:OPrev())
				CWEdge = NewRightEdge
			else
				break
			end
		end

		--Potential TODO: @optimization: check the next point's theta to see if we should direct CW or CCW around the hull.
		hull_edge = CCWEdge
	end

	for i, edge in pairs(EdgeList.Contents) do
		MakeValid_recursive( edge[1] )
	end

	local edges = EdgeList
	EdgeList = nil

	return edges, O
end

function Delaunay.Voronoi(points: Array<DPoint>): (Array<VCell>, Array<VEdge>, FastArray, Array<VPoint>)
	local triangulation, _ = Delaunay.Triangulate(points)

	local Cells, Edges, QEdges, CircumCenters = GetVoronoi(triangulation)

	return Cells, Edges, QEdges, CircumCenters
end

return Delaunay
