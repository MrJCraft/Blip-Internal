package profile

import intri "base:intrinsics"
import win "core:sys/windows"
import "core:fmt"
import "base:runtime"


Byte     :: 1
Kilobyte :: 1024 * Byte
Megabyte :: 1024 * Kilobyte
Gigabyte :: 1024 * Megabyte
Terabyte :: 1024 * Gigabyte
Petabyte :: 1024 * Terabyte
Exabyte  :: 1024 * Petabyte

/* QueryPerformanceCounter */
/* QueryPerformanceFrequency */
// RDTSC
// RDTSCP

//odin run src -define:profile=false
//odin run src -define:profile=true

profile :: #config(profile, true) 

/* main :: proc() { */
		/* arr : []uint = {0,1,2,3,3,2,2,2,1,1,1,0} */
		/* fmt.println(arr[1:len(arr)-1]) */
		/* fmt.println(arr[len(arr):]) */
		/* arr := make([]int, 1000) */
		/* for i in 0..<10 { */
		/* 		timeBlock(#location(),1000*4) */
		/* 		for j in 0..<1000 { */
		/* 				arr[j] = j */
		/* 		} */
		/* } */
		/* recursiontest(6) */
/* 		rec() */
/* 		getResults() */
/* } */
/* recursiontest :: proc(num : int) -> int { */
/* 		if num < 10 { */
/* 				timeBlock(#location(), 8) */
/* 				fmt.println("start") */
/* 				return recursiontest(num+1)+recursiontest(num+1) */
/* 		} */
/* 		return 0 */
/* } */


/* rec :: proc() { */
/* 		timeBlock(#location(),10) */
/* 		rec1() */
/* } */

/* rec1 :: proc() { */
/* 		timeBlock(#location(),10) */
/* 		rec2() */
/* } */

/* rec2 :: proc() { */
/* 		timeBlock(#location(),10) */
/* 		rec3() */
/* 		rec3() */
/* 		rec4() */
/* } */

/* rec3 :: proc() { */
/* 		timeBlock(#location(),10) */
/* 		rec4() */
/* 		rec4() */
/* } */

/* rec4 :: proc() { */
/* 		timeBlock(#location(),10) */
/* 		rec5() */
/* } */

/* rec5 :: proc() { */
/* 		return */
/* } */









