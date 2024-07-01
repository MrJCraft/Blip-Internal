package load_obj

import "core:math"
import "../profile"
import "core:fmt"
import "core:simd"

fast_triangle :: struct {
		bx, by : f32,
    v0x, v0y: f32,
		v1x, v1y: f32,
    d00, d01 : f32,
    denom, d11 : f32,
		uvs : [3]u32,
		index : int,
}

BVH :: struct {
		direction : Dir,
		width, length : int,
		// Volumes stores an index into the Model
		buckets : [][]#soa[dynamic]fast_triangle,
		//         width    length   Index
}

delete_BVH :: proc(bvh : ^BVH) {
		assert(false,"not implemented")
}

/* Model.xmin Model.xmax */
/* Model.ymin Model.ymax */
/* Model.zmin Model.zmax */

tri_to_fast_tri :: proc(model : ^Obj,  input : Triangle, index : int, dir : Dir) -> fast_triangle {
		first, last : int
		switch dir {
		case .x: first = 1; last = 2;
		case .y: first = 0; last = 2;
		case .z: first = 0; last = 1;
		}

		tri : fast_triangle
		a := model.points[input.iverts[0]-1]
		b := model.points[input.iverts[1]-1]
		c := model.points[input.iverts[2]-1]
		tri.bx = a[first]
		tri.by = a[last]
		tri.v0x = b[first] - a[first]
		tri.v0y = b[last] - a[last]
		tri.v1x = c[first] - a[first]
		tri.v1y = c[last] - a[last]
		tri.d00 = dot(tri.v0x, tri.v0y, tri.v0x, tri.v0y)
		tri.d01 = dot(tri.v0x, tri.v0y, tri.v1x, tri.v1y)
		tri.d11 = dot(tri.v1x, tri.v1y, tri.v1x, tri.v1y)
		tri.index = index
		tri.uvs = input.uv
		/* fmt.println(tri.d00 * tri.d11 , tri.d01 * tri.d01) */
		tri.denom = tri.d00 * tri.d11 - tri.d01 * tri.d01
		return tri
}


