const empty_id = u64(0)
const on_bits = u64(0x2000_0000_0000_0000) // 0010_0000_000...
const elem_on_bits = u64(0xA000_0000_0000_0000) // 1010_0000_000...  always on
const elem_not_bits = u64(0x0000_0000_0000_0000) // 0000_0000_000...
const elem_diode_bits = u64(0x4000_0000_0000_0000) // 0100_0000_000...
const elem_wire_bits = u64(0xC000_0000_0000_0000) // 1100_0000_000...
const elem_crossing_bits = u64(0xFFFF_FFFF_FFFF_FFFF) // 1111_1111_...
// x++=east y++=south
const north = u64(0x0)
const south = u64(0x0800_0000_0000_0000) // 0000_1000..
const west = u64(0x1000_0000_0000_0000) // 0001_000...
const east = u64(0x1800_0000_0000_0000) // 0001_100..
const rid_mask = u64(0x07FF_FFFF_FFFF_FFFF) // 0000_0111_11111... bit map to get the real id with &
const elem_type_mask = u64(0xC000_0000_0000_0000) // 1100_0000...
const ori_mask = u64(0x1800_0000_0000_0000) // 0001_1000...

enum Elem {
	not      // 00
	diode    // 01
	on       // 10
	wire     // 11
	crossing // 111...111
}

@[noreturn]
fn log_quit(message string) {
	panic("Very TODO")
}

