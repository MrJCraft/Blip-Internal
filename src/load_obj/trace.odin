package load_obj

import td "core:math/linalg"
import "../profile"
import "core:math"
import "core:fmt"
import "core:simd"
import "core:mem"

//import png "core:image/png"
// I need to do precomputation and put the triangles into a spatial partition
// I need to simplify the ray tracing code
// I need to swap over all structures that are soa to aos and use the language feature instead

f32x16 :: simd.f32x16
boolx16 :: simd.boolx16

simd_size  :: 16

Vector3 :: struct {
		x : f32,
		y : f32,
		z : f32,
}


Dir :: enum u16 {
		x = 0,
		y = 1,
		z = 2,
}

//Test Package
Ray :: struct {
		o : [3]f32,
		dir : [3]f32,
		t : f32,
}

scale : f32 = 1

simd_dot :: proc(ax, ay, bx, by : #simd[16]f32) -> #simd[16]f32 {
		return (ax * bx) + (ay * by)
}

dot :: proc(ax, ay, bx, by : f32) -> f32 {
		return (ax * bx) + (ay * by)
}

bary_to_xyz :: proc (u, v, w, : f32, p0, p1, p2 : [3]f32) -> [3]f32
{
      return u * p0 + v * p1 + w * p2;
}

//TODO create an Optimized version of this, using barecentric coordinates and precomputation
ray_intersects_triangle :: proc (ray : Ray, triangle : [3][3]f32) -> ([3]f32, f32, f32, bool) // hit point, u, v, did it hit
{
		u : f32
		v : f32
		epsilon :: 0.0001
    edge1 : [3]f32 = triangle[1] - triangle[0]
    edge2 : [3]f32 = triangle[2] - triangle[0]
    ray_cross_e2 : [3]f32 = td.cross(ray.dir, edge2)
    det : f32 = td.dot(edge1, ray_cross_e2)

    if (det > -epsilon && det < epsilon) {
        return {0,0,0},0,0, false    // This ray is parallel to this triangle.
		}

    inv_det : f32 = 1.0 / det
    s : [3]f32 = ray.o - triangle[0]
    u = inv_det * td.dot(s, ray_cross_e2)

    if (u < 0 || u > 1) {
        return {0,0,0},0,0, false
		}

    s_cross_e1 : [3]f32 = td.cross(s, edge1)
    v = inv_det * td.dot(ray.dir , s_cross_e1)

    if (v < 0 || u + v > 1) {
        return {0,0,0},0,0, false
		}
		//vector 
    // At this stage we can compute t to find out where the intersection point is on the line.
    t : f32 = inv_det * td.dot(edge2, s_cross_e1)

    if (t > epsilon) // ray intersection
    {
        return ray.o + ray.dir * t, u, v, true
    } else {
        return {0,0,0},0,0, false
		}
}