when profile == true {

		getOSTime :: proc() -> uint {
				value : win.LARGE_INTEGER 
				win.QueryPerformanceCounter(&value)
				return cast(uint)value
		}

		getOSFreq :: proc() -> uint {
				freq : win.LARGE_INTEGER 
				win.QueryPerformanceFrequency(&freq)
				return uint(freq)
		}

		getCycleTime :: proc() -> uint {
				return cast(uint) intri.read_cycle_counter()
		}

		getCPUHz :: proc() -> f64 {
				/* freq := getOSFreq() */
				freq : uint = 100
				value1 : uint = getOSTime()
				value2 : uint
				elapsed : uint = 0
				time1 := getCycleTime()
				for elapsed < freq {
						value2 = getOSTime()
						elapsed = value2-value1
				}
				time2 := getCycleTime()
				/* result := cast(f64)(value2-value1) / cast(f64) freq */
				freq = getOSFreq()
				return cast(f64)((time2-time1)*freq)/cast(f64)(value2-value1)
		}

		anchor :: struct {
				gen   : uint,
				time  : uint,
				bytes : uint,
				start : bool,
				location : runtime.Source_Code_Location,
		}

		/* timeInfo:: struct { */
		/* 		time : uint, */
		/* 		bytes : uint, */
		/* 		gen : uint, */
		/* 		name : string, */
		/* } */

		gen : uint = 0
		index : uint = 0
		length : uint = 0
		totalTime : uint = 0

		AnchorCount :: 8*Megabyte
		anchors := make([]anchor, AnchorCount)
		/* timeInfos := make([]timeInfo, AnchorCount) */
		/* times := make([]uint, AnchorCount) */
		

		startTime :: proc(bytes : uint = 0) {
				time := getCycleTime()
				current := &anchors[index]
				current.time = time
				current.gen = gen
				current.bytes = bytes
				current.start = true 
				index += 1
				gen += 1
				length += 1
		}

		endTime :: proc() {
				gen -= 1
				time := getCycleTime()
				current := &anchors[index]
				current.time = time
				current.gen = gen
				index += 1
				length += 1
		}


		/* getResults :: proc() { */
		/* 		assert(gen == 0, "Profiler doesnt have enough end points") */
		/* 		hz := getCPUHz() */
		/* 		totalTime = getTotalTime() */
		/* 		for &c, i in timeInfos { */
		/* 				if i > cast(int) length { */
		/* 						break */
		/* 				} */
		/* 				clocks := c.time */
		/* 				percent := (cast(f64)c.time/cast(f64)totalTime)*100 */
		/* 				percentFraction := (cast(f64)c.time/cast(f64)totalTime) */
		/* 				procName := c.name */
		/* 				totalBytes := c.bytes */
		/* 				totalMbs := f64(c.bytes/Megabyte) */
		/* 				throughput := (cast(f64)totalBytes/Gigabyte) / ((cast(f64)totalTime/hz)*percentFraction) */
		/* 				generation := c.gen */
		/* 				if generation == 0 { */
		/* 						/\* fmt.printfln("%s %i %f%% %fmbs %fgb/s",procName,clocks,percent,totalMbs, throughput) *\/ */
		/* 						continue */
		/* 				} else { */
		/* 				} */
		/* 				for _ in 0..<generation { */
		/* 						/\* fmt.printf("  ") *\/ */
		/* 				} */
		/* 				/\* fmt.printfln("L_%s %i %f%% %fmbs %fgb/s",procName,clocks,percent,totalMbs, throughput) *\/ */
		/* 		} */

		/* 		fmt.printfln("Total Time: %fs, %i",cast(f64)totalTime/hz,totalTime) */
		/* } */
		getTotalTime :: proc() -> uint {
				/* i : uint = 0 */
				/* first, last : uint */
				/* time : uint */
				time := anchors[index-1].time - anchors[0].time
				/* for &c in anchors { */
				/* 		if c.gen == 0 && c.start == true { */
				/* 				first = c.time */
				/* 		} else if c.gen == 0 && c.start == false { */
				/* 				last = c.time */
				/* 				time += last - first */
				/* 		} */
				/* }  */
				return time
		}

		/* getResults :: proc(tAnchors : []anchor = anchors) { */
		/* 		if len(tAnchors) == 0 { */
		/* 				return */
		/* 		} */
		/* 		hz := getCPUHz() */
		/* 		totalTime = getTotalTime() */
		/* 		first := tAnchors[0] */
		/* 		tempTime : uint = 0 */
		/* 		length : uint = 0 */
		/* 		for &c, i in tAnchors[1:] { */
		/* 				if(c.gen == first.gen && c.start == false) { */
		/* 						time : uint = c.time - first.time */
		/* 						fmt.println(time) */
		/* 						/\* formatTime(first,time,hz) *\/ */
		/* 						if i == 0 { */
		/* 								return */
		/* 						} else { */
		/* 								getResults(tAnchors[1:i]) */
		/* 								getResults(tAnchors[i+1:]) */
		/* 						} */
		/* 				} */
		/* 		} */
		/* } */

		getResults :: proc() {
				totalTime = getTotalTime()
				getResultsRec(anchors[0:length])
								fmt.println(totalTime)
		}
		getResultsRec :: proc(tAnchors : []anchor) {
				if len(tAnchors) == 0 {
						return
				} 
				tlength := len(tAnchors)
				first := tAnchors[0]
				/* last := tAnchors[len(tAnchors)-1] */
				assert(first.start == true)
				assert(len(tAnchors) % 2 == 0)
				for &c, i in tAnchors {
						if(c.gen == first.gen && c.start == false && i != 0) {
								/* fmt.println(i) */
								formatTime(first,c.time - first.time, getCPUHz())
								if i == 1 && tlength < 2	{
										return
								}
								getResultsRec(tAnchors[1:i])
								getResultsRec(tAnchors[i+1:])
								return
						}
				}
		}


		formatTime :: proc(first : anchor, time: uint, hz : f64) {
				clocks := time
				percent := (cast(f32)clocks/cast(f32)totalTime)*cast(f32)100
				percentFraction := (cast(f64)clocks/cast(f64)totalTime)
				procName := first.location.procedure
				totalBytes := first.bytes
				totalMbs := f64(first.bytes/Megabyte)
				throughput := (cast(f64)totalBytes/Gigabyte) / ((cast(f64)totalTime/hz)*percentFraction)
				generation := first.gen
				if generation == 0 {
						fmt.printfln("%s %i %f%% %fmbs %fgb/s",procName,clocks,percent,totalMbs, throughput)
				} else {
						for _ in 0..<generation {
								fmt.printf("  ")
						}
						fmt.printfln("L_%s %i %f%% %fmbs %fgb/s",procName,clocks,percent,totalMbs, throughput)
				}
		}

		@(deferred_none=timeBlockEnd)
		timeBlock ::  proc(str : runtime.Source_Code_Location = #caller_location, bytes : uint = 0) {
				// TODO is is slightly better to put timeInfo = str in the endTime Function
				anchors[index].location = str
				startTime(bytes)
		}
		timeBlockEnd :: proc() {
				endTime()
		}

} else {
		getOSTime :: proc() -> uint {return 0}
		getOSFreq :: proc() -> uint {return 0}
		getCycleTime :: proc() -> uint {return 0}
		getCPUHz :: proc() -> f64 {return 0.0}
		startTime :: proc(bytes : uint = 0) {}
		endTime :: proc() {}
		getResults :: proc() {}
		getTotalTime :: proc() -> (uint,uint) {return 0, 0}
		timeBlock ::  proc(str : runtime.Source_Code_Location = #caller_location, bytes : uint = 0) {}
		timeBlockEnd:: proc() {}
}