init_BVH :: proc(Model : ^Obj, dir : Dir, volume : ^BVH) -> ^BVH {
		width : f32 = 0
		length : f32 = 0
		first := 0
		last := 0
		bottom : [3]f32 = {Model.xmin, Model.ymin, Model.zmin,}
		top : [3]f32 = {Model.xmax, Model.ymax, Model.zmax,}
		switch dir {
		case .x: width = math.ceil(math.abs(Model.ymax - Model.ymin)); length = math.ceil(math.abs(Model.zmax - Model.zmin)); first = 1; last = 2;
		case .y: width = math.ceil(math.abs(Model.xmax - Model.xmin)); length = math.ceil(math.abs(Model.zmax - Model.zmin)); first = 0; last = 2;
		case .z: width = math.ceil(math.abs(Model.xmax - Model.xmin)); length = math.ceil(math.abs(Model.ymax - Model.ymin)); first = 0; last = 1;
		}

		diff : f32 = width / length
		density :: 4
		w : int = cast(int) math.sqrt(cast(f32) len(Model.triangles) / density / diff)
		l : int = w*cast(int)diff
		if w == 0 {
				w = 1
		}
		if l == 0 {
				l = 1
		}
		volume.width = w
		volume.length = l

		extra :: 1
		volume.direction = dir
		volume.buckets = make([][]#soa[dynamic]fast_triangle,w+extra)
		for &v in volume.buckets {
				v = make([]#soa[dynamic]fast_triangle,l+extra)
		}
		/* buckets := make([][256]int,w*l) */

		/* resize(&volume.buckets, w)  */
		/* resize(&volume.buckets[], w)  */

		// is it on the right or left
		// recursively
		
		for triangle, index in Model.triangles {
				
				a : #simd[4]f32
				b : #simd[4]f32
				c : #simd[4]f32
				a = vector_to_simd(Model.points[triangle.iverts[0]-1])
				b = vector_to_simd(Model.points[triangle.iverts[1]-1])
				c = vector_to_simd(Model.points[triangle.iverts[2]-1])
				ma := simd.max(simd.max(a,b), c)
				mi := simd.min(simd.min(a,b), c)

				posf := []f32{(simd.to_array(mi)[first]-bottom[first])/width,
											(simd.to_array(mi)[last]-bottom[last])/length,
										 }
				posm := []f32{(simd.to_array(ma)[first]-bottom[first])/width,
											(simd.to_array(ma)[last]-bottom[last])/length,
										 }
				/* fmt.println(simd.to_array(ma)[first], simd.to_array(ma)[last], simd.to_array(mi)[first], simd.to_array(mi)[last], cast(int)math.floor(posf[0]*cast(f32)w), cast(int)math.floor(posm[0]*cast(f32)w), width, length) */
				// TODO I have no idea if this works
				for j in cast(int)math.floor(posf[0]*cast(f32)w)..=cast(int)math.floor(posm[0]*cast(f32)w) {
						for b in cast(int)math.floor(posf[1]*cast(f32)l)..=cast(int)math.floor(posm[1]*cast(f32)l) {
								append_soa(&volume.buckets[j][b], tri_to_fast_tri(Model, Model.triangles[index], index, dir))
						}
				}


		}

		return volume
}



bvh_dir :: struct {
		width : f32,
		length : f32,
		first : int,
		last : int,
}

init_BVH_box :: proc(Model : ^Obj, volume : [3]^BVH) -> [3]^BVH {
		profile.timeBlock()
		volumex := volume[0]
		volumey := volume[1]
		volumez := volume[2]

		width : f32 = 0
		length : f32 = 0
		first := 0
		last := 0
		bottom : [3]f32 = {Model.xmin, Model.ymin, Model.zmin,}
		top : [3]f32 = {Model.xmax, Model.ymax, Model.zmax,}

		xd : bvh_dir
		yd : bvh_dir
		zd : bvh_dir
		xd.width = math.ceil(math.abs(Model.ymax - Model.ymin))
		xd.length = math.ceil(math.abs(Model.zmax - Model.zmin))
		xd.first = 1
		xd.last = 2
		yd.width = math.ceil(math.abs(Model.xmax - Model.xmin))
		yd.length = math.ceil(math.abs(Model.zmax - Model.zmin))
		yd.first = 0
		yd.last = 2
		zd.width = math.ceil(math.abs(Model.xmax - Model.xmin))
		zd.length = math.ceil(math.abs(Model.ymax - Model.ymin))
		zd.first = 0
		zd.last = 1

		xdiff : f32 = xd.width / xd.length
		ydiff : f32 = yd.width / yd.length
		zdiff : f32 = zd.width / zd.length
		density :: 2
		wx : int = cast(int) math.sqrt(cast(f32) len(Model.triangles) / density / xdiff)
		lx : int = wx*cast(int)xdiff

		wy : int = cast(int) math.sqrt(cast(f32) len(Model.triangles) / density / ydiff)
		ly : int = wy*cast(int)ydiff

		wz : int = cast(int) math.sqrt(cast(f32) len(Model.triangles) / density / zdiff)
		lz : int = wz*cast(int)zdiff

		if wx == 0 {
				wx = 1
		}
		if lx == 0 {
				lx = 1
		}

		if wy == 0 {
				wy = 1
		}
		if ly == 0 {
				ly = 1
		}
		if wz == 0 {
				wz = 1
		}
		if lz == 0 {
				lz = 1
		}
		volumex.width = wx
		volumex.length = lx

		volumey.width = wy
		volumey.length = ly

		volumez.width = wz
		volumez.length = lz

		extra :: 2

		volumex.direction = Dir.x
		volumex.buckets = make([][]#soa[dynamic]fast_triangle,wx+extra)
		for &v in volumex.buckets {
				v = make([]#soa[dynamic]fast_triangle,lx+extra)
		}

		volumey.direction = Dir.y
		volumey.buckets = make([][]#soa[dynamic]fast_triangle,wy+extra)
		for &v in volumey.buckets {
				v = make([]#soa[dynamic]fast_triangle,ly+extra)
		}

		volumez.direction = Dir.z
		volumez.buckets = make([][]#soa[dynamic]fast_triangle,wz+extra)
		for &v in volumez.buckets {
				v = make([]#soa[dynamic]fast_triangle,lz+extra)
		}
		/* buckets := make([][256]int,w*l) */

		/* resize(&volume.buckets, w)  */
		/* resize(&volume.buckets[], w)  */

		// is it on the right or left
		// recursively
		for triangle, index in Model.triangles {
				
				a : #simd[4]f32
				b : #simd[4]f32
				c : #simd[4]f32
				a = vector_to_simd(Model.points[triangle.iverts[0]-1])
				b = vector_to_simd(Model.points[triangle.iverts[1]-1])
				c = vector_to_simd(Model.points[triangle.iverts[2]-1])
				ma := simd.max(simd.max(a,b), c)
				mi := simd.min(simd.min(a,b), c)

				posfx := []f32{(simd.to_array(mi)[xd.first]-bottom[xd.first])/xd.width,
											(simd.to_array(mi)[xd.last]-bottom[xd.last])/xd.length,
										 }
				posmx := []f32{(simd.to_array(ma)[xd.first]-bottom[xd.first])/xd.width,
											(simd.to_array(ma)[xd.last]-bottom[xd.last])/xd.length,
										 }

				posfy := []f32{(simd.to_array(mi)[yd.first]-bottom[yd.first])/yd.width,
											(simd.to_array(mi)[yd.last]-bottom[yd.last])/yd.length,
										 }
				posmy := []f32{(simd.to_array(ma)[yd.first]-bottom[yd.first])/yd.width,
											(simd.to_array(ma)[yd.last]-bottom[yd.last])/yd.length,
										 }

				posfz := []f32{(simd.to_array(mi)[zd.first]-bottom[zd.first])/zd.width,
											(simd.to_array(mi)[zd.last]-bottom[zd.last])/zd.length,
										 }
				posmz := []f32{(simd.to_array(ma)[zd.first]-bottom[zd.first])/zd.width,
											(simd.to_array(ma)[zd.last]-bottom[zd.last])/zd.length,
										 }
				/* fmt.println(simd.to_array(ma)[first], simd.to_array(ma)[last], simd.to_array(mi)[first], simd.to_array(mi)[last], cast(int)math.floor(posf[0]*cast(f32)w), cast(int)math.floor(posm[0]*cast(f32)w), width, length) */
				// TODO I have no idea if this works
				for j in cast(int)math.floor(posfx[0]*cast(f32)wx)..=cast(int)math.floor(posmx[0]*cast(f32)wx) {
						for b in cast(int)math.floor(posfx[1]*cast(f32)lx)..=cast(int)math.floor(posmx[1]*cast(f32)lx) {
								append_soa(&volumex.buckets[j][b], tri_to_fast_tri(Model, Model.triangles[index], index, Dir.x))
						}
				}

				for j in cast(int)math.floor(posfy[0]*cast(f32)wy)..=cast(int)math.floor(posmy[0]*cast(f32)wy) {
						for b in cast(int)math.floor(posfy[1]*cast(f32)ly)..=cast(int)math.floor(posmy[1]*cast(f32)ly) {
								append_soa(&volumey.buckets[j][b], tri_to_fast_tri(Model, Model.triangles[index], index, Dir.y))
						}
				}

				for j in cast(int)math.floor(posfz[0]*cast(f32)wz)..=cast(int)math.floor(posmz[0]*cast(f32)wz) {
						for b in cast(int)math.floor(posfz[1]*cast(f32)lz)..=cast(int)math.floor(posmz[1]*cast(f32)lz) {
								append_soa(&volumez.buckets[j][b], tri_to_fast_tri(Model, Model.triangles[index], index, Dir.z))
						}
				}


		}

		result : [3]^BVH = {volumex,volumey,volumez}
		return result
}


vector_to_simd :: proc(a : [3]f32) -> #simd[4]f32 {
		return #simd[4]f32 {a.x,a.y,a.z,0}
}


