const empty_id  = u64(0)
const on_bits = u64(0x2000_0000_0000_0000) // 0010_0000_000...
const elem_on_bits = u64(0xA000_0000_0000_0000) // 1010_0000_000...  always on
const elem_not_bits = u64(0x0000_0000_0000_0000) // 0000_0000_000...
const elem_diode_bits = u64(0x4000_0000_0000_0000) // 0100_0000_000...
const elem_wire_bits = u64(0xC000_0000_0000_0000) // 1100_0000_000...
const elem_crossing_bits = u64(0xFFFF_FFFF_FFFF_FFFF) // 1100_0000_000...
const north = u64(0x0)
const south = u64(0x0800_0000_0000_0000)
const west = u64(0x1000_0000_0000_0000)
const east = u64(0x1800_0000_0000_0000)
const rid_mask = u64(0x07FF_FFFF_FFFF_FFFF) // 0000_0111_11111... bit map to get the real id with &
const elem_type_mask = u64(0xC000_0000_0000_0000)
const ori_mask = u64(0x1800_0000_0000_0000)

enum Elem {
	not // 00
	diode // 01
	on // 10
	wire // 11
	crossing // 111...111
}

fn (mut app App) placement(x_start u32, y_start u32, x_end u32, y_end u32) {
	// 1.
	// set the tile id to:
	// the type (2 most sign bits)
	// the state (3rd)
	// the orientation (4,5th)
	// 2.
	// add the struct to the array (with the right fields)
	// add the state to the array
	// 3.
	// update the output/inputs fields of the adjacent elements 
	// 4.
	// add one to the rid of the type
	
	match app.selected_item {
		.not {
			
		}
		.diode {
		}
		.on {
			mut x_ori, mut y_ori := match app.selected_ori {
				north { u32(0), u32(-1)}
				south { 0, 1}
				east { 1, 0}
				west { -1, 0}
				else {panic("unknown orientation")}
			}
			for x in x_start..x_end {
				for y in y_start..y_end {
					mut chunkmap := app.get_chunkmap_at_coords(x, y)
					x_map := x % chunk_size
					y_map := y % chunk_size
					if chunkmap[x_map][y_map] != 0x0 { // map not empty
						continue
					} 
					// 1. done
					id := elem_on_bits & app.o_next_rid & app.selected_ori
					chunkmap[x_map][y_map] = id
					// 2. done
					out_id := app.gate_out_id(x, y, x_ori, y_ori)
					app.ons << On {
						id,
						out_id,
						x,
						y
					}
					// no state arrays for the ons
					// 3. done; only an input for other elements
					if out_id != empty_id {
						_, idx := app.get_elem_state_idx_by_id(out_id, 0) // do not want the state
						if out_id & elem_type_mask == 0b00 { // not
							app.nots[idx].inp = id
						}
						else if out_id & elem_type_mask == 0b01 { // diode
							app.diodes[idx].inp = id
						}
						else if out_id & elem_type_mask == 0b10 { // on -> does not have inputs
						}
						else if out_id & elem_type_mask == 0b11 { // wire
							app.wires[idx].inps << id
						}
					}
					// 4. done
					app.o_next_rid++
				}
			}
		}
		.wire {
		}
		.crossing {
		}
	}
}


// Returns empty_id if not a valid output
fn (mut app App) gate_out_id(x u32, y u32, x_ori u32, y_ori u32) u64 {
	mut output_chunkmap := app.get_chunkmap_at_coords(x+x_ori, y+y_ori)
	mut out_id := output_chunkmap[(x+x_ori)%chunk_size][(y+y_ori)%chunk_size]
	// Check if output's orientation is matching and not orthogonal
	if out_id == elem_crossing_bits {
		// check until wire
		mut x_off := x_ori
		mut y_off := y_ori
		for out_id == elem_crossing_bits {
			x_off += x_ori
			y_off += y_ori
			output_chunkmap = app.get_chunkmap_at_coords(x+x_off, y+y_off)
			out_id = output_chunkmap[(x+x_off)%chunk_size][(y+y_off)%chunk_size]
		}
		return app.gate_out_id(x+x_off-x_ori, y+y_off-y_ori, x_ori, y_ori) // coords of the crossing just before the detected good elem 
	} else if out_id == 0x0 {
		out_id = empty_id
	} else if out_id & elem_type_mask == elem_on_bits {
		out_id = empty_id
	} else if out_id & elem_type_mask == elem_wire_bits {
	} else if out_id & elem_type_mask == elem_not_bits {
		if out_id & ori_mask != app.selected_ori {
			out_id = empty_id
		}
	} else if out_id & elem_type_mask == elem_diode_bits {
		if out_id & ori_mask != app.selected_ori {
			out_id = empty_id
		}
	}
	return out_id
}