fn (mut app App) removal(_x_start u32, _y_start u32, _x_end u32, _y_end u32) {
	// 1.
	// set the tile id to empty_id
	// 2.
	// remove the struct from the array
	// remove the state from the arrays (there are 2 state arrays to modify /!\)
	// 3.
	// update the output/inputs fields of the adjacent elements

	x_start, x_end := if _x_start > _x_end {
		_x_end, _x_start
	} else {
		_x_start, _x_end
	}
	y_start, y_end := if _y_start > _y_end {
		_y_end, _y_start
	} else {
		_y_start, _y_end
	}

	for x in x_start .. x_end {
		for y in y_start .. y_end {
			mut chunkmap := app.get_chunkmap_at_coords(x, y)
			x_map := x % chunk_size
			y_map := y % chunk_size
			if chunkmap[x_map][y_map] == 0x0 { // map empty
				continue
			}
			id := chunkmap[x_map][y_map]
			mut x_ori, mut y_ori := match id & ori_mask {
				// Output direction
				north { 0, -1 }
				south { 0, 1 }
				east { 1, 0 }
				west { -1, 0 }
				else { log_quit('${@LINE}unknown orientation') }
			}
			match id & elem_type_mask {
				elem_not_bits {
					// 1. done
					chunkmap[x_map][y_map] = empty_id

					// 2. done
					_, idx := app.get_elem_state_idx_by_id(id, 0)
					app.nots.delete(idx)
					app.n_states[0].delete(idx)
					app.n_states[1].delete(idx)

					// 3. done
					inp_id := app.next_gate_id(x, y, -x_ori, -y_ori)
					out_id := app.next_gate_id(x, y, x_ori, y_ori)
					app.add_input(out_id, empty_id)
					app.add_output(inp_id, empty_id)
				}
				elem_diode_bits {
					// 1. done
					chunkmap[x_map][y_map] = empty_id

					// 2. done
					_, idx := app.get_elem_state_idx_by_id(id, 0)
					app.diodes.delete(idx)
					app.d_states[0].delete(idx)
					app.d_states[1].delete(idx)

					// 3. done
					inp_id := app.next_gate_id(x, y, -x_ori, -y_ori)
					out_id := app.next_gate_id(x, y, x_ori, y_ori)
					app.add_input(out_id, empty_id)
					app.add_output(inp_id, empty_id)
				}
				elem_on_bits {
					// 1. done
					chunkmap[x_map][y_map] = empty_id

					// 2. done
					// no arrays for the ons

					// 3. done; only an input for other elements
					out_id := app.next_gate_id(x, y, x_ori, y_ori)
					app.add_input(out_id, empty_id)
				}
				elem_wire_bits {
					// Find if a part of an existing wire
					mut coo_adj_wire := [][]int{}
					mut adjacent_inps := []u64{}
					mut adjacent_outs := []u64{}
					for coo in [[0, 1], [0, -1], [1, 0], [-1, 0]] {
						adj_id, is_input, _, _ := app.wire_next_gate_id_coo(x, y, coo[0],
							coo[1])
						if adj_id == empty_id {
						} else if adj_id & elem_type_mask == elem_wire_bits {
							coo_adj_wire << [x + coo[0], y + coo[1]]
						} else {
							if is_input {
								adjacent_inps << adj_id // for the old inps
							} else {
								adjacent_outs << adj_id // for the old inps
							}
						}
					}

					// 2. done
					// Separate the wires:
					if adjacent_wire.len > 0 {
						// for each cable on the cable (positions) stack
						// 	for each adjacent tile
						// 		if the tile is an i/o -> put in the i/o lists of the wire corresponding to the id of the cable
						//		if it is a cable (adj_cable)
						//			if adj_cable is already in a wire list:
						// 				if it is the same list as cable : already processed -> continue the for loop
						//				else :
						//				 merge the two wire lists: done
						// 					copy all the arrays of the first one into the second one
						//					replace all the ids of the second one by the first one's in the id_stack
						//					delete the second wire
						// 			else: add adj_cable to the wire list of cable
						//			add adj_cable in the stack (with it's wire id on the id_stack)
						//		else: do nothing

						mut new_wires := []Wire{len: adjacent_wires.len, init: Wire{
							rid:          index
							cable_coords: [coo_adj_wire[index]]
						}}
						mut c_stack := [][]int{len: adjacent_wires.len, init: coo_adj_wire[index]}
						mut id_stack := []int{len: adjacent_wires.len, init: index}

						for c_stack.len > 0 { // for each wire in the stack
							cable := w_stack.pop()
							cable_id := id_stack.pop()
							for coo in [[0, 1], [0, -1], [1, 0],
								[-1, 0]] { // for each adjacent tile
								ajd_id, is_input, x_off, y_off := app.wire_next_gate_id_coo(cable[0],
									cable[1], coo[0], coo[1])
								if ajd_id != empty_id {
									total_x := cable[0] + x_off
									total_y := cable[1] + y_off
									mut adj_chunkmap := app.get_chunkmap_at_coords(total_x,
										total_y)
									adj_x_map := total_x % chunk_size
									adj_y_map := total_y % chunk_size
									assert adj_id == adj_chunkmap[adj_x_map][adj_y_map]
									if adj_id & elem_type_mask == elem_wire_bits { // if is a wire
										adj_coo := [total_x, total_y]
										mut wid_adj := which_wire(new_wires, adj_coo) // will be the id of the wire in which the actual adj cable is
										if wid_adj == -1 { // if the coord is not already in a wire list
											for mut wire in new_wires { // find the wire where cable is
												if wire.rid == cable_id {
													wid_adj = cable_id
													wire.cable_coords << adj_coo
												}
											}
											if wid_ajd == -1 {
												log_quit('${@LINE} should have found the appropriate wire')
											}
										} else {
											if wid_adj != cable_id { // if is in a list but not the same as cable
												wid_adj = cable_id
												// merge the lists
												mut i_first := -1
												mut i_sec := -1
												for iw, wire in new_wires {
													if wire.rid == cable_id {
														i_first = iw
													} else if wire.rid == id {
														i_sec = iw
													}
												}

												new_wires[i_first].cable_coords << new_wires[i_sec].cable_coords
												new_wires[i_first].inps << new_wires[i_sec].inps
												new_wires[i_first].outs << new_wires[i_sec].outs
												for mut ids in id_stack {
													if ids == i_sec {
														ids = i_first
													}
												}
												new_wires.delete(i_sec)
											} else {
												continue // was already processed
											}
										}
										// put the actual adj cable on the stack
										c_stack << adj_coo
										id_stack << wid_adj
									} else {
										// it is an input or an output, or else the wire_next_gate_id_coo function would have returned empty_id
										for mut wire in new_wires { // find the wire where cable is
											if wire.rid == cable_id {
												if is_input {
													wire.inps << adj_id
												} else {
													wire.outs << adj_id
												}
											}
										}
									}
								}
							}
						}

						_, idx := app.get_elem_state_idx_by_id(id, 0)
						new_wires[0].rid = id
						app.wires[idx] = new_wires[0]
						for mut wire in new_wires[1..] {
							wire.rid = app.w_next_rid | elem_wire_bits
							app.wires << wire
							app.w_next_rid++
						}

						// change the ids of the cables on the map and the I/O's i/o (the previous I/O (that were next to the wire) and actual I/O of the new wires)
						for inp in adjacent_inps {
							app.add_output(inp, empty_id)
						}
						for out in adjacent_outs {
							app.add_output(out, empty_id)
						}
						for wire in new_wires {
							for coo in wire.cable_coos {
								mut adj_chunkmap := app.get_chunkmap_at_coords(coo[0],
									coo[1])
								adj_x_map := coo[0] % chunk_size
								adj_y_map := coo[1] % chunk_size
								adj_chunkmap[adj_x_map][adj_y_map] = wire.rid
							}
							
							for inp in wire.inps {
								app.add_output(inp, wire.rid)
							}
							for out in wire.outs {
								app.add_output(out, wire.rid)
							}
						}
					} else {
						_, idx := app.get_elem_state_idx_by_id(id, 0)
						app.wires.delete(idx)
						app.w_states[0].delete(idx)
						app.w_states[1].delete(idx)
					}

					// 1. done
					chunkmap[x_map][y_map] = empty_id

					// 3. done
					for inp_id in adjacent_inps {
						app.add_output(inp_id, empty_id)
					}
					for out_id in adjacent_outs {
						app.add_input(out_id, empty_id)
					}
				}
				elem_crossing_bits {
					// 1. done
					chunkmap[x_map][y_map] = empty_id

					// 2. done: no state & no struct

					// 3. WIP
					s_adj_id, s_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 0, 1)
					n_adj_id, n_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 0, -1)
					e_adj_id, e_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 1, 0)
					w_adj_id, w_is_input, _, _ := app.wire_next_gate_id_co_cooo(x, y, -1, 0)
					if s_adj_id != empty_id && n_adj_id != empty_id {
						if s_is_input && !n_is_input { // s is the input of n
							app.add_input(n_adj_id, s_adj_id)
							app.add_output(s_adj_id, n_adj_id)
						} else if !s_is_input && n_is_input {
							app.add_input(s_adj_id, n_adj_id)
							app.add_output(n_adj_id, s_adj_id)
						}
					}
					if e_adj_id != empty_id && w_adj_id != empty_id {
						if e_is_input && !w_is_input { // s is the input of n
							app.add_input(w_adj_id, e_adj_id)
							app.add_output(e_adj_id, w_adj_id)
						} else if !e_is_input && w_is_input {
							app.add_input(e_adj_id, w_adj_id)
							app.add_output(w_adj_id, e_adj_id)
						}
					}
				} else {
					log_quit("${@LINE} should not get into this else")
				}
			}
		}
	}
}

