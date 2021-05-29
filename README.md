# Sweep-circle Delaunay Triangulation
(and voroni diagrams)

![](https://i.imgur.com/9oMfjzU.png)

In blue is the triangulation; in red are the voronoi cells derived from it. The point locations are purely random.

[Video of the process](https://i.imgur.com/azsskqC.mp4) throttled to ~10 points per second

## Disclaimers
1) This is not *quite* a library! It's a reference implementation that *can* be used and drawn from, but I stopped developing this once it satisfied the needs of the project I was using it for.
    * The outside of the triangulation is left unfinished (the final hull will not be convex).
    * Colinear points are not guarded against
2) The code displayed has been modified slightly to break some ties it has to the codebase I developed it in. These changes are minor and should not impact the way the code functions (e.g. different `require` paths), but they are untested nonetheless.
3) This occasionally uses Luau syntax and flavors.
4) Benchmarks, videos, and screenshots are from inside a game that this code is used in, so forgive the backgrounds :^).

## Example Usage
```lua
	local DPoint = require(--[[Path to DPoint]])
	local Delaunay = require(--[[Path to Delaunay folder]])

	local k = 100
	local points = table.create(k)
	for i = 1, k, 1 do
		points[i] = DPoint.new(math.random() * 1000, math.random() * 1000)
	end

	--Do everything
	local Cells, Edges, QEdges, CircumCenters = Delaunay.Voronoi(points)
	--Just triangulate
	local QEdges, O = Delaunay.Triangulate(points)
```

## Choice in algorithm:

We initially used the classic Divide-and-Conquer delaunay algorithm, but persistent issues realted to ultra-high-aspect-ratio triangles on dense point sets (~28,000 points in a 2,000x2,000 square) could not be resolved; ultimately we concluded that Roblox's Luau optimizations were the cause. It's unknown if these issues would persist in other Lua environments. The Sweep-Circle algorithm was selected because it's unlikely to form such triangles, and indeed we do not run into this type of issue anymore.

This implementation is based on the Sweep-Circle algorithm in [this paper](https://cglab.ca/~biniaz/papers/Sweep%20Circle.pdf). We utilize the [QuadEdge data structure](http://www.cs.cmu.edu/afs/andrew/scs/cs/15-463/2001/pub/src/a2/quadedge.html) for navigating the triangulation's topology. Our specific implementation of QEdges comes from [this repository](https://github.com/jtwaugh/Delaunay), which in turn used the aformentioned QuadEdge page for its implementation.

## Performance

It's... reasonable, considering the language. Function inlining, real arrays, and access to array-pointer logic would make this a whole lot faster.

These samples were taken from an in-game benchmark; point distribution is purely random from (0, 10,000]

Points Ct. | Time (s)
----- | -----
55,000 | 16.3269
45,000 | 11.8009
35,000 | 8.2465
25,000 | 4.9367
5,000 | 2.5130

# Acknowledgements

Algorithm: [Ahmad Biniaz and Gholamhossein Dastghaibyfard. A faster circle-sweep Delaunay triangulation algorithm](https://cglab.ca/~biniaz/papers/Sweep%20Circle.pdf)

QuadEdge spec: [Paul Heckbert](http://www.cs.cmu.edu/afs/andrew/scs/cs/15-463/2001/pub/src/a2/quadedge.html)

Reference QuadEdge Usage (also derrived on Paul Heckbert's teachings): https://github.com/jtwaugh/Delaunay @jtwaugh