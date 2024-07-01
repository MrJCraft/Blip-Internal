package main


import "load_obj"
import "core:fmt"
import prof "profile"
/* import "core:math" */
/* import "core:strings" */
import "core:mem"
/* import "core:os" */
/* import "core:bytes" */
/* import end "core:encoding/endian" */
import png "core:image/png"
import clr "color"
// PROJECT BG / BLIP


colored_main :: proc() {
		// TODO Handle Errors
		// TODO use the standard in to specify the file names
		prof.startTime()
		using load_obj
		//max height 380
		//material := "stone"
		Model := new(load_obj.Obj)
		/* defer load_obj.delete_model(Model) */

		Model.name = "models/turtle.obj"
		Model.points = make([dynamic][3]f32, 0, 100000)
		Model.triangles = make([dynamic]Triangle,0, 100000)
		Model.uvs = make([dynamic][2]f32,0, 100000)
		
		//TODO validate that this is a png
		// multithread this
		err : png.Error
		Model.img, err = png.load_from_file("models/turtle.png")
		if err != nil {
				fmt.println(err)
				assert(false)
		}
		// No Color
		//obj_mcstructure(Model^)
		//obj_schem(Model^)
		parse_obj(Model)
		//generates the structure
		// TODO Optimize
		pal := clr.create_block_map("palletes/simplepal/")
		/* defer clr.delete_block_map(pal) */

		fmt.println("started colored")
		obj_schem_color(Model, &pal)
		fmt.println("finished")
		prof.endTime()
		prof.getResults()
}

simple_main :: proc() {
		// TODO Handle Errors
		//max height 380
		using load_obj
		//max height 380
		Model := new(load_obj.Obj)
		Model.name = "models/sphere.obj"
 		Model.points = make([dynamic][3]f32, 0)
		//material := "stone"
		defer load_obj.delete_model(Model)
		parse_obj_simple(Model)
		// No Color
		//obj_mcstructure(Model^)
		fmt.println("started")
		obj_schem(Model)
		fmt.println("finished")
}


bvh_main :: proc() {
		using load_obj
		Model := new(load_obj.Obj)
		defer load_obj.delete_model(Model)
		Model.name = "models/dragon.obj"
		Model.points = make([dynamic][3]f32, 0, 100000)
		Model.triangles = make([dynamic]Triangle,0, 100000)
		Model.uvs = make([dynamic][2]f32,0, 100000)
		Model.img, _ = png.load_from_file("models/dragon.png")
		parse_obj(Model)
		volumes : BVH
		init_BVH(Model, Dir.y, &volumes)
		/* fmt.println(volumes.buckets) */
		for v in volumes.buckets {
				for v2 in v {
						fmt.println(v2)
				}
		}
}

// TODO Non temporal Stores
main :: proc() {
		colored_main()
}





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