fn which_wire(new_wires []Wire, coo []int) int {
	for wire in new_wires {
		i := wire.cable_coords.index(coo)
		if i != -1 {
			return i
		}
	}
	return -1
}

fn (mut app App) placement(_x_start u32, _y_start u32, _x_end u32, _y_end u32) {
	// 1.
	// set the tile id to:
	// the type (2 most significant bits)
	// the state (3rd) -> off by default
	// the orientation (4,5th)
	// the rid (all bits to the left)
	// 2.
	// add the struct to the array (with the right fields)
	// add the state to the arrays (there are 2 state arrays to fill /!\)
	// 3.
	// update the output/inputs fields of the adjacent elements
	// 4.
	// add one to the rid of the type

	x_start, x_end := if _x_start > _x_end {
		_x_end, _x_start
	} else {
		_x_start, _x_end
	}
	y_start, y_end := if _y_start > _y_end {
		_y_end, _y_start
	} else {
		_y_start, _y_end
	}

	mut x_ori, mut y_ori := match app.selected_ori {
		// Output direction
		north { 0, -1 }
		south { 0, 1 }
		east { 1, 0 }
		west { -1, 0 }
		else { log_quit('${@LINE} unknown orientation') }
	}
	match app.selected_item {
		.not {
			for x in x_start .. x_end {
				for y in y_start .. y_end {
					mut chunkmap := app.get_chunkmap_at_coords(x, y)
					x_map := x % chunk_size
					y_map := y % chunk_size
					if chunkmap[x_map][y_map] != 0x0 { // map not empty
						continue
					}

					// 1. done
					id := elem_not_bits | app.n_next_rid | app.selected_ori
					chunkmap[x_map][y_map] = id

					// 2. done
					inp_id := app.next_gate_id(x, y, -x_ori, -y_ori)
					out_id := app.next_gate_id(x, y, x_ori, y_ori)
					app.nots << Nots{id, inp_id, out_id, x, y}
					app.n_states[0] << false // default state & important to do the two lists
					app.n_states[1] << false // default state

					// 3. done
					app.add_input(out_id, id)
					app.add_output(inp_id, id)

					// 4. done
					app.n_next_rid++
				}
			}
		}
		.diode {
			for x in x_start .. x_end {
				for y in y_start .. y_end {
					mut chunkmap := app.get_chunkmap_at_coords(x, y)
					x_map := x % chunk_size
					y_map := y % chunk_size
					if chunkmap[x_map][y_map] != 0x0 { // map not empty
						continue
					}

					// 1. done
					id := elem_diode_bits | app.d_next_rid | app.selected_ori
					chunkmap[x_map][y_map] = id

					// 2. done
					inp_id := app.next_gate_id(x, y, -x_ori, -y_ori)
					out_id := app.next_gate_id(x, y, x_ori, y_ori)
					app.diodes << Diode{id, inp_id, out_id, x, y}
					app.d_states[0] << false // default state & important to do the two lists
					app.d_states[1] << false // default state

					// 3. done
					app.add_input(out_id, id)
					app.add_output(inp_id, id)

					// 4. done
					app.d_next_rid++
				}
			}
		}
		.on {
			for x in x_start .. x_end {
				for y in y_start .. y_end {
					mut chunkmap := app.get_chunkmap_at_coords(x, y)
					x_map := x % chunk_size
					y_map := y % chunk_size
					if chunkmap[x_map][y_map] != 0x0 { // map not empty
						continue
					}

					// 1. done
					id := elem_on_bits | app.selected_ori
					chunkmap[x_map][y_map] = id

					// 2. done
					// no arrays for the ons

					// 3. done; only an input for other elements
					out_id := app.next_gate_id(x, y, x_ori, y_ori)
					app.add_input(out_id, id)

					// 4. done, no need
				}
			}
		}
		.wire {
			for x in x_start .. x_end {
				for y in y_start .. y_end {
					mut chunkmap := app.get_chunkmap_at_coords(x, y)
					x_map := x % chunk_size
					y_map := y % chunk_size
					if chunkmap[x_map][y_map] != 0x0 { // map not empty
						continue
					}

					// Find if a part of an existing wire
					mut adjacent_wires := []u64{}
					mut adjacent_inps := []u64{}
					mut adjacent_outs := []u64{}
					for coo in [[0, 1]!, [0, -1]!, [1, 0]!, [-1, 0]!]! {
						adj_id, is_input, _, _ := app.wire_next_gate_id_coo(x, y, coo[0],
							coo[1])
						if adj_id == empty_id {
						} else if adj_id & elem_type_mask == elem_wire_bits {
							adjacent_wires << adj_id
						} else {
							if is_input {
								adjacent_inps << adj_id // for the new inps
							} else {
								adjacent_outs << adj_id // for the new inps
							}
						}
					}

					// Join the wires:
					if adjacent_wires.len > 0 {
						adjacent_wires.sort() // the id order is the same as the idx order so no problem for deletion
						_, first_i := app.get_elem_state_idx_by_id(adjacent_wires[0],
							0)
						for wire in adjacent_wires[1..] {
							_, i := app.get_elem_state_idx_by_id(wire, 0)
							for coo in app.wires[i].cable_coords {
								// change the id of all the cables on the map
								mut w_chunkmap := app.get_chunkmap_at_coords(coo[0], coo[1])
								w_chunkmap[coo[0] % chunk_size][coo[1] % chunk_size] &= ~elem_type_mask
								w_chunkmap[coo[0] % chunk_size][coo[1] % chunk_size] |= adjacent_wires[0]
							}
							// change the inputs / outputs' i/o ids
							for inp in app.wires[i].inps {
								app.add_output(inp, wire)
							}
							for out in app.wires[i].outs {
								app.add_input(out, wire)
							}
							// merge all the arrays in the new main wire
							app.wires[first_i].cable_coords << app.wires[i].cable_coords
							app.wires[first_i].inps << app.wires[i].inps
							app.wires[first_i].outs << app.wires[i].outs
							// delete the old wires
							app.wires.delete(i)
							app.w_states[0].delete(i)
							app.w_states[1].delete(i)
						}
					} else {
						app.wires << Wire{
							rid: app.w_next_rid
						}
						adjacent_wires << app.w_next_rid
						app.w_states[0] << false
						app.w_states[1] << false
						// 4. done /!\ only if creating a new wire
						app.w_next_rid++
					}
					_, first_i := app.get_elem_state_idx_by_id(adjacent_wires[0], 0)

					// 1. done
					chunkmap[x_map][y_map] = elem_wire_bits | adjacent_wires[0] // no orientation

					// 2. done
					app.wires[first_i].cable_coords << [x, y]!
					app.wires[first_i].inps << adjacent_inps
					app.wires[first_i].outs << adjacent_outs

					// 3. done
					for inp_id in adjacent_inps {
						app.add_output(inp_id, adjacent_wires[0])
					}
					for out_id in adjacent_outs {
						app.add_input(out_id, adjacent_wires[0])
					}
				}
			}
		}
		.crossing {
			for x in x_start .. x_end {
				for y in y_start .. y_end {
					mut chunkmap := app.get_chunkmap_at_coords(x, y)
					x_map := x % chunk_size
					y_map := y % chunk_size
					if chunkmap[x_map][y_map] != 0x0 { // map not empty
						continue
					}
					// 1. done; they all have the same id
					chunkmap[x_map][y_map] = elem_crossing_bits

					// 2. done: no state & no struct

					// 3. done
					s_adj_id, s_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 0, 1)
					n_adj_id, n_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 0, -1)
					e_adj_id, e_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 1, 0)
					w_adj_id, w_is_input, _, _ := app.wire_next_gate_id_coo(x, y, -1, 0)
					if s_adj_id != empty_id && n_adj_id != empty_id {
						if s_is_input && !n_is_input { // s is the input of n
							app.add_input(n_adj_id, s_adj_id)
							app.add_output(s_adj_id, n_adj_id)
						} else if !s_is_input && n_is_input {
							app.add_input(s_adj_id, n_adj_id)
							app.add_output(n_adj_id, s_adj_id)
						}
					}
					if e_adj_id != empty_id && w_adj_id != empty_id {
						if e_is_input && !w_is_input { // s is the input of n
							app.add_input(w_adj_id, e_adj_id)
							app.add_output(e_adj_id, w_adj_id)
						} else if !e_is_input && w_is_input {
							app.add_input(e_adj_id, w_adj_id)
							app.add_output(w_adj_id, e_adj_id)
						}
					}

					// 4. done: no rid
				}
			}
		}
	}
}

