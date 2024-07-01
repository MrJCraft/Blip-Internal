package color

import "core:fmt"
import "core:os"
import "core:math"
//import li "core:math/linalg"
import "core:bytes"
import "../profile"
import "core:strings"
//import "core:mem"
import png "core:image/png"

img_to_avg_color :: proc(filename : string) -> [4]u8 {
		res := [4]u8{0,0,0,0}
		img, err := png.load_from_file(filename)
		defer png.destroy(img)
		if err != nil {
				fmt.println("error:")
				fmt.println("color img_to_avg_color")
				fmt.println(err)
		}
		if(img.channels == 3) {
				res = avg_rgb(img)
		}
		else if(img.channels == 4) {
				res = avg_rgba(img)
		}
		return res
}


avg_rgba :: proc(img: ^png.Image) -> [4]u8 {
		buf := [4]u8{0,0,0,0}
		avg := [4]int{0,0,0,0}
		buf2 : [4]int
		img_length := img.width * img.height
		for _ in 0..<img_length {
				bytes.buffer_read(&img.pixels, auto_cast buf[:])
				buf2[0] = auto_cast buf[0]
				buf2[1] = auto_cast buf[1]
				buf2[2] = auto_cast buf[2]
				buf2[3] = auto_cast buf[3]
				avg = avg+buf2
		}
		avg = (avg / img_length)
		ret: [4]u8
		ret[0] = auto_cast avg[0]
		ret[1] = auto_cast avg[1]
		ret[2] = auto_cast avg[2]
		ret[3] = auto_cast avg[3]
		return ret 
}
avg_rgb :: proc(img: ^png.Image) -> [4]u8 {
		buf := [3]u8{0,0,0}
		avg := [3]int{0,0,0}
		buf2 : [3]int
		img_length := img.width * img.height
		for _ in 0..<img_length {
				bytes.buffer_read(&img.pixels, auto_cast buf[:])
				buf2[0] = auto_cast buf[0]
				buf2[1] = auto_cast buf[1]
				buf2[2] = auto_cast buf[2]
				avg = avg+buf2
		}
		avg = (avg / img_length)
		ret: [4]u8 = {0,0,0,255}
		ret[0] = auto_cast avg[0]
		ret[1] = auto_cast avg[1]
		ret[2] = auto_cast avg[2]
		return ret 
}

block_map :: struct {
		length: int,
		names: []string,
		r: [512]u8,
		g: [512]u8,
		b: [512]u8,
		a: [512]u8,
}

/* Color :: struct { */
/* 		r: u8, */
/* 		g: u8, */
/* 		b: u8, */
/* 		a: u8, */
/* } */

/* rgb_hash :: struct { */
/* 		colors: [256][256][256]string */
/* } */

delete_block_map :: proc(bmap : block_map) {
		for &v in bmap.names {
				delete(v)
		}
		delete(bmap.names)
}

create_block_map :: proc(path: string) -> block_map {

		ret : block_map
		length: int
		ret.names = make([]string,512)
		h ,_ := os.open(path)
		files, err := os.read_dir(h,0)
		if (err != 0) {
				fmt.println("error:")
				fmt.println("color craete_block_map")
				fmt.println(err)
		}
		length = len(files)
		for file, i in files {
				/* ret.names[i] = strings.clone(file.name) */
				ret.names[i] = strings.clone(file.name[0:len(file.name)-4])
				val := img_to_avg_color(file.fullpath)
				ret.r[i] = val[0]
				ret.g[i] = val[1]
				ret.b[i] = val[2]
				ret.a[i] = val[3]

				os.file_info_delete(file)
		}
		ret.length = length
		defer os.close(h)
		defer delete(files)
		return ret
}

euclid :: proc(v1 : [4]u8, v2 : [4]u8) -> u32 {
		diff :[4]u8 = v1-v2
		total : uint = 0
		for v in diff {
				total += cast(uint)v
		}
		return cast(u32)math.abs(total)
}

color_to_block :: proc(color: [4]u8, palette: ^block_map) -> string {
		current : [4]u8 = [4]u8{0,0,0,0}
		block := "bedrock"
		for i in 0..<palette.length {
				rgba :[4]u8 = {palette.r[i],palette.g[i],palette.b[i],palette.a[i]}
				pdiff := euclid(color, rgba)
				cdiff := euclid(color, current)
				if pdiff < cdiff {
						current = rgba
						block = palette.names[i]
				}
		}
		return block
}

/* main :: proc() { */
/* 		blocks := create_block_map("test/") */
/* 		fmt.println(color_to_block([4]u8{136,136,136,255}, &blocks)) */
/* 		//fmt.println(blocks) */
/* 		defer delete_block_map(blocks) */
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
