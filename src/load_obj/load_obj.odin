package load_obj

//import td "core:math/linalg"
import png "core:image/png"
//import clr "color"
import "core:strings"
import "../profile"
import "core:os"
import "core:bufio"
import "core:fmt"
//import "core:mem"
import "core:bytes"
import "core:strconv"
import "core:math"
//filename length limit might be 256
epsilon :: 8

Triangle :: struct {
		iverts : [3]u32,
		uv : [3]u32,
}

Obj :: struct {
		name : string,
		xmax : f32,
		xmin : f32,
		ymax : f32,
		ymin : f32,
		zmax : f32,
		zmin : f32,
		points : [dynamic][3]f32,
		//triangles : [dynamic][3]u32,
		triangles : [dynamic]Triangle,
		// texture coordinates
		uvs : [dynamic][2]f32,
		img : ^png.Image,
		//points
}

Ruct :: struct {
		// a bit map for block because
		colors : [dynamic][4]u8,
		pos : [dynamic][3]f32,
}

delete_ruct :: proc(structure : Ruct) {
		delete(structure.colors)
		delete(structure.pos)
}

get_obj_size :: proc($T : typeid, model : ^Obj) -> [3]T {
		size : [3]T = {
				cast(T) (math.ceil(model.xmax) - math.ceil(model.xmin)),
				cast(T) (math.ceil(model.ymax) - math.ceil(model.ymin)),
				cast(T) (math.ceil(model.zmax) - math.ceil(model.zmin)),
		}
		return size
}

uv_to_color :: proc(puv : [2]f32, img : ^png.Image) -> [4]u8 {
		ret : [4]u8 = {0,0,0,255}
		if img.channels == 3 {
				offset :: 3
				pixel : []u8 = {0,0,0}
				x := int((cast(f32)img.width)*puv[0])
				y := int((cast(f32)img.height)*math.abs(puv[1]-1))
				bytes.buffer_read_at(&img.pixels, pixel, x*offset+(y*offset*cast(int)img.width))
				ret = {pixel[0],pixel[1],pixel[2],255}

		} else if img.channels == 4 {
				offset :: 4
				pixel : []u8 = {0,0,0,255}
				x := int((cast(f32)img.width)*puv[0])
				y := int((cast(f32)img.height)*math.abs(puv[1]-1))
				bytes.buffer_read_at(&img.pixels, pixel, x*offset+(y*offset*cast(int)img.width))
				ret = {pixel[0],pixel[1],pixel[2],pixel[3]}
		}
		return ret
}

parse_vert :: proc(line : string, Model : ^Obj) {
		// "v "
		ret : [3]f32 = {0,0,0}
		mline := line[2:len(line)]

		i := 0
		for str in strings.split_iterator(&mline, " ") {
				value, _ := strconv.parse_f32(str)
				ret[i] = value
				i = i + 1
		}
		if ret[0] > Model.xmax {
				Model.xmax = ret[0]
		}
		else if ret[0] < Model.xmin {
				Model.xmin = ret[0]
		}
		if ret[1] > Model.ymax {
				Model.ymax = ret[1]
		}
		else if ret[1] < Model.ymin {
				Model.ymin = ret[1]
		}
		if ret[2] > Model.zmax {
				Model.zmax = ret[2]
		}
		else if ret[2] < Model.zmin {
				Model.zmin = ret[2]
		}
		append(&Model.points, ret)
}

parse_tri :: proc(line : string, Model : ^Obj) {
		// full f v1/vt1/vn1 v1/vt1/vn1 v1/vt1/vn1
		// what we are dealing withf v1 v2 v3
		// add uv support

		tri : Triangle
		tri.iverts = {0, 0, 0}
		tri.uv = {0, 0, 0}
		mline := line[2:len(line)-1]

		i := 0
		j := 0
		info : string
		for str in strings.split_iterator(&mline, " ") {
				if i > 2 {
						panic("Mesh not Triangulated")
				}
				info = str
				j = 0
				for ss in strings.split_iterator(&info, "/") {
						if j == 0 {
								value, _ := strconv.parse_uint(ss)
								tri.iverts[i] = cast(u32)value
						} else if j == 1 {
								value, _ := strconv.parse_uint(ss)
								tri.uv[i] = cast(u32)value
						}
						j += 1
				}
				i = i + 1
		}
		append(&Model.triangles, tri)

}