// add input_id to the input(s) of elem_id (if it is a valid id)
fn (mut app App) add_input(elem_id u64, input_id u64) {
	if elem_id != empty_id && elem_id != elem_crossing_bits {
		_, idx := app.get_elem_state_idx_by_id(elem_id, 0) // do not want the state
		if elem_id & elem_type_mask == 0b00 { // not
			app.nots[idx].inp = input_id
		} else if elem_id & elem_type_mask == 0b01 { // diode
			app.diodes[idx].inp = input_id
		} else if elem_id & elem_type_mask == 0b10 { // on -> does not have inputs
		} else if elem_id & elem_type_mask == 0b11 { // wire
			app.wires[idx].inps << input_id
		}
	}
}

// add output_id to the output(s) of elem_id (if it is a valid id)
fn (mut app App) add_output(elem_id u64, output_id u64) {
	if elem_id != empty_id && elem_id != elem_crossing_bits {
		_, idx := app.get_elem_state_idx_by_id(elem_id, 0) // do not want the state
		if elem_id & elem_type_mask == 0b00 { // not
			app.nots[idx].out = output_id
		} else if elem_id & elem_type_mask == 0b01 { // diode
			app.diodes[idx].out = output_id
		} else if elem_id & elem_type_mask == 0b10 { // on -> does not have outputs
		} else if elem_id & elem_type_mask == 0b11 { // wire
			app.wires[idx].outs << output_id
		}
	}
}