simd_aligned_ray_triangle_intersection :: proc(x, y : simd.f32x16, tri : #soa[]fast_triangle) -> (f32x16, f32x16, f32x16) //u v w
{
		bx : f32x16
		by : f32x16
		v0x : f32x16
		v0y : f32x16
		v1x : f32x16
		v1y : f32x16
		d00 : f32x16
		d01 : f32x16
		denom : f32x16
		d11 : f32x16
		if len(tri) < 16 {
				bx = simd.from_slice(f32x16,tri.bx[0:16])
				by = simd.from_slice(f32x16,tri.by[0:16])
				v0x = simd.from_slice(f32x16,tri.v0x[0:16])
				v0y = simd.from_slice(f32x16,tri.v0y[0:16])
				v1x = simd.from_slice(f32x16,tri.v1x[0:16])
				v1y = simd.from_slice(f32x16,tri.v1y[0:16])
				d00 = simd.from_slice(f32x16,tri.d00[0:16])
				d01 = simd.from_slice(f32x16,tri.d01[0:16])
				denom = simd.from_slice(f32x16,tri.denom[0:16])
				d11 = simd.from_slice(f32x16,tri.d11[0:16])
		} else {
				mem.copy(&bx, &tri.bx[0], len(tri)*4)
				mem.copy(&by, &tri.by[0], len(tri)*4)
				mem.copy(&v0x, &tri.v0x[0], len(tri)*4)
				mem.copy(&v0y, &tri.v0y[0], len(tri)*4)
				mem.copy(&v1x, &tri.v1x[0], len(tri)*4)
				mem.copy(&v1y, &tri.v1y[0], len(tri)*4)
				mem.copy(&d00, &tri.d00[0], len(tri)*4)
				mem.copy(&d01, &tri.d01[0], len(tri)*4)
				mem.copy(&denom, &tri.denom[0], len(tri)*4)
				mem.copy(&d11, &tri.d11[0], len(tri)*4)
		}
		/* temp : [16]f32 */

		v2x: f32x16 = x - bx
		v2y: f32x16 = y - by
		d20 : f32x16 = simd_dot(v2x,v2y , v0x, v0y)
		d21 : f32x16 = simd_dot(v2x,v2y , v1x, v1y)

		v : f32x16 = (d11 * d20 - d01 * d21) / denom
		w : f32x16 = (d00 * d21 - d01 * d20) / denom
		u : f32x16 = cast(f32x16) 1 - v - w

		return u,v,w
}

/* xy_to_barycentric :: proc([2]f32 p, [2]f32 a, [2]f32 b, [2]f32 c,) -> (f32, f32, f32) //u v w */
/* { */
/*     v0: [2]f32 = b - a */
/* 		v1: [2]f32 = c - a */
/* 		v2: [2]f32 = p - a */
/* 		// precalculate this most of this */
/*     d00 : f32 = Dot(v0, v0) */
/*     d01 : f32 = Dot(v0, v1) */
/*     d11 : f32 = Dot(v1, v1) */
/*     d20 : f32 = Dot(v2, v0) */
/*     d21 : f32 = Dot(v2, v1) */
/*     denom : f32 = d00 * d11 - d01 * d01 */
/*     v : f32 = (d11 * d20 - d01 * d21) / denom */
/*     w : f32 = (d00 * d21 - d01 * d20) / denom */
/*     u : f32 = 1.0f - v - w */
/* } */





// I should problably make a few other versions of this, and try out different ideas
// I could do a box so all the values are the same
// I could do each side as a different thread so there would be no reason to do it as a box
trace :: proc(Model : ^Obj) -> Ruct {
		/* pal := clr.create_block_map("pal/") */
		/* defer clr.delete_block_map(pal) */
		/* rucmatic.blocks = make([]u8, Model.width*Model.height) */
		/* rucmatic.colors = make([][4]u8, Model.width*Model.height) */
		ret : Ruct
		ret.colors = make([dynamic][4]u8, 0)
		ret.pos = make([dynamic][3]f32, 0)
		offset :: 0
		ray : Ray
		ray.o = {0,0,0}
		ray.dir = [3]f32{0,-1,0}
		//pos : [3]f32
		j := 0
		// TODO turn this into a function
		triangles := Model.triangles
		for x in Model.xmin-offset..<(Model.xmax+offset)*scale {
				for z in Model.zmin-offset..<(Model.zmax+offset)*scale {
						for tri, _ in triangles {
								ray.o = {x/scale, Model.ymax, z/scale}
								triangle : [3][3]f32 = {Model.points[tri.iverts[0]-1], Model.points[tri.iverts[1]-1], Model.points[tri.iverts[2]-1]}
								//TODO these could be broken

								if(triangle[0][0] > ray.o[0] && triangle[1][0] > ray.o[0] && triangle[2][0] > ray.o[0] ||
									 triangle[0][0] < ray.o[0] && triangle[1][0] < ray.o[0] && triangle[2][0] < ray.o[0] ||
									 triangle[0][2] > ray.o[2] && triangle[1][2] > ray.o[2] && triangle[2][2] > ray.o[2] ||
									 triangle[0][2] < ray.o[2] && triangle[1][2] < ray.o[2] && triangle[2][2] < ray.o[2]) {
										continue
								}

								pos, u, v, b := ray_intersects_triangle(ray,triangle)
								// this is the point uv and is relative to the triangle

								if b {
										j += 1
										a := Model.uvs[tri.uv[0]-1]
										b := Model.uvs[tri.uv[1]-1]
										c := Model.uvs[tri.uv[2]-1]
										w := 1-u-v
										puv := u*a+v*b+w*c
										// PUV Hit UV to Image
										color := uv_to_color(puv, Model.img)
										append(&ret.colors, color)
										append(&ret.pos, pos)
										//fmt.printf("execute if score timer timer matches %d run setblock ~%d ~%d ~%d %s\n",j/1000, cast(i32)pos[0], cast(i32)pos[1], cast(i32)pos[2], clr.color_to_block(color, &pal))
										//fmt.println(color)
								}
						}
				}
		}

		j = 0
		ray.dir = [3]f32{1,0,0}
		for y in Model.ymin-offset..<(Model.ymax+offset)*scale {
				for z in Model.zmin-offset..<(Model.zmax+offset)*scale {
						for tri in triangles {
								ray.o = {Model.xmin, y/scale, z/scale}

								triangle : [3][3]f32 = {Model.points[tri.iverts[0]-1], Model.points[tri.iverts[1]-1], Model.points[tri.iverts[2]-1]}

								if(triangle[0][1] > ray.o[1] && triangle[1][1] > ray.o[1] && triangle[2][1] > ray.o[1] ||
									 triangle[0][1] < ray.o[1] && triangle[1][1] < ray.o[1] && triangle[2][1] < ray.o[1] ||
									 triangle[0][2] > ray.o[2] && triangle[1][2] > ray.o[2] && triangle[2][2] > ray.o[2] ||
									 triangle[0][2] < ray.o[2] && triangle[1][2] < ray.o[2] && triangle[2][2] < ray.o[2]) {
										continue
								}

								pos, u, v,b := ray_intersects_triangle(ray,triangle)

								if b {
										j += 1
										a := Model.uvs[tri.uv[0]-1]
										b := Model.uvs[tri.uv[1]-1]
										c := Model.uvs[tri.uv[2]-1]
										w := 1-u-v
										puv := u*a+v*b+w*c
										// PUV Hit UV to Image
										color := uv_to_color(puv, Model.img)

										append(&ret.colors, color)
										append(&ret.pos, pos)
										//fmt.printf("execute if score timer timer matches %d run setblock ~%d ~%d ~%d %s\n",j/1000, cast(i32)pos[0], cast(i32)pos[1], cast(i32)pos[2], clr.color_to_block(color, &pal))
								}
						}
				}
		}

		j = 0
		ray.dir = [3]f32{0,0,1}
		for y in Model.ymin-offset..<(Model.ymax+offset)*scale {
				for x in Model.xmin-offset..<(Model.xmax+offset)*scale {
						for tri in triangles {
								ray.o = {x/scale, y/scale, Model.zmin}

								triangle : [3][3]f32 = {Model.points[tri.iverts[0]-1], Model.points[tri.iverts[1]-1], Model.points[tri.iverts[2]-1]}

								if(triangle[0][1] > ray.o[1] && triangle[1][1] > ray.o[1] && triangle[2][1] > ray.o[1] ||
									 triangle[0][1] < ray.o[1] && triangle[1][1] < ray.o[1] && triangle[2][1] < ray.o[1] ||
									 triangle[0][0] > ray.o[0] && triangle[1][0] > ray.o[0] && triangle[2][0] > ray.o[0] ||
									 triangle[0][0] < ray.o[0] && triangle[1][0] < ray.o[0] && triangle[2][0] < ray.o[0]) {
										continue
								}

								pos, u, v, b := ray_intersects_triangle(ray,triangle)

								if b {
										j += 1
										a := Model.uvs[tri.uv[0]-1]
										b := Model.uvs[tri.uv[1]-1]
										c := Model.uvs[tri.uv[2]-1]
										w := 1-u-v
										puv := u*a+v*b+w*c
										// PUV Hit UV to Image
										color := uv_to_color(puv, Model.img)

										append(&ret.colors, color)
										append(&ret.pos, pos)

										//fmt.printf("execute if score timer timer matches %d run setblock ~%d ~%d ~%d %s\n",j/1000, cast(i32)pos[0], cast(i32)pos[1], cast(i32)pos[2], clr.color_to_block(color, &pal))
								}
						}
				}
		}
		return ret
}








/* ray : Ray */
/* ray.dir = [3]f32{0,1,0} */
/* ray.dir = [3]f32{1,0,0} */
/* ray.dir = [3]f32{0,0,1} */

/* ret : Ruct */
/* ret.colors = make([dynamic][4]u8, 0) */
/* ret.pos = make([dynamic][3]f32, 0) */

/* trace_face :: proc(Model : ^Obj,ret : ^Ruct, ray : Ray) -> Ruct { */

trace_face :: proc(Model : ^Obj, ret : ^Ruct, ray : Ray) -> ^Ruct {
		ray := ray


		face_dir : Dir
		width : [2]f32
		length : [2]f32
		first, last : int
		mins : [3]f32 = {Model.xmin, Model.ymin, Model.zmin}

		switch ray.dir {
		case {0, 1, 0}: width = {Model.xmin, Model.xmax}; length = {Model.zmin, Model.zmax}; first = 0; last = 2; face_dir = Dir.y;
		case {1, 0, 0}: width = {Model.ymin, Model.ymax}; length = {Model.zmin, Model.zmax}; first = 1; last = 2; face_dir = Dir.x;
		case {0, 0, 1}: width = {Model.xmin, Model.xmax}; length = {Model.ymin, Model.ymax}; first = 0; last = 1; face_dir = Dir.z;
				case: assert(false, "I only test 0 1 0, 1 0 0, 0 0 1,");
		}

		offset :: 0
		/* j := 0 */
		// TODO turn this into a function
		triangles := Model.triangles
		for x in width[0]-offset..<(width[1]+offset)*scale {
				for z in length[0]-offset..<(length[1]+offset)*scale {
						for tri, _ in triangles {
								ray.o[first] = x/scale;
								ray.o[last] = z/scale;
								ray.o[face_dir] = mins[face_dir];
								/* ray.o = {x/scale, Model.ymax, z/scale} */
								/* ray.o = {Model.xmin, y/scale, z/scale} */
								/* ray.o = {x/scale, y/scale, Model.zmin} */
								triangle : [3][3]f32 = {Model.points[tri.iverts[0]-1], Model.points[tri.iverts[1]-1], Model.points[tri.iverts[2]-1]}
								//TODO these could be broken

								if(triangle[0][first] > ray.o[first] && triangle[1][first] > ray.o[first] && triangle[2][first] > ray.o[first] ||
									 triangle[0][first] < ray.o[first] && triangle[1][first] < ray.o[first] && triangle[2][first] < ray.o[first] ||
									 triangle[0][last] > ray.o[last] && triangle[1][last] > ray.o[last] && triangle[2][last] > ray.o[last] ||
									 triangle[0][last] < ray.o[last] && triangle[1][last] < ray.o[last] && triangle[2][last] < ray.o[last]) {
										continue
								}

								pos, u, v, b := ray_intersects_triangle(ray,triangle)
								// this is the point uv and is relative to the triangle

								if b {
										/* j += 1 */
										a := Model.uvs[tri.uv[0]-1]
										b := Model.uvs[tri.uv[1]-1]
										c := Model.uvs[tri.uv[2]-1]
										w := 1-u-v
										puv := u*a+v*b+w*c
										// PUV Hit UV to Image
										// I think it would be better to save all of the uvs and get the colors later but keep for now
										color := uv_to_color(puv, Model.img)
										append(&ret.colors, color)
										append(&ret.pos, pos)
										//fmt.printf("execute if score timer timer matches %d run setblock ~%d ~%d ~%d %s\n",j/1000, cast(i32)pos[0], cast(i32)pos[1], cast(i32)pos[2], clr.color_to_block(color, &pal))
										//fmt.println(color)
								}
						}
				}
		}

		return ret
}




/* trace_face_bvh2 :: proc(Model : ^Obj, ret : ^Ruct, ray : Ray, volume : ^BVH) -> ^Ruct { */
/* ray := ray */


/* face_dir : Dir */
/* width : [2]f32 */
/* length : [2]f32 */
/* first, last : int */
/* mins : [3]f32 = {Model.xmin, Model.ymin, Model.zmin} */

/* switch ray.dir { */
/* case {0, 1, 0}: width = {Model.xmin, Model.xmax}; length = {Model.zmin, Model.zmax}; first = 0; last = 2; face_dir = Dir.y; */
/* case {1, 0, 0}: width = {Model.ymin, Model.ymax}; length = {Model.zmin, Model.zmax}; first = 1; last = 2; face_dir = Dir.x; */
/* case {0, 0, 1}: width = {Model.xmin, Model.xmax}; length = {Model.ymin, Model.ymax}; first = 0; last = 1; face_dir = Dir.z; */
/* 		case: assert(false, "I only test 0 1 0, 1 0 0, 0 0 1,"); */
/* } */

/* offset :: 0 */
/* /\* j := 0 *\/ */
/* // TODO turn this into a function */
/* triangles := Model.triangles */
/* for x in width[0]-offset..<(width[1]+offset){ */
/* 		for z in length[0]-offset..<(length[1]+offset){ */

/* 				posx := int(math.floor(((x-width[0]+offset) / (width[1]-width[0]))*cast(f32)volume.width)) */
/* 				posz := int(math.floor(((z-length[0]+offset) / (length[1]-length[0]))*cast(f32)volume.length)) */

/* 				for itri, _ in volume.buckets[posx][posz] { */
/* 						tri := Model.triangles[itri] */
/* 						ray.o[first] = x; */
/* 						ray.o[last] = z; */
/* 						ray.o[face_dir] = mins[face_dir]; */
/* 						/\* ray.o[face_dir] = width[0]; *\/ */
/* 						triangle : [3][3]f32 = {Model.points[tri.iverts[0]-1], Model.points[tri.iverts[1]-1], Model.points[tri.iverts[2]-1]} */

/* 						if(triangle[0][first] > ray.o[first] && triangle[1][first] > ray.o[first] && triangle[2][first] > ray.o[first] || */
/* 							 triangle[0][first] < ray.o[first] && triangle[1][first] < ray.o[first] && triangle[2][first] < ray.o[first] || */
/* 							 triangle[0][last] > ray.o[last] && triangle[1][last] > ray.o[last] && triangle[2][last] > ray.o[last] || */
/* 							 triangle[0][last] < ray.o[last] && triangle[1][last] < ray.o[last] && triangle[2][last] < ray.o[last]) { */
/* 								continue */
/* 						} */

/* 						pos, u, v, b := ray_intersects_triangle(ray,triangle) */
/* 						// this is the point uv and is relative to the triangle */

/* 						if b { */
/* 								/\* j += 1 *\/ */
/* 								a := Model.uvs[tri.uv[0]-1] */
/* 								b := Model.uvs[tri.uv[1]-1] */
/* 								c := Model.uvs[tri.uv[2]-1] */
/* 								w := 1-u-v */
/* 								puv := u*a+v*b+w*c */
/* 								// PUV Hit UV to Image */
/* 								// I think it would be better to save all of the uvs and get the colors later but keep for now */
/* 								color := uv_to_color(puv, Model.img) */
/* 								append(&ret.colors, color) */
/* 								append(&ret.pos, pos) */
/* 								//fmt.printf("execute if score timer timer matches %d run setblock ~%d ~%d ~%d %s\n",j/1000, cast(i32)pos[0], cast(i32)pos[1], cast(i32)pos[2], clr.color_to_block(color, &pal)) */
/* 								//fmt.println(color) */
/* 						} */
/* 				} */
/* 		} */
/* } */

/* return ret */
/* } */


simd_trace_face_bvh :: proc(Model : ^Obj, ret : ^Ruct, ray : Ray, volume : ^BVH) -> ^Ruct {
		profile.timeBlock()
		ray := ray


		face_dir : Dir
		width : [2]f32
		length : [2]f32
		first, last : int
		mins : [3]f32 = {Model.xmin, Model.ymin, Model.zmin}

		switch ray.dir {
		case {0, 1, 0}: width = {Model.xmin, Model.xmax}; length = {Model.zmin, Model.zmax}; first = 0; last = 2; face_dir = Dir.y;
		case {1, 0, 0}: width = {Model.ymin, Model.ymax}; length = {Model.zmin, Model.zmax}; first = 1; last = 2; face_dir = Dir.x;
		case {0, 0, 1}: width = {Model.xmin, Model.xmax}; length = {Model.ymin, Model.ymax}; first = 0; last = 1; face_dir = Dir.z;
				case: assert(false, "I only test 0 1 0, 1 0 0, 0 0 1,");
		}

		offset :: 0
		/* j := 0 */
		triangles := Model.triangles
		for x1 in width[0]-offset..<(width[1]+offset) {
				x := x1+0.5
				for z1 in length[0]-offset..<(length[1]+offset) {
						z := z1+0.5
						posx := int(math.floor(((x-width[0]+offset) / (width[1]-width[0]))*cast(f32)volume.width))
						posz := int(math.floor(((z-length[0]+offset) / (length[1]-length[0]))*cast(f32)volume.length))

						if len(volume.buckets[posx][posz]) == 0 {
								continue
						}

						// TOOD Fix this
						/* bucket_length := math.abs(math.remainder(cast(f32)len(volume.buckets[posx][posz]),simd_size)) */
						/* for elem in 0..< bucket_length { */
						/* 		zero_tri : fast_triangle */
						/* 		append_soa_elem(&volume.buckets[posx][posz],zero_tri) */
						/* } */

						/* assert(len(volume.buckets[posx][posz])/simd_size == 0) */

						for idx in 0..<cast(int)len(volume.buckets[posx][posz])/simd_size {
								ltriangles := volume.buckets[posx][posz][idx*16:idx*16+16]

								ray.o[first] = x;
								ray.o[last] = z;
								ray.o[face_dir] = mins[face_dir];
								/* ray.o[face_dir] = width[0]; */

								u, v, w := simd_aligned_ray_triangle_intersection(x,z,ltriangles)
								ua := simd.to_array(u)
								va := simd.to_array(v)
								wa := simd.to_array(w)
								uvwa := simd.to_array(u+v+w)
								// this is the point uv and is relative to the triangle

								for val, j in uvwa {
										if val >= 0.95 && val <= 1.05 && ua[j] <= 1.05 && va[j] <= 1.05 && wa[j] <= 1.05 && ua[j] >= -0.05 && va[j] >= -0.05 && wa[j] >= -0.05 {
												/* j += 1 */
												/* fmt.println(ltriangles[j].uvs[0]-1) */
												a := Model.uvs[ltriangles[j].uvs[0]-1]
												b := Model.uvs[ltriangles[j].uvs[1]-1]
												c := Model.uvs[ltriangles[j].uvs[2]-1]
												/* w := 1-ua[j]-va[j] */
												// TODO Colors are wrong?
												puv := (ua[j]*a) + (va[j]*b) + (wa[j]*c)
												tri := Model.triangles[ltriangles[j].index]
												pos := bary_to_xyz(ua[j], va[j], wa[j],Model.points[tri.iverts.x-1], Model.points[tri.iverts.y-1], Model.points[tri.iverts.z-1])
												// PUV Hit UV to Image
												// I think it would be better to save all of the uvs and get the colors later but keep for now
												color := uv_to_color(puv, Model.img)
												append(&ret.colors, color)
												append(&ret.pos, pos)
												//fmt.printf("execute if score timer timer matches %d run setblock ~%d ~%d ~%d %s\n",j/1000, cast(i32)pos[0], cast(i32)pos[1], cast(i32)pos[2], clr.color_to_block(color, &pal))
												//fmt.println(color)
										}
								}
						}
				}
		}

		return ret
}