// A tick is a unit of time. For each tick, a complete update cycle/process will be effected.
// Update process: 
// 1. change which states lists are the actual ones (/!\ when creating/destroying an element, the program must update the actual and the old state lists)
// 2. for each element in the element lists (nots, diodes, wires) do steps 3 and 4
// 3. look at the previous state(s) of the input(s) in the old states lists
// 4. update it's state (in the actual state list and in the id stored in the chunks) accordingly
// It is updated like a graph to avoid running into update order issues.
fn (mut app App) update_cycle() {
	//1. done
	app.actual_state = (app.actual_state+1)%2
	//2. done
	for i, not in app.nots {
		//3. done
		old_inp_state, _ := app.get_elem_state_idx_by_id(not.inp, 1)
		//4. done 
		app.n_states[app.actual_state][i] = !old_inp_state
		mut chunkmap := app.get_chunkmap_at_coords(not.x, not.y)
		xmap := not.x % chunk_size
		ymap := not.y % chunk_size
		if !old_inp_state {
			chunkmap[xmap][ymap] = chunkmap[xmap][ymap] | on_bits
		} else {
			chunkmap[xmap][ymap] = chunkmap[xmap][ymap] & (~on_bits)
		}
	}
	for i, diode in app.diodes {
		//3. done
		old_inp_state, _ := app.get_elem_state_idx_by_id(diode.inp, 1)
		//4. done 
		app.d_states[app.actual_state][i] = old_inp_state
		mut chunkmap := app.get_chunkmap_at_coords(diode.x, diode.y)
		xmap := diode.x % chunk_size
		ymap := diode.y % chunk_size
		if old_inp_state {
			chunkmap[xmap][ymap] = chunkmap[xmap][ymap] | on_bits
		} else {
			chunkmap[xmap][ymap] = chunkmap[xmap][ymap] & (~on_bits)
		}
	}
	for i, wire in app.wires {
		//3. done
		mut old_or_inp_state := false // will be all the inputs of the wire ORed
		for inp in wire.inps {
			inp_state, _ := app.get_elem_state_idx_by_id(inp, 1)
			if inp_state {
				old_or_inp_state = true // only one is needed for the OR to be true
				break
			}
		}
		//4. done
		app.w_states[app.actual_state][i] = old_or_inp_state
		for cable_coo in wire.cable_coords {
			mut chunkmap := app.get_chunkmap_at_coords(cable_coo[0], cable_coo[1])
			xmap := cable_coo[0] % chunk_size
			ymap := cable_coo[1] % chunk_size
			if old_or_inp_state {
				chunkmap[xmap][ymap] = chunkmap[xmap][ymap] | on_bits
			} else {
				chunkmap[xmap][ymap] = chunkmap[xmap][ymap] & (~on_bits)
			}
		}
	} 
}

fn (mut app App) get_chunkmap_at_coords(x u32, y u32) [chunk_size][chunk_size]u64 {
	for chunk in app.map {
		if x >= chunk.x && y >= chunk.y {
			if x < chunk.x + chunk_size && y < chunk.y + chunk_size {
				return chunk.id_map
			}
		}
	}
	panic("Chunk at ${x} ${y} not found")
}