// Returns - the id of the next gate that is not orthogonal with these coordinates on the x/y_dir specified
//         - whether or not the next gate is an input or an output of the wire
// Returns empty_id if not a valid input/output
// x_dir -> direction of the step
// the selected ori is irrelevant and will need to use the step direction instead
// returns id, (next_gate is input of the gate), x_delta, y_delta
// example: id, false, 21, 23 -> is an output
fn (mut app App) wire_next_gate_id_coo(x u32, y u32, x_dir int, y_dir int) (u64, bool, int, int) {
	mut next_chunkmap := app.get_chunkmap_at_coords(u32(x + x_dir), u32(y + y_dir))
	mut next_id := next_chunkmap[(x + x_dir) % chunk_size][(y + y_dir) % chunk_size]
	mut input := false
	// Check if next gate's orientation is matching and not orthogonal
	if next_id == elem_crossing_bits {
		// check until wire
		mut x_off := x_dir
		mut y_off := y_dir
		for next_id == elem_crossing_bits {
			x_off += x_dir
			y_off += y_dir
			next_chunkmap = app.get_chunkmap_at_coords(u32(x + x_off), u32(y + y_off))
			next_id = next_chunkmap[(x + x_off) % chunk_size][(y + y_off) % chunk_size]
		}
		next_id, input, _, _ = app.wire_next_gate_id_coo(u32(x + x_off - x_dir), u32(y + y_off - y_dir),
			x_dir, y_dir) // coords of the crossing just before the detected good elem
		return next_id, input, x_off, y_off
	} else if next_id == 0x0 {
		next_id = empty_id
	} else if next_id & elem_type_mask == elem_on_bits {
		// need to return the id of the on gates (all the ons have the same) not an empty one if it is an input -> to know it is always ON
		opp_step_ori := match [x_dir, y_dir]! {
			[0, 1]! {
				north
			}
			[0, -1]! {
				south
			}
			[1, 0]! {
				west
			}
			[-1, 0]! {
				east
			}
			else {
				log_quit('${@LINE} not a valid step for an orientation')
			}
		}
		if opp_step_ori != next_id & ori_mask { // is not an input of the gate
			next_id = empty_id
		} else {
			input = true
		}
	} else if next_id & elem_type_mask == elem_wire_bits {
	} else if next_id & elem_type_mask == elem_not_bits {
		// Need to find the ori of the step and do the check
		ori, opposite_ori := match [x_dir, y_dir]! {
			[0, 1]! {
				south, north
			}
			[0, -1]! {
				north, south
			}
			[1, 0]! {
				east, west
			}
			[-1, 0]! {
				west, east
			}
			else {
				log_quit('${@LINE} not a valid step for an orientation')
			}
		}

		if next_id & ori_mask == ori {
			input = false // output
		} else if next_id & ori_mask == opposite_ori {
			input = true
		} else {
			next_id = empty_id
		}
	} else if next_id & elem_type_mask == elem_diode_bits {
		ori, opposite_ori := match [x_dir, y_dir]! {
			[0, 1]! {
				south, north
			}
			[0, -1]! {
				north, south
			}
			[1, 0]! {
				east, west
			}
			[-1, 0]! {
				west, east
			}
			else {
				log_quit('${@LINE} not a valid step for an orientation')
			}
		}

		if next_id & ori_mask == ori {
			input = false // output
		} else if next_id & ori_mask == opposite_ori {
			input = true
		} else {
			next_id = empty_id
		}
	}
	return next_id, input, x_dir, y_dir
}