parse_vt :: proc(line : string, Model : ^Obj) {
		// vt 0.500 1 [0]
		mline := line[3:len(line)]
		vt : [2]f32
		i := 0
		for str in strings.split_iterator(&mline, " ") {
				if (i > 2) {
						break
				}
				value, _ := strconv.parse_f32(str)
				vt[i] = value
				i = i + 1
		}
		append(&Model.uvs, vt)

}

parse_convex_polygon :: proc() {
		// TODO LATER
		// f v1/vt1/vn1 v1/vt1/vn1 v1/vt1/vn1 v1/vt1/vn1 ...

}

parse_obj :: proc(Model : ^Obj) {
		profile.timeBlock()
		filepath : string = Model.name
		f, ferr := os.open(filepath)
		if ferr != 0 {
				fmt.println("no such file exists")
				return 
		}
		defer os.close(f)

		r: bufio.Reader
		buffer: [4096]byte
		bufio.reader_init_with_buf(&r, os.stream_from_handle(f), buffer[:])
		// NOTE: bufio.reader_init can be used if you want to use a dynamic backing buffer
		defer bufio.reader_destroy(&r)

		for {
				// This will allocate a string because the line might go over the backing
				// buffer and thus need to join things together
				line, err := bufio.reader_read_string(&r, '\n', context.allocator)
				if err != nil {
						break
				}
				defer delete(line, context.allocator)
				//line = strings.trim_right(line, "\n")
				if line[0:2] == "v " {
						parse_vert(line, Model)
				} else if line[0:2] == "f " {
						parse_tri(line, Model)
				} else if line[0:3] == "vt " {
						parse_vt(line, Model)
				}
		}
		Model.xmin -= epsilon
		Model.xmax += epsilon
		Model.ymin -= epsilon
		Model.ymax += epsilon
		Model.zmin -= epsilon
		Model.zmax += epsilon
}

parse_obj_simple :: proc(Model : ^Obj) {
		filepath : string = Model.name
		f, ferr := os.open(filepath)
		if ferr != 0 {
				fmt.println("no such file exists")
				return 
		}
		defer os.close(f)

		r: bufio.Reader
		buffer: [128]byte
		bufio.reader_init_with_buf(&r, os.stream_from_handle(f), buffer[:])
		// NOTE: bufio.reader_init can be used if you want to use a dynamic backing buffer
		defer bufio.reader_destroy(&r)

		for {
				// This will allocate a string because the line might go over the backing
				// buffer and thus need to join things together
				line, err := bufio.reader_read_string(&r, '\n', context.allocator)
				if err != nil {
						break
				}
				defer delete(line, context.allocator)
				//line = strings.trim_right(line, "\n")
				if line[0:2] == "v " {
						parse_vert(line, Model)
				}
		}
}

delete_model :: proc (Model : ^Obj) {
		delete(Model.points)
		delete(Model.triangles)
		delete(Model.uvs)
		png.destroy(Model.img)
		free(Model)
}

// this is for testing purposes only
// as this is a library
/* _main :: proc() { */
/* 		Model := new(Obj) */
/* 		defer delete_model(Model) */
/* 		Model.name = "house.obj" */
/* 		Model.points = make([dynamic][3]f32, 0, 100000) */
/* 		Model.triangles = make([dynamic]Triangle,0, 100000) */
/* 		Model.uvs = make([dynamic][2]f32,0, 100000) */
/* 		Model.img, _ = png.load_from_file("house-RGBA.png") */
/* 		parse_obj(Model) */
/* 		structure := trace(Model) */
/* 		defer delete_ruct(structure) */
/* 		//fmt.println(Model.triangles) */
/* 		/\* for v in Model.points { *\/ */
/* 		/\* 		fmt.println(v) *\/ */
/* 		/\* } *\/ */



/* } */


/* main :: proc() { */

/* 		track: mem.Tracking_Allocator */
/* 		mem.tracking_allocator_init(&track, context.allocator) */
/* 		defer mem.tracking_allocator_destroy(&track) */
/* 		context.allocator = mem.tracking_allocator(&track) */

/* 		_main() */

/* 		for _, leak in track.allocation_map { */
/* 				fmt.printf("%v leaked %m\n", leak.location, leak.size) */
/* 		} */
/* 		for bad_free in track.bad_free_array { */
/* 				fmt.printf("%v allocation %p was freed badly\n", bad_free.location, bad_free.memory) */
/* 		} */

/* } */