// id of the concerned element & the index in the list
// previous: 0 for actual state, 1 for the previous state
fn (mut app App) get_elem_state_idx_by_id(id u64, previous u8) (bool, int) { 
	concerned_state := (app.actual_state+previous)%2
	rid := id & rid_mask
	// the state in the id may be an old state so it needs to get the state from the state lists
	if id & elem_type_mask == 0b00 { // not
		mut low := 0
		mut high := app.nots.len
		mut mid := 0 // tmp value
		for low <= high {
			mid = low + ((high - low) >> 1) // low + half
			// If x is smaller, ignore right half
			if app.nots[mid].rid < rid {
				high = mid - 1
			}	
			// If x greater, ignore left half
			else if app.nots[mid].rid > rid {
				low = mid + 1
			}	
			// Check if x is present at mid
			else {
				return app.n_states[concerned_state][mid], mid
			}
		}	
	} else if id & elem_type_mask == 0b01 { // diode 
		mut low := 0
		mut high := app.diodes.len
		mut mid := 0 // tmp value
		for low <= high {
			mid = low + ((high - low) >> 1) // low + half
			if app.diodes[mid].rid < rid {
				high = mid - 1
			}	
			else if app.diodes[mid].rid > rid {
				low = mid + 1
			}	
			else {
				return app.d_states[concerned_state][mid], mid
			}
		}	
	} else if id & elem_type_mask == 0b10 { // On
		return true // a on is always ON
	} else if id & elem_type_mask == 0b11 { // wire
		mut low := 0
		mut high := app.wires.len
		mut mid := 0 // tmp value
		for low <= high {
			mid = low + ((high - low) >> 1) // low + half
			if app.wires[mid].rid < rid {
				high = mid - 1
			}	
			else if app.wires[mid].rid > rid {
				low = mid + 1
			}	
			else {
				return app.w_states[concerned_state][mid], mid
			}
		}	
	}
	panic("id not found in get_elem_state_idx_by_id: ${id}")
}

// Explain ids

// An element is a something placed on the map (so not empty)
// A gate is an element with some inputs or some outputs or both
// The orientation of a gate is where the output is facing

// Crossing: a special element that links it's north & south sides and (separately) it's west and east sides as if it was not there
// Example: a not gate facing west placed next to a crossing (the not gate is on it's west side), will have as input the element placed next to the crossing on the east side
const chunk_size = 100
struct Chunk {
	x u32
	y u32
	id_map [chunk_size][chunk_size]u64 // [x][y] x++=east y++=south
}

// A gate that outputs the opposite of the input signal
struct Nots {
	rid u64 // real id
mut:
	inp u64 // id of the input element of the not gate
	out u64 // id of the output of the not gate
	// Map coordinates
	x u32 
	y u32
}

// A gate that transmit the input signal to the output element (unidirectionnal) and adds 1 tick delay (1 update cycle to update)
struct Diode {
	rid u64 // real id
mut:
	inp u64 // id of the input element of the not gate
	out u64 // id of the output of the not gate
	// Map coordinates
	x u32 
	y u32
}

// A gate that is always ON (only on one side)
struct On {
	rid u64 // real id
mut:
	out u64 // id of the output of the not gate
	// Map coordinates
	x u32 
	y u32
}

// Cables are the individually placable element and two cables are connected if one of 
// them is already connected to one that is connected to the other or the two cables are next to each other
// If some cables are connected, they shared their states by being a wire

// a Wire is made out of multiple cables that are connected
// It outputs the OR of all it's inputs
struct Wire {
	rid u64 // real id
mut:
	inps []u64 // id of the input elements outputing to the wire
	outs []u64 // id of the output elements whose inputs are the wire
	cable_coords [][]u32 // all the x y coordinates of the induvidual cables (elements) the wire is made of
}

struct App {
mut:
	map []Chunk
	selected_item Elem
	selected_ori u64
	actual_state int // indicate which list is the old state list and which is the actual one (0 for the first, 1 for the second)
	nots []Nots
	n_next_rid u64 = 1
	n_states [2][]bool // the old state and the actual state list
	diodes []Diode
	d_next_rid u64 = 1
	d_states [2][]bool
	ons []On
	o_next_rid u64 = 1
	wires []Wire
	w_next_rid u64 = 1
	w_states [2][]bool
}