// Returns the id of the next gate that is not orthogonal with these coordinates on the x/y_dir specified
// Returns empty_id if not a valid input/output
// x_dir -> direction of the step
fn (mut app App) next_gate_id(x u32, y u32, x_dir int, y_dir int) u64 {
	mut next_chunkmap := app.get_chunkmap_at_coords(u32(x + x_dir), u32(y + y_dir))
	mut next_id := next_chunkmap[(x + x_dir) % chunk_size][(y + y_dir) % chunk_size]
	// Check if next gate's orientation is matching and not orthogonal
	if next_id == elem_crossing_bits {
		// check until wire
		mut x_off := x_dir
		mut y_off := y_dir
		for next_id == elem_crossing_bits {
			x_off += x_dir
			y_off += y_dir
			next_chunkmap = app.get_chunkmap_at_coords(u32(x + x_off), u32(y + y_off))
			next_id = next_chunkmap[(x + x_off) % chunk_size][(y + y_off) % chunk_size]
		}
		return app.next_gate_id(u32(x + x_off - x_dir), u32(y + y_off - y_dir), x_dir,
			y_dir) // coords of the crossing just before the detected good elem
	} else if next_id == 0x0 {
		next_id = empty_id
	} else if next_id & elem_type_mask == elem_on_bits {
		// need to return the id of the on gates (all the ons have the same) not an empty one if it is an input -> to know it is always ON
		step_ori := match [x_dir, y_dir]! {
			[0, 1]! {
				south
			}
			[0, -1]! {
				north
			}
			[1, 0]! {
				east
			}
			[-1, 0]! {
				west
			}
			else {
				log_quit('${@LINE} not a valid step for an orientation')
			}
		}
		if step_ori == app.selected_ori || next_id & ori_mask != app.selected_ori { // is an output of the gate or is not aligned (because the next is a ON)
			next_id = empty_id
		}
	} else if next_id & elem_type_mask == elem_wire_bits {
	} else if next_id & elem_type_mask == elem_not_bits {
		if next_id & ori_mask != app.selected_ori {
			next_id = empty_id
		}
	} else if next_id & elem_type_mask == elem_diode_bits {
		if next_id & ori_mask != app.selected_ori {
			next_id = empty_id
		}
	}
	return next_id
}

