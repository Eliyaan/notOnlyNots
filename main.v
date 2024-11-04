// Explain update system & tick delay

// Explain ids

// An element is a something placed on the map (so not empty)
// A gate is an element with some inputs or some outputs or both
// The orientation of a gate is where the output is facing

// Crossing: a special element that links it's north & south sides and (separately) it's west and east sides as if it was not there
// Example: a not gate facing west placed next to a crossing (the not gate is on it's west side), will have as input the element placed next to the crossing on the east side
struct Chunk {}

// A gate that outputs the opposite of the input signal
struct Nots {
	inp u64 // id of the input element of the not gate
	out u64 // id of the output of the not gate
	rid // real id
	// Map coordinates
	x u32 
	y u32
}

// A gate that transmit the input signal to the output element (unidirectionnal) and adds 1 tick delay
struct Diode {
	inp u64 // id of the input element of the not gate
	out u64 // id of the output of the not gate
	rid // real id
	// Map coordinates
	x u32 
	y u32
}

// A gate that is always ON (only on one side)
struct On {
	out u64 // id of the output of the not gate
	rid // real id
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
	inps []u64 // id of the input elements outputing to the wire
	outs []u64 // id of the output elements whose inputs are the wire
	cable_coords [][]u32 // all the x y coordinates of the induvidual cables (elements) the wire is made of
	rid // real id
}

struct App {
	map []Chunk
	nots []Nots
	n_states []u8
	diodes []Diode
	d_states []u8
	ons []On
	wires []Wire
	w_states []u8
}
