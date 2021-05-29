local VEdge = { }

function VEdge.new( origin: VPoint, destination: VPoint, leftCell: Cell, rightCell: Cell )
	local t = {
		origin = origin,
		destination = destination,
		LeftCell = leftCell,
		RightCell = rightCell,
	}

	leftCell:addEdge(t)
	rightCell:addEdge(t)
	origin:addEdge(t)
	destination:addEdge(t)
	origin:addNeighboringPoint(destination)
	destination:addNeighboringPoint(origin)

	return t
end

return VEdge