// A tick is a unit of time. For each tick, a complete update cycle/process will be effected.
// Update process:
// 1. change which states lists are the actual ones (/!\ when creating/destroying an element, the program must update the actual and the old state lists)
// 2. for each element in the element lists (nots, diodes, wires) do steps 3 and 4
// 3. look at the previous state(s) of the input(s) in the old states lists
// 4. update it's state (in the actual state list and in the id stored in the chunks) accordingly
// It is updated like a graph to avoid running into update order issues.
fn (mut app App) update_cycle() {
	// 1. done
	app.actual_state = (app.actual_state + 1) % 2
	// 2. done
	for i, not in app.nots {
		// 3. done
		old_inp_state, _ := app.get_elem_state_idx_by_id(not.inp, 1)
		// 4. done
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
		// 3. done
		old_inp_state, _ := app.get_elem_state_idx_by_id(diode.inp, 1)
		// 4. done
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
		// 3. done
		mut old_or_inp_state := false // will be all the inputs of the wire ORed
		for inp in wire.inps {
			inp_state, _ := app.get_elem_state_idx_by_id(inp, 1)
			if inp_state {
				old_or_inp_state = true // only one is needed for the OR to be true
				break
			}
		}
		// 4. done
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
	log_quit('${@LINE} Chunk at ${x} ${y} not found')
}

// previous: 0 for actual state, 1 for the previous state
// returns id of the concerned element & the index in the list
// crossing & ons dont have different states nor idx
fn (mut app App) get_elem_state_idx_by_id(id u64, previous u8) (bool, int) {
	concerned_state := (app.actual_state + previous) % 2
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
			} else if app.diodes[mid].rid > rid {
				low = mid + 1
			} else {
				return app.d_states[concerned_state][mid], mid
			}
		}
	} else if id & elem_type_mask == 0b11 { // wire
		mut low := 0
		mut high := app.wires.len
		mut mid := 0 // tmp value
		for low <= high {
			mid = low + ((high - low) >> 1) // low + half
			if app.wires[mid].rid < rid {
				high = mid - 1
			} else if app.wires[mid].rid > rid {
				low = mid + 1
			} else {
				return app.w_states[concerned_state][mid], mid
			}
		}
	}
	log_quit('${@LINE} id not found in get_elem_state_idx_by_id: ${id}')
}

// TODO: Explain ids

// An element is a something placed on the map (so not empty)
// A gate is an element with some inputs or some outputs or both
// The orientation of a gate is where the output is facing

// Crossing: a special element that links it's north & south sides and (separately) it's west and east sides as if it was not there
// Example: a not gate facing west placed next to a crossing (the not gate is on it's west side), will have as input the element placed next to the crossing on the east side
const chunk_size = 100

struct Chunk {
	x      u32
	y      u32
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
	inps         []u64    // id of the input elements outputing to the wire
	outs         []u64    // id of the output elements whose inputs are the wire
	cable_coords [][2]u32 // all the x y coordinates of the induvidual cables (elements) the wire is made of
}

struct App {
mut:
	map           []Chunk
	selected_item Elem
	selected_ori  u64
	actual_state  int // indicate which list is the old state list and which is the actual one (0 for the first, 1 for the second)
	nots          []Nots
	n_next_rid    u64 = 1
	n_states      [2][]bool // the old state and the actual state list
	diodes        []Diode
	d_next_rid    u64 = 1
	d_states      [2][]bool
	wires         []Wire
	w_next_rid    u64 = 1
	w_states      [2][]bool
}
