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
	for not in app.nots {
		//3. 
		//4. wip
	}
	for diode in app.diodes {
		//3. wip
		//4. wip
	}
	for wire in app.wires {
		//3. wip
		//4. wip
	} 
}

const rid_bitmap = u64(0x07FF_FFFF_FFFF_FFFF) // 0000_0111_11111... bit map to get the real id with &
const elem_type_bitmap = u64(0xC000_0000_0000_0000)

// TODO: Can be upgraded by using a binary search
fn (mut app App) get_elem_state_by_id(id u64) bool {
	rid := id & rid_bitmap
	// the state in the id may be an old state so it needs to get the state from the state lists
	if id & elem_type_bitmap == 0b00 {  // not
		for i, not in app.nots {
			if not.rid == rid {
				return app.n_states[app.actual_state][i]
			}
		}
	} else if id & elem_type_bitmap == 0b01 { // diode 
		for i, diode in app.diodes {
			if diode.rid == rid {
				return app.d_states[app.actual_state][i]
			}
		}
	} else if id & elem_type_bitmap == 0b10 { // On
		return true // a on is always ON
	} else if id & elem_type_bitmap == 0b11 { // wire
		for i, wire in app.wires {
			if wire.rid == rid {
				return app.w_states[app.actual_state][i]
			}
		}
	}
	panic("id not found in get_elem_state_by_id: ${id}")
}

// Explain ids

// An element is a something placed on the map (so not empty)
// A gate is an element with some inputs or some outputs or both
// The orientation of a gate is where the output is facing

// Crossing: a special element that links it's north & south sides and (separately) it's west and east sides as if it was not there
// Example: a not gate facing west placed next to a crossing (the not gate is on it's west side), will have as input the element placed next to the crossing on the east side
struct Chunk {}

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
	actual_state int // indicate which list is the old state list and which is the actual one (0 for the first, 1 for the second)
	nots []Nots
	n_states [2][]bool // the old state and the actual state list
	diodes []Diode
	d_states [2][]bool
	ons []On
	wires []Wire
	w_states [2][]bool
}
