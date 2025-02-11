import math { abs }
import os
import rand
import time
import gg

const default_colorchip_color_on = gg.Color{197, 209, 227, 255}
const default_colorchip_color_off = gg.Color{47, 49, 54, 255}
const default_camera_pos_x = f64(2_000_000_000.0)
const default_camera_pos_y = f64(2_000_000_000.0)
const gates_path = 'saved_gates/'
const maps_path = 'saved_maps/'
const empty_id = u64(0)
const on_bits = u64(0x2000_0000_0000_0000) // 0010_0000_000...
const elem_not_bits = u64(0x0000_0000_0000_0000) // 0000_0000_000...
const elem_diode_bits = u64(0x4000_0000_0000_0000) // 0100_0000_000...
const elem_on_bits = u64(0xA000_0000_0000_0000) // 1010_0000_000...  always on
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
const chunk_size = 100
const diode_poly_unscaled = [
	[f32(0.2), 1.0, 0.4, 0.0, 0.6, 0.0, 0.8, 1.0], // north
	[f32(0.2), 0.0, 0.8, 0.0, 0.6, 1.0, 0.4, 1.0], // south
	[f32(0.0), 0.2, 1.0, 0.4, 1.0, 0.6, 0.0, 0.8], // west
	[f32(1.0), 0.2, 1.0, 0.8, 0.0, 0.6, 0.0, 0.4], // east
]
const not_rect_unscaled = [// x, y, width, height
	[f32(0.33), 0.0, 0.33, 0.2], // north
	[f32(0.33), 0.8, 0.33, 0.2], // south
	[f32(0.0), 0.33, 0.2, 0.33], // west
	[f32(0.8), 0.33, 0.2, 0.33], // east
]
const not_poly_unscaled = [
	[f32(0.2), 1.0, 0.5, 0.3, 0.8, 1.0], // north
	[f32(0.2), 0.0, 0.8, 0.0, 0.5, 0.7], // south
	[f32(0.0), 0.2, 0.7, 0.5, 0.0, 0.8], // west
	[f32(1.0), 0.2, 1.0, 0.8, 0.3, 0.5], // east
]

struct Palette {
	junc            gg.Color = gg.Color{0, 0, 0, 255}
	junc_v          gg.Color = gg.Color{213, 92, 247, 255} // vertical line
	junc_h          gg.Color = gg.Color{190, 92, 247, 255} // horiz line
	wire_on         gg.Color = gg.Color{131, 247, 92, 255}
	wire_off        gg.Color = gg.Color{247, 92, 92, 255}
	on              gg.Color = gg.Color{89, 181, 71, 255}
	not             gg.Color = gg.Color{247, 92, 170, 255}
	diode           gg.Color = gg.Color{92, 190, 247, 255}
	background      gg.Color = gg.Color{255, 235, 179, 255}
	place_preview   gg.Color = gg.Color{128, 128, 128, 128}
	selection_start gg.Color = gg.Color{26, 107, 237, 128}
	selection_end   gg.Color = gg.Color{72, 97, 138, 128}
	selection_box   gg.Color = gg.Color{66, 136, 245, 128}
	input_preview   gg.Color = gg.Color{217, 159, 0, 128}
}

struct ColorChip { // TODO: save color chips and keyboard inputs too 
	x u32
	y u32
	w u32
	h u32
mut:
	colors []gg.Color // colors to show
	inputs [][2]u32 // the state will be converted to a number (binary) and it will be the index of the shown color
}

struct App {
mut:
	ctx        &gg.Context = unsafe { nil }
	tile_size  int         = 50
	text_input string // holds what the user typed
	colorchips_hidden bool // if colorchips are hidden
	// main menu
	main_menu     bool
	button_solo_x f32 = 0.0 // TODO: make it scale with screensize and place it properly
	button_solo_y f32 = 0.0
	button_solo_w f32 = 300.0
	button_solo_h f32 = 300.0
	// solo menu TODO: display map info of the hovered map (size bits, nb of hours played, gates placed... fun stuff)
	solo_menu           bool
	map_names_list      []string // without folder name
	maps_x_offset       f32 = 5.0
	maps_y_offset       f32 = 50.0
	maps_top_spacing    f32 = 10.0
	maps_h              f32 = 50.0
	maps_w              f32 = 500.0
	button_new_map_x    f32 = 5.0
	button_new_map_y    f32 = 5.0
	button_new_map_size f32 = 40.0
	// edit mode -> edit colorchips
	edit_mode bool
	editmenu_rgb_y f32 = 10.0
	editmenu_rgb_h f32 = 40.0
	editmenu_rgb_w f32 = 40.0
	editmenu_r_x f32 = 60.0
	editmenu_g_x f32 = 110.0
	editmenu_b_x f32 = 160.0
	editmenu_offset_x f32 = 160.0 // TODO: scale w/ screen size
	editmenu_offset_y f32 = 160.0 // TODO: scale
	editmenu_nb_color_by_row int = 10 
	editmenu_colorsize f32 = 50.0
	editmenu_selected_color int = 0 // TODO: show coords of input
	editmenu_offset_inputs_x f32 = 160.0 // TODO: scale w/ screen size
	editmenu_offset_inputs_y f32 = 160.0 // TODO: scale
	editmenu_nb_inputs_by_row int = 10 
	editmenu_inputsize f32 = 50.0
	delete_colorchip_submode bool
	create_colorchip_submode bool // select start and end of the new colorchip
	create_colorchip_x u32 = u32(-1)
	create_colorchip_y u32 = u32(-1)
	create_colorchip_endx u32 = u32(-1)
	create_colorchip_endy u32 = u32(-1)
	choose_colorchip_submode bool // select a colorchip to edit
	steal_settings_submode bool
	add_input_submode bool // to add an input to a colorchip
	edit_color_submode bool // edit colors of a colorchip
	selected_colorchip int // index of the selected colorchip
	// test mode
	test_mode bool
	// camera moving -> default mode
	cam_x     f64 = default_camera_pos_x
	cam_y     f64 = default_camera_pos_y
	move_down bool
	click_x   f32 // Holds the position of the click (start point of the camera movement)
	click_y   f32
	drag_x    f32 // Holds the actual position of the click (to be able to render the moved map even if the camera movement is not yet finished (by releasing the mouse))
	drag_y    f32
	// placement mode
	placement_mode bool
	place_down     bool
	place_start_x  u32 = u32(-1)
	place_start_y  u32
	place_end_x    u32 // Only used for preview
	place_end_y    u32
	// selection mode (left click: starting pos of selection, right click: ending position of selection)
	selection_mode bool
	select_start_x u32 = u32(-1)
	select_start_y u32
	select_end_x   u32
	select_end_y   u32
	// paste mode
	paste_mode bool
	// load gate mode
	load_gate_mode   bool
	gate_name_list   []string // without folder name
	gate_x_offset    f32 = 5.0
	gate_y_offset    f32 = 50.0
	gate_top_spacing f32 = 10.0
	gate_h           f32 = 50.0
	gate_w           f32 = 500.0
	// save gate mode
	save_gate_mode bool
	// keyboard input (force state of a gate to ON) mode
	keyinput_mode bool
	key_pos       map[u8][][]u32 // `n` -> [[0, 3], [32, 53]] : will force the state to ON at x:0 y:3 and x:32 y:53
	tmp_pos_x     u32 = u32(-1)
	tmp_pos_y     u32 = u32(-1)
	// UI on the left border, TODO: need to make it scaling automatically w/ screensize
	ui_width              f32 = 50.0
	button_size           f32 = 40.0
	button_left_padding   f32 = 5.0
	button_top_padding    f32 = 5.0
	cancel_button_pos     u32 = u32(0) // escapes mode, first position, then multiply by padding and button size to get the coords of the button
	confirm_save_gate_pos u32 = 1      // save gate mode
	selection_button_pos  u32 = 1      // only no_mode
	rotate_copy_pos       u32 = 1      // only paste mode
	copy_button_pos       u32 = 1      // only selection mode instead of selection mode button
	choose_colorchip_pos  u32 = 1 	   // edit mode
	load_gate_pos         u32 = 2      // no mode & paste mode
	save_gate_pos         u32 = 2      // selection mode (copies and saves the copied gate)
	edit_color_pos	      u32 = 2	   // edit mode
	item_nots_pos         u32 = 3      // no_mode and placement mode
	create_color_chip_pos u32 = 3	   // selection mode 
	add_input_pos	      u32 = 3	   // edit mode
	item_diode_pos        u32 = 4      // no/placement mode
	steal_settings_pos    u32 = 4	   // edit mode
	item_crossing_pos     u32 = 5      // no/placement mode
	delete_colorchip_pos  u32 = 5	   // edit mode
	item_on_pos           u32 = 6      // no/placement mode
	item_wire_pos         u32 = 7      // no/placement mode
	speed_pos             u32 = 8      // no mode
	slow_pos              u32 = 9      // no mode
	pause_pos             u32 = 10     // no mode
	paste_pos             u32 = 11     // no mode
	save_map_pos          u32 = 12     // no mode
	keyinput_pos          u32 = 13     // no mode
	hide_colorchips_pos   u32 = 14	   // no mode
	selection_delete_pos  u32 = 10     // selection mode
	
	// logic
	map           []Chunk
	map_name      string // to fill when loading a map
	comp_running  bool   // is a map loaded and running
	pause         bool   // is the map updating
	nb_updates    int = 5 // number of updates per second
	todo          []TodoInfo
	selected_item Elem
	selected_ori  u64 = north
	copied        []PlaceInstruction
	actual_state  int // indicate which list is the old state list and which is the actual one, 0 for the first, 1 for the second
	nots          []Nots
	n_next_rid    u64 = 1
	n_states      [2][]bool // the old state and the actual state list
	diodes        []Diode
	d_next_rid    u64 = 1
	d_states      [2][]bool
	wires         []Wire
	w_next_rid    u64 = 1
	w_states      [2][]bool
	forced_states [][]u32 // forced to ON state by a keyboard input
	colorchips    []ColorChip // screens
	palette       Palette // TODO: edit palette and save palette
}

// graphics

fn main() {
	mut app := &App{}
	app.ctx = gg.new_context(
		create_window: true
		window_title:  'Nots'
		user_data:     app
		frame_fn:      on_frame
		event_fn:      on_event
		sample_count:  2
		bg_color:      app.palette.background
	)

	// lancement du programme/de la fenêtre
	app.ctx.run()
}

fn (app App) scale_sprite(a [][]f32) [][]f32 {
	mut new_a := [][]f32{len: a.len, init: []f32{len: a[0].len}}
	for i, dir_a in a {
		for j, coo in dir_a {
			new_a[i][j] = coo * app.tile_size
		}
	}
	return new_a
}

fn (mut app App) draw_input_buttons() {
	for key in app.key_pos.keys() {
		for pos in app.key_pos[key] {
			pos_x := f32(f64(pos[0] * u32(app.tile_size)) - app.cam_x)
			pos_y := f32(f64(pos[1] * u32(app.tile_size)) - app.cam_y)
			app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, app.palette.input_preview)
			// TODO: draw_text
		}
	}
	if app.tmp_pos_x != u32(-1) && app.tmp_pos_y != u32(-1) {
		pos_x := f32(f64(app.tmp_pos_x * u32(app.tile_size)) - app.cam_x)
		pos_y := f32(f64(app.tmp_pos_y * u32(app.tile_size)) - app.cam_y)
		app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, app.palette.input_preview)
	}
}
fn (mut app App) draw_placing_preview() {
	x_start, x_end := if app.place_start_x > app.place_end_x {
		app.place_end_x, app.place_start_x
	} else {
		app.place_start_x, app.place_end_x
	}
	y_start, y_end := if app.place_start_y > app.place_end_y {
		app.place_end_y, app.place_start_y
	} else {
		app.place_start_y, app.place_end_y
	}
	for x in x_start .. x_end {
		for y in y_start .. y_end {
			pos_x := f32(f64(x * u32(app.tile_size)) - app.cam_x)
			pos_y := f32(f64(y * u32(app.tile_size)) - app.cam_y)
			app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, app.palette.place_preview)
		}
	}
}

fn (mut app App) draw_selection_box() {
	if app.select_start_x != u32(-1) {
		pos_x := f32(f64(app.select_start_x * u32(app.tile_size)) - app.cam_x)
		pos_y := f32(f64(app.select_start_y * u32(app.tile_size)) - app.cam_y)
		app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, app.palette.selection_start)
	}
	if app.select_end_x != u32(-1) {
		pos_x := f32(f64(app.select_end_x * u32(app.tile_size)) - app.cam_x)
		pos_y := f32(f64(app.select_end_y * u32(app.tile_size)) - app.cam_y)
		app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, app.palette.selection_end)
	}
	if app.select_start_x != u32(-1) && app.select_end_x != u32(-1) {
		x_start, x_end := if app.select_start_x > app.select_end_x {
			app.select_end_x, app.select_start_x
		} else {
			app.select_start_x, app.select_end_x
		}
		y_start, y_end := if app.select_start_y > app.select_end_y {
			app.select_end_y, app.select_start_y
		} else {
			app.select_start_y, app.select_end_y
		}
		for x in x_start .. x_end {
			for y in y_start .. y_end {
				pos_x := f32(f64(x * u32(app.tile_size)) - app.cam_x)
				pos_y := f32(f64(y * u32(app.tile_size)) - app.cam_y)
				app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, app.palette.selection_box)
			}
		}
	}
}

fn on_frame(mut app App) {
	// Draw
	size := app.ctx.window_size()
	app.ctx.begin()
	if app.comp_running {
		// placing preview
		if app.placement_mode && app.place_start_x != u32(-1) { // did not hide the check to be able to see when it is happening
			app.draw_placing_preview()
		}
		if app.selection_mode {
			app.draw_selection_box()
		}
		if app.keyinput_mode {
		}

		// map rendering
		not_poly := app.scale_sprite(not_poly_unscaled)
		not_rect := app.scale_sprite(not_rect_unscaled)
		mut not_poly_offset := []f32{len: 6, cap: 6}
		diode_poly := app.scale_sprite(diode_poly_unscaled)
		mut diode_poly_offset := []f32{len: 8, cap: 8}
		for chunk in app.map {
			chunk_cam_x := chunk.x - (app.cam_x + (app.drag_x - app.click_x) / app.tile_size)
			chunk_cam_y := chunk.y - (app.cam_y + (app.drag_y - app.click_y) / app.tile_size)
			if chunk_cam_x > -chunk_size && chunk_cam_x < size.width {
				if chunk_cam_y > -chunk_size && chunk_cam_y < size.height {
					for x, column in chunk.id_map {
						if chunk_cam_x + x < size.width { // cant break like that for lower bound
							for y, id in column {
								if chunk_cam_y + y < size.height {
									if id == empty_id {
										continue
									}
									pos_x := f32((chunk_cam_x + x) * app.tile_size)
									pos_y := f32((chunk_cam_y + y) * app.tile_size)
									if id == elem_crossing_bits { // same bits as wires so need to be separated
										app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size,
											app.palette.junc)
										app.ctx.draw_rect_filled(pos_x, pos_y + app.tile_size / 3,
											app.tile_size, app.tile_size / 3, app.palette.junc_h)
										app.ctx.draw_rect_filled(pos_x + app.tile_size / 3,
											pos_y, app.tile_size / 3, app.tile_size, app.palette.junc_v)
									} else {
										state_color, not_state_color := if id & on_bits == 0 {
											app.palette.wire_off, app.palette.wire_on
										} else {
											app.palette.wire_on, app.palette.wire_off
										}
										ori := match id & ori_mask {
											north { 0 }
											south { 1 }
											west { 2 }
											east { 3 }
											else { app.log_quit('${@LINE} should not get into this else') }
										}
										match id & elem_type_mask {
											elem_not_bits {
												app.ctx.draw_square_filled(pos_x, pos_y,
													app.tile_size, app.palette.not)
												not_poly_offset[0] = not_poly[ori][0] + pos_x
												not_poly_offset[1] = not_poly[ori][1] + pos_y
												not_poly_offset[2] = not_poly[ori][2] + pos_x
												not_poly_offset[3] = not_poly[ori][3] + pos_y
												not_poly_offset[4] = not_poly[ori][4] + pos_x
												not_poly_offset[5] = not_poly[ori][5] + pos_y
												app.ctx.draw_convex_poly(not_poly_offset,
													state_color)
												app.ctx.draw_rect_filled(not_rect[ori][0] + pos_x,
													not_rect[ori][1] + pos_y, not_rect[ori][2],
													not_rect[ori][3], not_state_color)
											}
											elem_diode_bits {
												app.ctx.draw_square_filled(pos_x, pos_y,
													app.tile_size, app.palette.diode)
												diode_poly_offset[0] = diode_poly[ori][0] + pos_x
												diode_poly_offset[1] = diode_poly[ori][1] + pos_y
												diode_poly_offset[2] = diode_poly[ori][2] + pos_x
												diode_poly_offset[3] = diode_poly[ori][3] + pos_y
												diode_poly_offset[4] = diode_poly[ori][4] + pos_x
												diode_poly_offset[5] = diode_poly[ori][5] + pos_y
												diode_poly_offset[6] = diode_poly[ori][6] + pos_x
												diode_poly_offset[7] = diode_poly[ori][7] + pos_y
												app.ctx.draw_convex_poly(diode_poly_offset,
													state_color)
											}
											elem_on_bits {
												app.ctx.draw_square_filled(pos_x, pos_y,
													app.tile_size, app.palette.on)
											}
											elem_wire_bits {
												app.ctx.draw_square_filled(pos_x, pos_y,
													app.tile_size, state_color)
											}
											else {
												app.log_quit('${@LINE} should not get into this else')
											}
										}
									}
								} else {
									break
								}
							}
						} else {
							break
						}
					}
				}
			}
		}
		if !app.colorchips_hidden {
			for cc in app.colorchips {
				// TODO: compute the index of the color w/ the inputs
				// draw the rect
			}
		}
	}
	app.ctx.end()
}

fn (app App) check_ui_button_click_y(pos u32, mouse_y f32) bool {
	return mouse_y >= pos * (app.button_top_padding + app.button_size) + app.button_top_padding
		&& mouse_y < (pos + 1) * (app.button_top_padding + app.button_size)
}

fn (app App) check_maps_button_click_y(pos int, mouse_y f32) bool {
	return mouse_y >= pos * (app.maps_top_spacing + app.maps_h) + app.maps_y_offset
		&& mouse_y < (pos + 1) * (app.maps_top_spacing + app.maps_h)
}

fn (app App) check_gates_button_click_y(pos int, mouse_y f32) bool {
	return mouse_y >= pos * (app.gate_top_spacing + app.gate_h) + app.gate_y_offset
		&& mouse_y < (pos + 1) * (app.gate_top_spacing + app.gate_h)
}

fn (mut app App) disable_all_ingame_modes() {
	app.edit_mode = false
	app.steal_settings_submode = false
	app.choose_colorchip_submode = false
	app.create_colorchip_submode = false
	app.edit_color_submode = false
	app.add_input_submode = false
	app.delete_colorchip_submode = false
	app.placement_mode = false
	app.selection_mode = false
	app.load_gate_mode = false
	app.paste_mode = false
	app.keyinput_mode = false
	app.save_gate_mode = false
}

fn on_event(e &gg.Event, mut app App) {
	mouse_x := if e.mouse_x < 1.0 {
		1.0
	} else {
		e.mouse_x
	}
	mouse_y := if e.mouse_y < 1.0 {
		1.0
	} else {
		e.mouse_y
	}
	match e.typ {
		.mouse_up {
			if app.main_menu {
				if mouse_x >= app.button_solo_x && mouse_x < app.button_solo_x + app.button_solo_w
					&& mouse_y >= app.button_solo_y
					&& mouse_y < app.button_solo_y + app.button_solo_h {
					app.main_menu = false
					app.solo_menu = true
					app.text_input = ''
					if !os.exists(maps_path) {
						os.mkdir(maps_path) or {
							app.log('Cannot create ${maps_path}, ${err}')
							return
						}
					}
					if !os.exists(gates_path) { // this one too in case
						os.mkdir(maps_path) or {
							app.log('Cannot create ${maps_path}, ${err}')
							return
						}
					}
					app.map_names_list = os.ls(maps_path) or {
						app.log('Cannot list files in ${maps_path}, ${err}')
						return
					}
				}
			} else if app.solo_menu {
				if mouse_x >= app.maps_x_offset && mouse_x < app.maps_x_offset + app.maps_w {
					app.map_names_list = os.ls(maps_path) or {
						app.log('Cannot list files in ${maps_path}, ${err}')
						return
					}
					for i, name in app.map_names_list.filter(it.contains(app.text_input)) { // the maps are filtered with the search field
						if e.mouse_button == .left {
							if app.check_maps_button_click_y(i, mouse_x) {
								app.solo_menu = false
								app.text_input = ''
								app.map_name = name
								app.load_map(name) or {
									app.log('Cannot load map ${name}, ${err}')
									return
								}
								app.pause = false
								app.nb_updates = 2
								app.todo = []
								app.selected_item = .not
								app.selected_ori = north
								app.copied = []
								app.actual_state = 0
								app.comp_running = true
								spawn app.computation_loop()
								app.cam_x = default_camera_pos_x
								app.cam_y = default_camera_pos_y
								return
							}
						}
					}
					if app.text_input != '' && mouse_x >= app.button_new_map_x
						&& mouse_x < app.button_new_map_x + app.button_new_map_size
						&& mouse_y >= app.button_new_map_y
						&& mouse_y < app.button_new_map_y + app.button_new_map_size {
						app.solo_menu = false
						app.map = []Chunk{}
						app.map_name = app.text_input
						app.text_input = ''
						app.pause = false
						app.nb_updates = 2
						app.todo = []
						app.selected_item = .not
						app.selected_ori = north
						app.copied = []
						app.actual_state = 0
						app.nots = []
						app.n_next_rid = 1
						app.n_states[0] = []
						app.n_states[1] = []
						app.diodes = []
						app.d_next_rid = 1
						app.d_states[0] = []
						app.d_states[1] = []
						app.wires = []
						app.w_next_rid = 1
						app.w_states[0] = []
						app.w_states[1] = []
						app.comp_running = true
						spawn app.computation_loop()
						app.cam_x = default_camera_pos_x
						app.cam_y = default_camera_pos_y
					}
				}
			} else if app.comp_running {
				if app.keyinput_mode {
					if mouse_x < app.ui_width {
						if mouse_x >= app.button_left_padding
							&& mouse_x < app.button_size + app.button_left_padding { // button area
							if app.check_ui_button_click_y(app.cancel_button_pos, mouse_y) {
								app.disable_all_ingame_modes()
								app.tmp_pos_x = u32(-1)
								app.tmp_pos_y = u32(-1)
							}
						}
					} else {
						map_x := app.cam_x + (mouse_x / app.tile_size)
						map_y := app.cam_y + (mouse_y / app.tile_size)
						// right click -> delete the pos = click_pos encountered in the map
						// left click -> waiting for input, when input, save pos & key in the map
						if e.mouse_button == .right {
							for key in app.key_pos.keys() {
								i := app.key_pos[key].index([u32(map_x), u32(map_y)])
								if i != -1 {
									app.key_pos[key].delete(i) // it will delete all the "buttons" on this tile, but the multiple buttons are not intended anyways				
								}
							}
						} else if e.mouse_button == .left {
							app.tmp_pos_x = u32(map_x) // TODO: show these too
							app.tmp_pos_y = u32(map_y)
						} else {
							app.tmp_pos_x = u32(-1)
							app.tmp_pos_y = u32(-1)
							// TODO: move, do this with other modes too, it's nice to move w/ middle click when having a mouse
						}
					}
				} else if app.edit_mode {
					if mouse_x < app.ui_width {
						if mouse_x >= app.button_left_padding
							&& mouse_x < app.button_size + app.button_left_padding { // button area
							if app.check_ui_button_click_y(app.cancel_button_pos, mouse_y) {
								app.disable_all_ingame_modes()
								app.create_colorchip_x = u32(-1)
								app.create_colorchip_endx = u32(-1)
							} else if app.check_ui_button_click_y(app.edit_color_pos, mouse_y) {
								if app.selected_colorchip == -1 {
									app.log("No ColorChip selected")
								} else {
									app.disable_all_ingame_modes()
									app.colorchips_hidden = false
									app.edit_color_submode = true
								}
							} else if app.check_ui_button_click_y(app.choose_colorchip_pos, mouse_y) {
								app.disable_all_ingame_modes()
								app.choose_colorchip_submode = true
							} else if app.check_ui_button_click_y(app.create_color_chip_pos, mouse_y) {
								app.disable_all_ingame_modes()
								app.colorchips_hidden = false
								app.create_colorchip_submode = true
							} else if app.check_ui_button_click_y(app.add_input_pos, mouse_y) {
								if app.selected_colorchip == -1 {
									app.log("No ColorChip selected")
								} else {
									app.disable_all_ingame_modes()
									app.colorchips_hidden = true
									app.add_input_submode = true
								}
							} else if app.check_ui_button_click_y(app.steal_settings_pos, mouse_y) {
								if app.selected_colorchip == -1 {
									app.log("No ColorChip selected")
								} else {
									app.disable_all_ingame_modes()
									app.colorchips_hidden = false
									app.steal_settings_submode = true
								}
							} else if app.check_ui_button_click_y(app.delete_colorchip_pos, mouse_y) {
								app.disable_all_ingame_modes()
								app.colorchips_hidden = false
								app.delete_colorchip_submode = true
							}
						}
					} else {
						if app.edit_color_submode && app.selected_colorchip != -1 {
							for i in 0 .. app.colorchips[app.selected_colorchip].inputs {
								x := app.editmenu_offset_inputs_x + i % app.editmenu_nb_inputs_by_row * app.editmenu_inputsize
								y := app.editmenu_offset_inputs_y + i / app.editmenu_nb_inputs_by_row * app.editmenu_inputsize
								if mouse_x >= x && mouse_x < x + app.editmenu_inputsize {
									if mouse_y >= y && mouse_y < y + app.editmenu_inputsize {
										app.colorchips[app.selected_colorchip].inputs.delete(i)
										for app.colorchips[app.selected_colorchip].colors.len > pow(2, app.colorchips[app.selected_colorchip].inputs.len) {
											app.colorchips[app.selected_colorchip].colors.delete[app.colorchips[app.selected_colorchip].len-1]
										}
									}
								}
							}
							for i in 0 .. app.colorchips[app.selected_colorchip].colors {
								x := app.editmenu_offset_x + i % app.editmenu_nb_color_by_row * app.editmenu_colorsize
								y := app.editmenu_offset_y + i / app.editmenu_nb_color_by_row * app.editmenu_colorsize
								if mouse_x >= x && mouse_x < x + app.editmenu_colorsize {
									if mouse_y >= y && mouse_y < y + app.editmenu_colorsize {
										if e.mouse_button == .left {
											app.editmenu_selected_color = i
										} else if e.mouse_button == .right {
											app.colorchips.delete(i)
											app.editmenu_selected_color -= 1
											if app.editmenu_selected_color < 0 {
												app.editmenu_selected_color = 0
											}
											for app.colorchips[app.selected_colorchip].colors.len < pow(2, app.colorchips[app.selected_colorchip].inputs) {
												app.colorchips[app.selected_colorchip].colors << gg.Color{0,0,0,255}
											}
										}
									}
								}
							}
							if mouse_y >= app.editmenu_rgb_y && mouse_y < app.editmenu_rgb_y + app.editmenu_rgb_h {
								if mouse_x >= app.editmenu_r_x && mouse_x < app.editmenu_r_y + app.editmenu_rgb_w {
									if e.mouse_button == .left {
										app.colorchips[app.selected_colorchip].colors[app.editmenu_selected_color].r += 1
									} else if e.mouse_button == .right {
										app.colorchips[app.selected_colorchip].colors[app.editmenu_selected_color].r -= 1
									}							
								}
								if mouse_x >= app.editmenu_g_x && mouse_x < app.editmenu_g_y + app.editmenu_rgb_w {
									if e.mouse_button == .left {
										app.colorchips[app.selected_colorchip].colors[app.editmenu_selected_color].g += 1
									} else if e.mouse_button == .right {
										app.colorchips[app.selected_colorchip].colors[app.editmenu_selected_color].g -= 1
									}							
								}
								if mouse_x >= app.editmenu_b_x && mouse_x < app.editmenu_b_y + app.editmenu_rgb_w {
									if e.mouse_button == .left {
										app.colorchips[app.selected_colorchip].colors[app.editmenu_selected_color].b += 1
									} else if e.mouse_button == .right {
										app.colorchips[app.selected_colorchip].colors[app.editmenu_selected_color].b -= 1
									}							
								}
							}
						} else if app.delete_colorchip_submode {
							map_x := u32(app.cam_x + (mouse_x / app.tile_size))
							map_y := u32(app.cam_y + (mouse_y / app.tile_size))
							mut del_i := -1
							for i, cc in app.colorchips {
								if map_x >= cc.x && map_x < cc.x + cc.w && map_y >= cc.y && map_y < cc.y + cc.h {
									del_i = i
									break
								}
							}
							if del_i > -1 {
								app.colorchips.delete(del_i)
								if app.selected_colorchip == del_i {
									app.selected_colorchip = -1
								}
							}
						} else if app.create_colorchip_submode {
							if app.create_colorchip_x == u32(-1) {
								app.create_colorchip_x = u32(app.cam_x + (mouse_x / app.tile_size))
								app.create_colorchip_y = u32(app.cam_y + (mouse_y / app.tile_size))
							} else if app.create_colorchip_endx == u32(-1) {
								app.create_colorchip_endx = u32(app.cam_x + (mouse_x / app.tile_size))
								app.create_colorchip_endy = u32(app.cam_y + (mouse_y / app.tile_size))
								if app.create_colorchip_x > app.create_colorchip_endx {
									app.create_colorchip_x, app.create_colorchip_endx = app.create_colorchip_endx, app.create_colorchip_x
								}
								if app.create_colorchip_y > app.create_colorchip_endy {
									app.create_colorchip_y, app.create_colorchip_endy = app.create_colorchip_endy, app.create_colorchip_y
								}
								app.colorchips << ColorChip{
									x: app.create_colorchip_x
									y: app.create_colorchip_y
									w: app.create_colorchip_endx - app.create_colorchip_x
									h: app.create_colorchip_endy - app.create_colorchip_y
									colors: [default_colorchip_color_on, default_colorchip_color_off]
								}	
								app.create_colorchip_x = u32(-1)
								app.create_colorchip_endx = u32(-1)
								app.create_colorchip_y = u32(-1)
								app.create_colorchip_endy = u32(-1)
								app.selected_colorchip = app.colorchips.len - 1
							}
						} else if app.add_input_submode && app.selected_colorchip != -1 {
							app.colorchips[app.selected_colorchip].inputs << [u32(app.cam_x + (mouse_x / app.tile_size)), u32(app.cam_y + (mouse_y / app.tile_size))]!
							for app.colorchips[app.selected_colorchip].colors.len < pow(2, app.colorchips[app.selected_colorchip].inputs) {
								app.colorchips[app.selected_colorchip].colors << gg.Color{0,0,0,255}
							}
							app.disable_all_ingame_modes()
						} else if app.choose_colorchip_submode {
							map_x := u32(app.cam_x + (mouse_x / app.tile_size))
							map_y := u32(app.cam_y + (mouse_y / app.tile_size))
							for i, cc in app.colorchips {
								if map_x >= cc.x && map_x < cc.x + cc.w && map_y >= cc.y && map_y < cc.y + cc.h {
									app.selected_colorchip = i
									break
								}
							}
						} else if app.steal_settings_submode && app.selected_colorchip != -1 {
							map_x := u32(app.cam_x + (mouse_x / app.tile_size))
							map_y := u32(app.cam_y + (mouse_y / app.tile_size))
							for i, cc in app.colorchips {
								if map_x >= cc.x && map_x < cc.x + cc.w && map_y >= cc.y && map_y < cc.y + cc.h {
									app.colorchips[app.selected_colorchip].colors = app.colorchips[app.selected_colorchip].colors.clone()
									break
								}
							}
						}
					}
				} else if app.load_gate_mode {
					if mouse_x < app.ui_width {
						if mouse_x >= app.button_left_padding
							&& mouse_x < app.button_size + app.button_left_padding { // button area
							if app.check_ui_button_click_y(app.cancel_button_pos, mouse_y) {
								app.disable_all_ingame_modes()
							}
						}
					} else {
						app.gate_name_list = os.ls(gates_path) or { // todo: do that in the frame update too
							app.log('cannot list files in ${gates_path}, ${err}')
							return
						}
						for i, name in app.gate_name_list.filter(it.contains(app.text_input)) { // the maps are filtered with the search field
							if e.mouse_button == .left {
								if app.check_gates_button_click_y(i, mouse_x) {
									app.disable_all_ingame_modes()
									app.paste_mode = true
									app.text_input = ''
									app.todo << TodoInfo{.load_gate, 0, 0, 0, 0, name}
								}
							}
						}
					}
				} else if app.placement_mode {
					if app.place_down { // TODO: make the UI disapear/fade out when doing a placement
						app.place_down = false
						place_end_x := u32(app.cam_x + mouse_x / app.tile_size)
						place_end_y := u32(app.cam_y + mouse_y / app.tile_size)
						if abs(app.place_start_x - place_end_x) >= abs(app.place_start_y - place_end_y) {
							if app.place_start_x > place_end_x {
								app.selected_ori = west
							} else {
								app.selected_ori = east
							}
							if e.mouse_button == .left {
								// start_y at the end because it's a X placement
								app.todo << TodoInfo{.place, app.place_start_x, app.place_start_y, place_end_x, app.place_start_y, ''}
							} else if e.mouse_button == .right {
								app.todo << TodoInfo{.removal, app.place_start_x, app.place_start_y, place_end_x, app.place_start_y, ''}
							}
						} else {
							if app.place_start_y > place_end_y {
								app.selected_ori = north
							} else {
								app.selected_ori = south
							}
							if e.mouse_button == .left {
								// start_x at the end because it's a Y placement
								app.todo << TodoInfo{.place, app.place_start_x, app.place_start_y, app.place_start_x, place_end_y, ''}
							} else if e.mouse_button == .right {
								app.todo << TodoInfo{.removal, app.place_start_x, app.place_start_y, app.place_start_x, place_end_y, ''}
							}
						}
						app.place_start_x = u32(-1)
						app.place_start_y = u32(-1)
						app.place_end_x = u32(-1)
						app.place_end_y = u32(-1)
					} else if mouse_x < app.ui_width {
						if mouse_x >= app.button_left_padding
							&& mouse_x < app.button_size + app.button_left_padding { // button area
							if app.check_ui_button_click_y(app.cancel_button_pos, mouse_y) {
								app.disable_all_ingame_modes()
								app.place_start_x = u32(-1)
							} else if app.check_ui_button_click_y(app.item_nots_pos, mouse_y) {
								app.selected_item = .not
							} else if app.check_ui_button_click_y(app.item_diode_pos,
								mouse_y)
							{
								app.selected_item = .diode
							} else if app.check_ui_button_click_y(app.item_crossing_pos,
								mouse_y)
							{
								app.selected_item = .crossing
							} else if app.check_ui_button_click_y(app.item_on_pos, mouse_y) {
								app.selected_item = .on
							} else if app.check_ui_button_click_y(app.item_wire_pos, mouse_y) {
								app.selected_item = .wire
							}
						}
					}
				} else if app.paste_mode {
					if mouse_x < app.ui_width {
						if mouse_x < app.ui_width {
							if mouse_x >= app.button_left_padding
								&& mouse_x < app.button_size + app.button_left_padding { // button area
								if app.check_ui_button_click_y(app.cancel_button_pos,
									mouse_y)
								{
									app.disable_all_ingame_modes()
								} else if app.check_ui_button_click_y(app.rotate_copy_pos,
									mouse_y)
								{
									app.todo << TodoInfo{.rotate, 0, 0, 0, 0, ''}
								} else if app.check_ui_button_click_y(app.load_gate_pos,
									mouse_y)
								{
									app.disable_all_ingame_modes()
									app.load_gate_mode = true
								}
							}
						}
					} else {
						if e.mouse_button == .left {
							app.todo << TodoInfo{.paste, u32(app.cam_x + mouse_x / app.tile_size), u32(
								app.cam_y + mouse_y / app.tile_size), 0, 0, ''}
						}
					}
				} else if app.save_gate_mode {
					if mouse_x < app.ui_width {
						if mouse_x >= app.button_left_padding
							&& mouse_x < app.button_size + app.button_left_padding { // button area
							if app.check_ui_button_click_y(app.cancel_button_pos, mouse_y) {
								app.disable_all_ingame_modes()
								app.select_start_x = u32(-1)
								app.select_end_x = u32(-1)
								app.text_input = ''
							} else if app.check_ui_button_click_y(app.confirm_save_gate_pos,
								mouse_y)
							{
								if app.text_input != '' && app.select_start_x != u32(-1)
									&& app.select_end_x != u32(-1) {
									app.disable_all_ingame_modes()
									// copies because save_gate saves the copied gate
									app.todo << TodoInfo{.copy, app.select_start_x, app.select_start_y, app.select_end_x, app.select_end_y, ''}
									app.todo << TodoInfo{.save_gate, 0, 0, 0, 0, app.text_input}
									app.text_input = ''
									app.select_start_x = u32(-1)
									app.select_end_x = u32(-1)
								}
							}
						}
					}
				} else if app.selection_mode {
					if mouse_x < app.ui_width {
						if mouse_x >= app.button_left_padding
							&& mouse_x < app.button_size + app.button_left_padding { // button area
							if app.check_ui_button_click_y(app.cancel_button_pos, mouse_y) {
								app.disable_all_ingame_modes()
								app.select_start_x = u32(-1)
								app.select_end_x = u32(-1)
							} else if app.check_ui_button_click_y(app.copy_button_pos,
								mouse_y)
							{
								if app.select_start_x != u32(-1) && app.select_end_x != u32(-1) {
									app.todo << TodoInfo{.copy, app.select_start_x, app.select_start_y, app.select_end_x, app.select_end_y, ''}
									app.log('Copied selection')
								}
							} else if app.check_ui_button_click_y(app.selection_delete_pos,
								mouse_y)
							{
								app.todo << TodoInfo{.removal, app.select_start_x, app.select_start_y, app.select_end_x, app.select_end_y, ''}
							} else if app.check_ui_button_click_y(app.save_gate_pos, mouse_y) {
								app.disable_all_ingame_modes()
								app.save_gate_mode = true
								app.text_input = ''
							} else if app.check_ui_button_click_y(app.create_color_chip_pos, mouse_y) {
								if app.select_start_x != u32(-1) && app.select_start_y != u32(-1) 
									&& app.select_end_x != u32(-1) && app.select_end_y != u32(-1) {
									app.disable_all_ingame_modes()
									app.create_colorchip_submode = true									
									app.create_colorchip_x = u32(-1)
									app.create_colorchip_y = u32(-1)
									app.create_colorchip_endx = u32(-1)
									app.create_colorchip_endy = u32(-1)
								}
							}
						}
					} else {
						if e.mouse_button == .left {
							app.select_start_x = u32(app.cam_x + mouse_x / app.tile_size)
							app.select_start_y = u32(app.cam_y + mouse_y / app.tile_size)
						} else if e.mouse_button == .right {
							app.select_end_x = u32(app.cam_x + mouse_x / app.tile_size)
							app.select_end_y = u32(app.cam_y + mouse_y / app.tile_size)
						}
					}
				} else {
					if app.move_down {
						app.move_down = false
						app.cam_x = app.cam_x + ((mouse_x - app.click_x) / app.tile_size)
						app.cam_y = app.cam_y + ((mouse_y - app.click_y) / app.tile_size)
					} else if mouse_x < app.ui_width {
						if mouse_x >= app.button_left_padding
							&& mouse_x < app.button_size + app.button_left_padding { // button area
							if app.check_ui_button_click_y(app.selection_button_pos, mouse_y) {
								app.disable_all_ingame_modes()
								app.selection_mode = true
							} else if app.check_ui_button_click_y(app.item_nots_pos, mouse_y) {
								app.disable_all_ingame_modes()
								app.selected_item = .not
								app.placement_mode = true
							} else if app.check_ui_button_click_y(app.item_diode_pos,
								mouse_y)
							{
								app.disable_all_ingame_modes()
								app.selected_item = .diode
								app.placement_mode = true
							} else if app.check_ui_button_click_y(app.item_crossing_pos,
								mouse_y)
							{
								app.disable_all_ingame_modes()
								app.selected_item = .crossing
								app.placement_mode = true
							} else if app.check_ui_button_click_y(app.item_on_pos, mouse_y) {
								app.disable_all_ingame_modes()
								app.selected_item = .on
								app.placement_mode = true
							} else if app.check_ui_button_click_y(app.item_wire_pos, mouse_y) {
								app.disable_all_ingame_modes()
								app.selected_item = .wire
								app.placement_mode = true
							} else if app.check_ui_button_click_y(app.speed_pos, mouse_y) {
								app.nb_updates += 1
							} else if app.check_ui_button_click_y(app.slow_pos, mouse_y) {
								if app.nb_updates > 1 {
									app.nb_updates -= 1
								}
							} else if app.check_ui_button_click_y(app.pause_pos, mouse_y) {
								app.pause = !app.pause
							} else if app.check_ui_button_click_y(app.paste_pos, mouse_y) {
								app.disable_all_ingame_modes()
								app.paste_mode = true
							} else if app.check_ui_button_click_y(app.save_map_pos, mouse_y) {
								app.todo << TodoInfo{.save_map, 0, 0, 0, 0, app.map_name}
							} else if app.check_ui_button_click_y(app.load_gate_pos, mouse_y) {
								app.disable_all_ingame_modes()
								app.load_gate_mode = true
							} else if app.check_ui_button_click_y(app.hide_colorchips_pos, mouse_y) {
								app.colorchips_hidden = !app.colorchips_hidden
							}
						}
					}
				}
			}
		}
		.mouse_down {
			if app.comp_running {
				if app.placement_mode {
					if mouse_x <= app.ui_width {
					} else {
						if !app.place_down {
							app.place_down = true
							app.place_start_x = u32(app.cam_x + mouse_x / app.tile_size)
							app.place_start_y = u32(app.cam_y + mouse_y / app.tile_size)
						} else {
							place_end_x := u32(app.cam_x + mouse_x / app.tile_size)
							place_end_y := u32(app.cam_y + mouse_y / app.tile_size)
							if abs(app.place_start_x - place_end_x) >= abs(app.place_start_y - place_end_y) {
								app.place_end_x = place_end_x
								app.place_end_y = app.place_start_y
							} else {
								app.place_end_y = place_end_y
								app.place_end_x = app.place_start_x
							}
						}
					}
				} else if app.selection_mode {
					if mouse_x <= app.ui_width {
					} else {
						if e.mouse_button == .left {
							app.select_start_x = u32(app.cam_x + mouse_x / app.tile_size)
							app.select_start_y = u32(app.cam_y + mouse_y / app.tile_size)
						} else if e.mouse_button == .right {
							app.select_end_x = u32(app.cam_x + mouse_x / app.tile_size)
							app.select_end_y = u32(app.cam_y + mouse_y / app.tile_size)
						}
					}
				} else {
					if mouse_x <= app.ui_width {
					} else {
						if !app.move_down {
							app.move_down = true
							app.click_x = mouse_x
							app.click_y = mouse_y
						}
						app.drag_x = mouse_x
						app.drag_y = mouse_y
					}
				}
			}
		}
		.key_up {
			if app.keyinput_mode {
				if e.char_code != 0 {
					for pos in app.key_pos[u8(e.char_code)] {
						i := app.forced_states.index(pos)
						if i != -1 {
							app.forced_states.delete(i)
						}
					}
				}
			}
		}
		.key_down {
			if app.solo_menu {
				if e.key_code == .delete {
					app.text_input = app.text_input#[..-2]
				}
				if e.char_code != 0 {
					app.text_input += u8(e.char_code).ascii_str()
				}
			} else if app.load_gate_mode {
				if e.key_code == .delete {
					app.text_input = app.text_input#[..-2]
				}
				if e.char_code != 0 {
					app.text_input += u8(e.char_code).ascii_str()
				}
			} else if app.keyinput_mode {
				if e.char_code != 0 {
					if app.tmp_pos_x == u32(-1) || app.tmp_pos_y == u32(-1) { // defensive: prevent map border
						app.forced_states << app.key_pos[u8(e.char_code)]
					} else {
						if mut a := app.key_pos[u8(e.char_code)] {
							a << [app.tmp_pos_x, app.tmp_pos_y]
						} else {
							app.key_pos[u8(e.char_code)] = [
								[app.tmp_pos_x, app.tmp_pos_y],
							]
						}
					}
					app.tmp_pos_x = u32(-1)
					app.tmp_pos_y = u32(-1)
				}
			} else if app.save_gate_mode {
				if e.key_code == .delete {
					app.text_input = app.text_input#[..-2]
				}
				if e.char_code != 0 {
					app.text_input += u8(e.char_code).ascii_str()
				}
			} else {
				match e.key_code {
					.escape {}
					else {}
				}
			}
		}
		else {}
	}
}

// logic

enum Elem as u8 {
	not      // 00
	diode    // 01
	on       // 10
	wire     // 11
	crossing // 111...111
}

@[noreturn]
fn (mut app App) log_quit(message string) {
	panic('Very TODO')
}

fn (mut app App) log(message string) {
	panic('TODO')
}

struct PlaceInstruction {
mut:
	elem        Elem
	orientation u8
	// relative coos to the selection/gate
	rel_x u32
	rel_y u32
}

enum Todos {
	save_map
	removal
	paste
	load_gate
	save_gate
	place
	rotate
	copy
}

struct TodoInfo {
	task  Todos
	x     u32
	y     u32
	x_end u32
	y_end u32
	name  string
}

fn (mut app App) computation_loop() {
	mut cycle_end := i64(0)
	mut avg_update_time := 0.0
	mut now := i64(0)
	for app.comp_running {
		if app.pause {
			time.sleep(30 * time.millisecond)
		} else {
			for pos in app.forced_states {
				app.set_elem_state_by_pos(pos[0], pos[1], true)
			}
			cycle_end = time.now().unix_nano() + i64(1_000_000_000.0 / f32(app.nb_updates)) - i64(avg_update_time) // nanosecs
			for todo in app.todo {
				now = time.now().unix_nano()
				if now < cycle_end {
					match todo.task {
						.save_map {
							app.save_map(todo.name) or { app.log('save copied: ${err}') }
						}
						.removal {
							app.removal(todo.x, todo.y, todo.x_end, todo.y_end)
						}
						.paste {
							app.paste(todo.x, todo.y)
						}
						.load_gate {
							app.load_gate_to_copied(todo.name) or {
								app.log('load gate to copied: ${err}')
							}
						}
						.save_gate {
							app.save_copied(todo.name) or { app.log('save copied: ${err}') }
						}
						.place {
							app.placement(todo.x, todo.y, todo.x_end, todo.y_end)
						}
						.rotate {
							app.rotate_copied()
						}
						.copy {
							app.copy(todo.x, todo.y, todo.x_end, todo.y_end)
						}
					}
				} else {
					break
				}
			}
			now = time.now().unix_nano()
			if app.todo.len == 0 && cycle_end - now >= 10000 { // 10micro sec
				time.sleep((cycle_end - now) * time.nanosecond)
			}

			now = time.now().unix_nano()
			app.update_cycle()
			avg_update_time = f32(time.now().unix_nano() - now) * 0.1 + 0.9 * avg_update_time
		}
	}
}

fn (mut app App) save_copied(name_ string) ! {
	mut name := name_
	if os.exists(gates_path) {
		for os.exists('${gates_path}${name}') {
			name += 'New'
		}
		mut file := os.open_file('${gates_path}${name}', 'w')!
		unsafe { file.write_ptr(app.copied, app.copied.len * int(sizeof(PlaceInstruction))) } // TODO : get the output nb and log it -> successful or not?
		file.close()
	}
}

fn (mut app App) load_map(map_name string) ! {
	// u32(version)
	//
	// i64(app.map.len)
	// for each chunk:
	// 	chunk.x chunk.y
	// 	chunk's content
	//
	// actual_state (which array)
	//
	// i64(app.nots.len)
	// all the nots (their data)
	// nots' state array
	//
	// i64(app.diodes.len)
	// all the diodes (their data)
	// diode's state array
	//
	// i64(app.wires.len)
	// for each wire:
	// 	rid
	//	i64(wire.inps.len)
	//	all the inputs
	//	i64(wire.outs.len)
	//	all the outputs
	//	i64(wire.cable_coords.len)
	// 	for all the cables:
	// 	cable.x  cable.y
	// wire's state array

	if os.exists(maps_path) {
		mut f := os.open(maps_path + map_name)!
		assert f.read_raw[u32]()! == 0
		map_len := f.read_raw[i64]()!
		app.map = []
		mut new_c := Chunk{}
		for _ in 0 .. map_len {
			f.read_struct(mut new_c)!
			app.map << new_c
		}

		app.actual_state = f.read_raw[int]()!

		nots_len := f.read_raw[i64]()!
		mut new_n := Nots{}
		app.nots = []
		for _ in 0 .. nots_len {
			f.read_struct(mut new_n)!
			app.nots << new_n
		}
		f.read_into_ptr(app.n_states[app.actual_state].data, int(nots_len))!
		app.n_states[(app.actual_state + 1) / 2] = []bool{len: int(nots_len)}

		diodes_len := f.read_raw[i64]()!
		mut new_d := Diode{}
		app.diodes = []
		for _ in 0 .. diodes_len {
			f.read_struct(mut new_d)!
			app.diodes << new_d
		}
		f.read_into_ptr(app.d_states[app.actual_state].data, int(diodes_len))!
		app.d_states[(app.actual_state + 1) / 2] = []bool{len: int(diodes_len)}

		wires_len := f.read_raw[i64]()!
		app.wires = []
		for _ in 0 .. wires_len {
			mut new_w := Wire{
				rid: f.read_raw[u64]()!
			}
			inps_len := f.read_raw[i64]()!
			for _ in 0 .. inps_len {
				new_w.inps << f.read_raw[u64]()!
			}
			outs_len := f.read_raw[i64]()!
			for _ in 0 .. outs_len {
				new_w.outs << f.read_raw[u64]()!
			}
			cable_len := f.read_raw[i64]()!
			for _ in 0 .. cable_len {
				new_w.cable_coords << [f.read_raw[u32]()!, f.read_raw[u32]()!]!
			}
			app.wires << new_w
		}
		f.read_into_ptr(app.w_states[app.actual_state].data, int(wires_len))!
		app.w_states[(app.actual_state + 1) / 2] = []bool{len: int(wires_len)}
	}

	/*
	save:
		map           []Chunk
		struct Chunk {
			x      u32
			y      u32
			id_map [chunk_size][chunk_size]u64 // [x][y] x++=east y++=south
		}
		actual_state  int
		nots          []Nots
		n_states      [2][]bool
		diodes        []Diode
		d_states      [2][]bool
		wires         []Wire
		struct Wire {
		mut:
			rid          u64      // real id
			inps         []u64    // id of the input elements outputing to the wire
			outs         []u64    // id of the output elements whose inputs are the wire
			cable_coords [][2]u32 // all the x y coordinates of the induvidual cables (elements) the wire is made of
		}
		w_states      [2][]bool
	*/
}

fn (mut app App) save_map(map_name string) ! {
	// u32(version)
	//
	// i64(app.map.len)
	// for each chunk:
	// 	chunk.x chunk.y
	// 	chunk's content
	//
	// actual_state (which array)
	//
	// i64(app.nots.len)
	// all the nots (their data)
	// nots' state array
	//
	// i64(app.diodes.len)
	// all the diodes (their data)
	// diode's state array
	//
	// i64(app.wires.len)
	// for each wire:
	// 	rid
	//	i64(wire.inps.len)
	//	all the inputs
	//	i64(wire.outs.len)
	//	all the outputs
	//	i64(wire.cable_coords.len)
	// 	for all the cables:
	// 	cable.x  cable.y
	// wire's state array

	mut file := os.open_file('saved_maps/${map_name}', 'w')!
	mut offset := u64(0)
	save_version := u32(0) // must be careful when V changes of int size, especially for array lenghts
	file.write_raw_at(save_version, offset)!
	offset += sizeof(save_version)
	file.write_raw_at(i64(app.map.len), offset)!
	offset += sizeof(i64)
	for mut chunk in app.map {
		file.write_raw_at(chunk.x, offset)!
		offset += sizeof(chunk.x)
		file.write_raw_at(chunk.y, offset)!
		offset += sizeof(chunk.y)
		unsafe {
			file.write_ptr_at(&chunk.id_map, chunk_size * chunk_size * int(sizeof(u64)),
				offset)
		}
		offset += chunk_size * chunk_size * sizeof(u64)
	}
	file.write_raw_at(app.actual_state, offset)!
	offset += sizeof(app.actual_state) // int
	file.write_raw_at(i64(app.nots.len), offset)!
	offset += sizeof(i64)
	unsafe { file.write_ptr_at(app.nots, app.nots.len * int(sizeof(Nots)), offset) }
	offset += u64(app.nots.len) * sizeof(Nots)
	unsafe {
		file.write_ptr_at(app.n_states[app.actual_state], app.nots.len * int(sizeof(bool)),
			offset)
	}
	offset += u64(app.diodes.len) * sizeof(bool)

	file.write_raw_at(i64(app.diodes.len), offset)!
	offset += sizeof(i64)
	unsafe { file.write_ptr_at(app.diodes, app.diodes.len * int(sizeof(Diode)), offset) }
	offset += u64(app.diodes.len) * sizeof(Diode)
	unsafe {
		file.write_ptr_at(app.d_states[app.actual_state], app.diodes.len * int(sizeof(bool)),
			offset)
	}
	offset += u64(app.diodes.len) * sizeof(bool)

	file.write_raw_at(i64(app.wires.len), offset)!
	offset += sizeof(i64)
	for wire in app.wires {
		file.write_raw_at(wire.rid, offset)!
		offset += sizeof(u64)

		file.write_raw_at(i64(wire.inps.len), offset)!
		offset += sizeof(i64)
		unsafe { file.write_ptr_at(wire.inps, wire.inps.len * int(sizeof(u64)), offset) }

		file.write_raw_at(i64(wire.outs.len), offset)!
		offset += sizeof(i64)
		unsafe { file.write_ptr_at(wire.outs, wire.outs.len * int(sizeof(u64)), offset) }

		file.write_raw_at(i64(wire.cable_coords.len), offset)!
		offset += sizeof(i64)
		for cable in wire.cable_coords {
			file.write_raw_at(cable[0], offset)!
			offset += sizeof(u32)
			file.write_raw_at(cable[1], offset)!
			offset += sizeof(u32)
		}
	}
	unsafe {
		file.write_ptr_at(app.w_states[app.actual_state], app.diodes.len * int(sizeof(bool)),
			offset)
	}
	offset += u64(app.wires.len) * sizeof(bool)
}

fn (mut app App) load_gate_to_copied(gate_name string) ! {
	mut f := os.open(gates_path + gate_name)!
	mut read_n := u32(0)
	size := os.inode(gates_path + gate_name).size
	app.copied = []
	mut place := PlaceInstruction{}
	for read_n * sizeof(PlaceInstruction) < size {
		f.read_struct_at(mut place, read_n * sizeof(PlaceInstruction))!
		app.copied << place
		read_n += 1
	}
	f.close()
}

fn (mut app App) rotate_copied() {
	// find size of the patern
	mut max_x := u32(0)
	for place in app.copied {
		if place.rel_x > max_x {
			max_x = place.rel_x
		}
	}
	for mut place in app.copied { // matrix rotation by 90 deg
		tmp_x := place.rel_x
		place.rel_x = place.rel_y
		place.rel_y = max_x - tmp_x - 1
	}
}

fn (mut app App) gate_unit_tests(x u32, y u32) {
	size := u32(100) // we dont know the size of the gates that will be placed, 100 should be okay, same as below
	cycles := 100 // we dont know in how much cycles the bug will happen, needs to match the amount in the fuzz testing because the unit tests will come from there
	app.removal(x, y, x + size, y + size)
	gates: for gate_path in os.ls('test_gates/') or {
		app.log('Listing the test gates: ${err}')
		return
	} {
		app.load_gate_to_copied('test_gates/' + gate_path) or {
			app.log('FAIL: cant load the gate: test_gates/${gate_path}, ${err}')
			continue
		}
		app.paste(x, y)
		for _ in 0 .. cycles {
			app.update_cycle()
			x_err, y_err, str_err := app.test_validity(x, y, x + size, y + size)
			if str_err != '' {
				app.log('FAIL: (validity) ${str_err}')
				println('TODO:')
				println(x_err)
				println(y_err)
				// TODO: show the coords on screen (tp to the right place & color the square)
				continue gates
			}
		}
		app.removal(x, y, x + size, y + size)
	}
}

fn (mut app App) paste(x_start u32, y_start u32) {
	old_item := app.selected_item
	old_ori := app.selected_ori
	for place in app.copied {
		app.selected_item = place.elem
		app.selected_ori = u64(place.orientation) << 56
		app.placement(place.rel_x + x_start, place.rel_y + y_start, place.rel_x + x_start,
			place.rel_y + y_start)
	}
	app.selected_ori = old_ori
	app.selected_item = old_item
}

fn (mut app App) test_validity(_x_start u32, _y_start u32, _x_end u32, _y_end u32) (u32, u32, string) {
	// check all the elems in the rectangle to see if their state / data is valid
	// input/output id (ajdacent tiles)
	// current state (depending on the input)
	// for the wires : check if adj_wires in the same wire

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
			id := chunkmap[x_map][y_map]
			if id == 0x0 { // map empty
				continue
			}
			if id == elem_crossing_bits { // same bits as wires so need to be separated
				continue // do not have any state to check
			}
			ori := id & ori_mask
			step := match ori {
				north {
					[0, 1]!
				}
				south {
					[0, -1]!
				}
				west {
					[1, 0]!
				}
				east {
					[-1, 0]!
				}
				else {
					app.log_quit('${@LINE} not a valid orientation')
				}
			}

			match id & elem_type_mask {
				elem_not_bits, elem_diode_bits {
					inp_id := app.next_gate_id(x, y, -step[0], -step[1], ori)
					if inp_id & rid_mask != app.get_input(id) & rid_mask {
						return x, y, 'problem: input is not the preceding gate'
					}
					out_id := app.next_gate_id(x, y, step[0], step[1], ori)
					if out_id & rid_mask != app.get_output(id) & rid_mask {
						return x, y, 'problem: output is not the following gate'
					}
					inp_old_state, _ := app.get_elem_state_idx_by_id(inp_id, (app.actual_state + 1) % 2)
					if id & elem_type_mask == elem_not_bits {
						state, _ := app.get_elem_state_idx_by_id(id, app.actual_state)
						if state == inp_old_state {
							return x, y, 'problem: NOT did not inverse the input state'
						}
						if (id & on_bits != 0) == inp_old_state {
							return x, y, 'problem: NOT(map state) did not inverse the input state'
						}
					} else { // diode
						state, _ := app.get_elem_state_idx_by_id(id, app.actual_state)
						if state != inp_old_state {
							return x, y, 'problem: Diode did not match the input state'
						}
						if (id & on_bits != 0) != inp_old_state {
							return x, y, 'problem: Diode(map state) did not match the input state'
						}
					}
				}
				elem_on_bits { // do not have any state to check
				}
				elem_wire_bits {
					s_adj_id, s_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 0, 1)
					n_adj_id, n_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 0, -1)
					e_adj_id, e_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 1, 0)
					w_adj_id, w_is_input, _, _ := app.wire_next_gate_id_coo(x, y, -1,
						0)
					wire_state, wire_idx := app.get_elem_state_idx_by_id(id, app.actual_state)
					if (id & on_bits != 0) != wire_state {
						return x, y, "problem: cable(map state)'s state is not the same as the wire"
					}
					if s_adj_id != empty_id {
						if s_adj_id & elem_type_mask == elem_wire_bits {
							if id & rid_mask != s_adj_id & rid_mask {
								return x, y, 'problem: south wire(${s_adj_id & rid_mask}) has a different id from the wire(${id & rid_mask})'
							}
						} else {
							if s_is_input {
								if s_adj_id !in app.wires[wire_idx].inps.map(it & rid_mask) {
									return x, y, "problem: south(${s_adj_id}) is not in the wire(${id})'s input"
								}
								s_old_state, _ := app.get_elem_state_idx_by_id(s_adj_id,
									(app.actual_state + 1) % 2)
								if s_old_state && !wire_state {
									return x, y, 'problem: wire did not match south On state'
								}
							} else {
								if s_adj_id !in app.wires[wire_idx].outs.map(it & rid_mask) {
									return x, y, "problem: south(${s_adj_id}) is not in the wire(${id})'s output"
								}
							}
						}
					}
					if n_adj_id != empty_id {
						if n_adj_id & elem_type_mask == elem_wire_bits {
							if id & rid_mask != n_adj_id & rid_mask {
								return x, y, 'problem: north wire(${n_adj_id & rid_mask}) has a different id from the wire(${id & rid_mask})'
							}
						} else {
							if n_is_input {
								if n_adj_id & rid_mask !in app.wires[wire_idx].inps.map(it & rid_mask) {
									return x, y, "problem: north(${n_adj_id & rid_mask}) is not in the wire(${id & rid_mask})'s input"
								}
								n_old_state, _ := app.get_elem_state_idx_by_id(n_adj_id,
									(app.actual_state + 1) % 2)
								if n_old_state && !wire_state {
									return x, y, 'problem: wire did not match north On state'
								}
							} else {
								if n_adj_id & rid_mask !in app.wires[wire_idx].outs.map(it & rid_mask) {
									return x, y, "problem: north(${n_adj_id & rid_mask}) is not in the wire(${id & rid_mask})'s output"
								}
							}
						}
					}
					if e_adj_id != empty_id {
						if e_adj_id & elem_type_mask == elem_wire_bits {
							if id & rid_mask != e_adj_id & rid_mask {
								return x, y, 'problem: east wire(${e_adj_id & rid_mask}) has a different id from the wire(${id & rid_mask})'
							}
						} else {
							if e_is_input {
								if e_adj_id & rid_mask !in app.wires[wire_idx].inps.map(it & rid_mask) {
									return x, y, "problem: east(${e_adj_id & rid_mask}) is not in the wire(${id & rid_mask})'s input"
								}
								e_old_state, _ := app.get_elem_state_idx_by_id(e_adj_id,
									(app.actual_state + 1) % 2)
								if e_old_state && !wire_state {
									return x, y, 'problem: wire did not match east On state'
								}
							} else {
								if e_adj_id & rid_mask !in app.wires[wire_idx].outs.map(it & rid_mask) {
									return x, y, "problem: east(${e_adj_id & rid_mask}) is not in the wire(${id & rid_mask})'s output"
								}
							}
						}
					}
					if w_adj_id != empty_id {
						if w_adj_id & elem_type_mask == elem_wire_bits {
							if id & rid_mask != w_adj_id & rid_mask {
								return x, y, 'problem: west wire(${w_adj_id & rid_mask}) has a different id from the wire(${id & rid_mask})'
							}
						} else {
							if w_is_input {
								if w_adj_id & rid_mask !in app.wires[wire_idx].inps.map(it & rid_mask) {
									return x, y, "problem: west(${w_adj_id & rid_mask}) is not in the wire(${id & rid_mask})'s input"
								}
								w_old_state, _ := app.get_elem_state_idx_by_id(w_adj_id,
									(app.actual_state + 1) % 2)
								if w_old_state && !wire_state {
									return x, y, 'problem: wire did not match west On state'
								}
							} else {
								if w_adj_id & rid_mask !in app.wires[wire_idx].outs.map(it & rid_mask) {
									return x, y, "problem: west(${w_adj_id & rid_mask}) is not in the wire(${id & rid_mask})'s output"
								}
							}
						}
					}
				}
				else {
					app.log_quit('${@LINE} should not get into this else')
				}
			}
		}
	}
	return 0, 0, ''
}

fn (mut app App) fuzz(_x_start u32, _y_start u32, _x_end u32, _y_end u32) {
	// place random elems in a rectangle

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
			app.selected_ori = match rand.int_in_range(0, 4) or { 0 } {
				1 { north }
				2 { south }
				3 { east }
				else { west }
			}
			match rand.int_in_range(0, 6) or { 0 } {
				1 {
					app.selected_item = .not
					app.placement(x, y, x, y)
				}
				2 {
					app.selected_item = .diode
					app.placement(x, y, x, y)
				}
				3 {
					app.selected_item = .on
					app.placement(x, y, x, y)
				}
				4 {
					app.selected_item = .wire
					app.placement(x, y, x, y)
				}
				5 {
					app.selected_item = .crossing
					app.placement(x, y, x, y)
				}
				else {}
			}
		}
	}
}

fn (mut app App) copy(_x_start u32, _y_start u32, _x_end u32, _y_end u32) {
	// for all the elements in the rectangle
	// 	add an instruction with the info needed to place the elem later

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

	app.copied = []

	for x in x_start .. x_end + 1 {
		for y in y_start .. y_end + 1 {
			mut chunkmap := app.get_chunkmap_at_coords(x, y)
			x_map := x % chunk_size
			y_map := y % chunk_size
			id := chunkmap[x_map][y_map]
			if id == 0x0 { // map empty
				continue
			}
			if id == elem_crossing_bits { // same bits as wires so need to be separated
				app.copied << PlaceInstruction{.crossing, u8(0), x - x_start, y - y_start}
				continue
			}

			ori := id & ori_mask
			match id & elem_type_mask {
				elem_not_bits {
					app.copied << PlaceInstruction{.not, u8(ori >> 56), x - x_start, y - y_start}
				}
				elem_diode_bits {
					app.copied << PlaceInstruction{.diode, u8(ori >> 56), x - x_start, y - y_start}
				}
				elem_on_bits {
					app.copied << PlaceInstruction{.on, u8(ori >> 56), x - x_start, y - y_start}
				}
				elem_wire_bits {
					app.copied << PlaceInstruction{.wire, u8(0), x - x_start, y - y_start}
				}
				else {
					app.log_quit('${@LINE} should not get into this else')
				}
			}
		}
	}
}

fn (mut app App) removal(_x_start u32, _y_start u32, _x_end u32, _y_end u32) {
	// 1.
	// set the tile id to empty_id
	// 2.
	// remove the struct from the array
	// remove the state from the arrays (there are 2 state arrays to modify ! )
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

	for x in x_start .. x_end + 1 {
		for y in y_start .. y_end + 1 {
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
				else { app.log_quit('${@LINE} unknown orientation') }
			}
			if id == elem_crossing_bits { // same bits as wires so need to be separated
				// 1. done
				chunkmap[x_map][y_map] = empty_id

				// 2. done: no state & no struct

				// 3. done
				s_adj_id, s_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 0, 1)
				n_adj_id, n_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 0, -1)
				e_adj_id, e_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 1, 0)
				w_adj_id, w_is_input, _, _ := app.wire_next_gate_id_coo(x, y, -1, 0)
				if s_adj_id != empty_id && n_adj_id != empty_id {
					if s_adj_id & elem_type_mask == elem_wire_bits
						&& n_adj_id & elem_type_mask == elem_wire_bits {
						// two wires: separate them
						app.separate_wires([[u32(0), 1]!, [u32(0), -1]!], s_adj_id) // same id for north and south
					} else if s_adj_id & elem_type_mask == elem_wire_bits {
						// one side is a wire: add the new i/o for the wire & for the gate
						_, idx := app.get_elem_state_idx_by_id(s_adj_id, 0)
						if n_is_input {
							i := app.wires[idx].inps.index(n_adj_id)
							app.wires[idx].inps.delete(i) // remove the input from the wire
							app.add_output(s_adj_id, empty_id) // remove output of the gate
						} else {
							i := app.wires[idx].outs.index(n_adj_id)
							app.wires[idx].outs.delete(i) // remove the input from the wire
							app.add_input(s_adj_id, empty_id) // remove output of the gate
						}
					} else if n_adj_id & elem_type_mask == elem_wire_bits {
						// one side is a wire: add the new i/o for the wire & for the gate
						_, idx := app.get_elem_state_idx_by_id(n_adj_id, 0)
						if s_is_input {
							i := app.wires[idx].inps.index(s_adj_id)
							app.wires[idx].inps.delete(i) // remove the input from the wire
							app.add_output(n_adj_id, empty_id) // remove output of the gate
						} else {
							i := app.wires[idx].outs.index(s_adj_id)
							app.wires[idx].outs.delete(i) // remove the input from the wire
							app.add_input(n_adj_id, empty_id) // remove output of the gate
						}
					} else {
						// If the two sides are standard gates:
						if s_is_input && !n_is_input { // s is the input of n
							app.add_input(n_adj_id, empty_id)
							app.add_output(s_adj_id, empty_id)
						} else if !s_is_input && n_is_input {
							app.add_input(s_adj_id, empty_id)
							app.add_output(n_adj_id, empty_id)
						}
					}
				}
				if e_adj_id != empty_id && w_adj_id != empty_id {
					if e_adj_id & elem_type_mask == elem_wire_bits
						&& w_adj_id & elem_type_mask == elem_wire_bits {
						// two wires: separate them
						app.separate_wires([[u32(1), 0]!, [u32(-1), 0]!], e_adj_id) // same id for east and west
					} else if e_adj_id & elem_type_mask == elem_wire_bits {
						// one side is a wire: add the new i/o for the wire & for the gate
						_, idx := app.get_elem_state_idx_by_id(e_adj_id, 0)
						if w_is_input {
							i := app.wires[idx].inps.index(w_adj_id)
							app.wires[idx].inps.delete(i) // remove the input from the wire
							app.add_output(e_adj_id, empty_id) // remove output of the gate
						} else {
							i := app.wires[idx].outs.index(e_adj_id)
							app.wires[idx].outs.delete(i) // remove the input from the wire
							app.add_input(e_adj_id, empty_id) // remove output of the gate
						}
					} else if w_adj_id & elem_type_mask == elem_wire_bits {
						// one side is a wire: add the new i/o for the wire & for the gate
						_, idx := app.get_elem_state_idx_by_id(w_adj_id, 0)
						if e_is_input {
							i := app.wires[idx].inps.index(e_adj_id)
							app.wires[idx].inps.delete(i) // remove the input from the wire
							app.add_output(w_adj_id, empty_id) // remove output of the gate
						} else {
							i := app.wires[idx].outs.index(e_adj_id)
							app.wires[idx].outs.delete(i) // remove the input from the wire
							app.add_input(w_adj_id, empty_id) // remove output of the gate
						}
					} else {
						// If the two sides are standard gates:
						if e_is_input && !w_is_input { // s is the input of n
							app.add_input(w_adj_id, empty_id)
							app.add_output(e_adj_id, empty_id)
						} else if !e_is_input && w_is_input {
							app.add_input(e_adj_id, empty_id)
							app.add_output(w_adj_id, empty_id)
						}
					}
				}
				continue // do not get in the match
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
					inp_id := app.next_gate_id(x, y, -x_ori, -y_ori, id & ori_mask)
					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
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
					inp_id := app.next_gate_id(x, y, -x_ori, -y_ori, id & ori_mask)
					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
					app.add_input(out_id, empty_id)
					app.add_output(inp_id, empty_id)
				}
				elem_on_bits {
					// 1. done
					chunkmap[x_map][y_map] = empty_id

					// 2. done
					// no arrays for the ons

					// 3. done; only an input for other elements
					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
					app.add_input(out_id, empty_id)
				}
				elem_wire_bits {
					// Find if a part of an existing wire
					mut coo_adj_wire := [][2]u32{}
					mut adjacent_inps := []u64{}
					mut adjacent_outs := []u64{}
					for coo in [[0, 1], [0, -1], [1, 0], [-1, 0]] {
						adj_id, is_input, _, _ := app.wire_next_gate_id_coo(x, y, coo[0],
							coo[1])
						if adj_id == empty_id {
						} else if adj_id & elem_type_mask == elem_wire_bits {
							coo_adj_wire << [u32(int(x) + coo[0]), u32(int(y) + coo[1])]!
						} else {
							if is_input {
								adjacent_inps << adj_id // for the old inps
							} else {
								adjacent_outs << adj_id // for the old inps
							}
						}
					}

					// 1. done; doing it before the join because it would count it as a valid wire
					chunkmap[x_map][y_map] = empty_id

					// 2. done
					// Separate the wires:
					if coo_adj_wire.len > 1 {
						app.separate_wires(coo_adj_wire, id)
					} else if coo_adj_wire.len == 0 {
						_, idx := app.get_elem_state_idx_by_id(id, 0)
						app.wires.delete(idx)
						app.w_states[0].delete(idx)
						app.w_states[1].delete(idx)
					} else { // if only 1 adjacent wire: remove the cable from the wire
						_, idx := app.get_elem_state_idx_by_id(id, 0)
						i := app.wires[idx].cable_coords.index([x, y]!)
						app.wires[idx].cable_coords.delete(i)
						for inp_id in adjacent_inps {
							i_ := app.wires[idx].inps.index(inp_id)
							app.wires[idx].inps.delete(i_)
						}
						for out_id in adjacent_outs {
							i_ := app.wires[idx].outs.index(out_id)
							app.wires[idx].outs.delete(i_)
						}
					}

					// 3. done
					for inp_id in adjacent_inps {
						app.add_output(inp_id, empty_id)
					}
					for out_id in adjacent_outs {
						app.add_input(out_id, empty_id)
					}
				}
				else {
					app.log_quit('${@LINE} should not get into this else')
				}
			}
		}
	}
}

// id: the id of the wire to separate (to reuse the old wire struct)
fn (mut app App) separate_wires(coo_adj_wires [][2]u32, id u64) {
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

	mut new_wires := []Wire{len: coo_adj_wires.len, init: Wire{
		rid:          u64(index)
		cable_coords: [coo_adj_wires[index]]
	}}
	mut c_stack := [][2]u32{len: coo_adj_wires.len, init: coo_adj_wires[index]}
	mut id_stack := []u64{len: coo_adj_wires.len, init: u64(index)}

	for c_stack.len > 0 { // for each wire in the stack
		cable := c_stack.pop()
		cable_id := id_stack.pop()
		for coo in [[0, 1], [0, -1], [1, 0], [-1, 0]] { // for each adjacent tile
			adj_id, is_input, x_off, y_off := app.wire_next_gate_id_coo(cable[0], cable[1],
				coo[0], coo[1])
			if adj_id != empty_id {
				total_x := u32(int(cable[0]) + x_off)
				total_y := u32(int(cable[1]) + y_off)
				mut adj_chunkmap := app.get_chunkmap_at_coords(total_x, total_y)
				adj_x_map := total_x % chunk_size
				adj_y_map := total_y % chunk_size
				assert adj_id == adj_chunkmap[adj_x_map][adj_y_map]
				if adj_id & elem_type_mask == elem_wire_bits { // if is a wire
					adj_coo := [total_x, total_y]!
					mut wid_adj_int := which_wire(new_wires, adj_coo) // will be the id of the wire in which the actual adj cable is
					mut wid_adj := u64(wid_adj_int)
					if wid_adj_int == -1 { // if the coord is not already in a wire list
						for mut wire in new_wires { // find the wire where cable is
							if wire.rid == cable_id {
								wid_adj = cable_id
								wire.cable_coords << adj_coo
							}
						}
						if wid_adj == -1 {
							app.log_quit('${@LINE} should have found the appropriate wire')
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
									ids = u64(i_first)
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

	// Create/Modify the new wires
	_, idx := app.get_elem_state_idx_by_id(id, 0)
	new_wires[0].rid = id
	app.wires[idx] = new_wires[0]
	for mut wire in new_wires[1..] {
		wire.rid = app.w_next_rid | elem_wire_bits
		app.wires << wire
		app.w_next_rid++
	}

	// change the ids of the cables on the map and the I/O's i/o (actual I/O of the new wires)
	for wire in new_wires {
		for coo in wire.cable_coords {
			mut adj_chunkmap := app.get_chunkmap_at_coords(coo[0], coo[1])
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
}

fn which_wire(new_wires []Wire, coo [2]u32) int {
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
		else { app.log_quit('${@LINE} unknown orientation') }
	}
	match app.selected_item {
		.not {
			for x in x_start .. x_end + 1 {
				for y in y_start .. y_end + 1 {
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
					inp_id := app.next_gate_id(x, y, -x_ori, -y_ori, id & ori_mask)
					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
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
			for x in x_start .. x_end + 1 {
				for y in y_start .. y_end + 1 {
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
					inp_id := app.next_gate_id(x, y, -x_ori, -y_ori, id & ori_mask)
					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
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
			for x in x_start .. x_end + 1 {
				for y in y_start .. y_end + 1 {
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
					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
					app.add_input(out_id, id)

					// 4. done, no need
				}
			}
		}
		.wire {
			for x in x_start .. x_end + 1 {
				for y in y_start .. y_end + 1 {
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
					if adjacent_wires.len > 1 { // if only one wire, there is no need to join it
						app.join_wires(mut adjacent_wires)
					} else if adjacent_wires.len == 0 {
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
			for x in x_start .. x_end + 1 {
				for y in y_start .. y_end + 1 {
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
					w_adj_id, w_is_input, _, _ := app.wire_next_gate_id_coo(x, y, -1,
						0)
					if s_adj_id != empty_id && n_adj_id != empty_id {
						if s_adj_id & elem_type_mask == elem_wire_bits
							&& n_adj_id & elem_type_mask == elem_wire_bits {
							// two wires: join them
							mut adjacent_wires := [s_adj_id, n_adj_id]
							app.join_wires(mut adjacent_wires)
						} else if s_adj_id & elem_type_mask == elem_wire_bits {
							// one side is a wire: add the new i/o for the wire & for the gate
							if n_is_input {
								app.add_input(s_adj_id, n_adj_id) // add an input to the wire
								app.add_output(n_adj_id, s_adj_id) // add an output to the gate
							} else {
								app.add_input(n_adj_id, s_adj_id)
								app.add_output(s_adj_id, n_adj_id)
							}
						} else if n_adj_id & elem_type_mask == elem_wire_bits {
							// one side is a wire: add the new i/o for the wire & for the gate
							if s_is_input {
								app.add_input(n_adj_id, s_adj_id)
								app.add_output(s_adj_id, n_adj_id)
							} else {
								app.add_input(s_adj_id, n_adj_id)
								app.add_output(n_adj_id, s_adj_id)
							}
						} else {
							// gates on the two sides
							if s_is_input && !n_is_input { // s is the input of n
								app.add_input(n_adj_id, s_adj_id)
								app.add_output(s_adj_id, n_adj_id)
							} else if !s_is_input && n_is_input {
								app.add_input(s_adj_id, n_adj_id)
								app.add_output(n_adj_id, s_adj_id)
							}
						}
					}
					if e_adj_id != empty_id && w_adj_id != empty_id {
						if e_adj_id & elem_type_mask == elem_wire_bits
							&& w_adj_id & elem_type_mask == elem_wire_bits {
							// two wires: join them
							mut adjacent_wires := [e_adj_id, w_adj_id]
							app.join_wires(mut adjacent_wires)
						} else if e_adj_id & elem_type_mask == elem_wire_bits {
							// one side is a wire: add the new i/o for the wire & for the gate
							if w_is_input {
								app.add_input(e_adj_id, w_adj_id) // add an input to the wire
								app.add_output(w_adj_id, e_adj_id) // add an output to the gate
							} else {
								app.add_input(w_adj_id, e_adj_id)
								app.add_output(e_adj_id, w_adj_id)
							}
						} else if w_adj_id & elem_type_mask == elem_wire_bits {
							// one side is a wire: add the new i/o for the wire & for the gate
							if e_is_input {
								app.add_input(w_adj_id, e_adj_id) // add an input to the wire
								app.add_output(e_adj_id, w_adj_id) // add an output to the gate
							} else {
								app.add_input(e_adj_id, w_adj_id)
								app.add_output(w_adj_id, e_adj_id)
							}
						} else {
							// gates on the two sides
							if e_is_input && !w_is_input { // s is the input of n
								app.add_input(w_adj_id, e_adj_id)
								app.add_output(e_adj_id, w_adj_id)
							} else if !e_is_input && w_is_input {
								app.add_input(e_adj_id, w_adj_id)
								app.add_output(w_adj_id, e_adj_id)
							}
						}
					}

					// 4. done: no rid
				}
			}
		}
	}
}

fn (mut app App) join_wires(mut adjacent_wires []u64) {
	adjacent_wires.sort() // the id order is the same as the idx order so no problem for deletion
	_, first_i := app.get_elem_state_idx_by_id(adjacent_wires[0], 0)
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
}

// get the input of the elem (empty_id for wires & ons)
fn (mut app App) get_input(elem_id u64) u64 {
	if elem_id != empty_id && elem_id != elem_crossing_bits {
		if elem_id & elem_type_mask == 0b00 { // not
			_, idx := app.get_elem_state_idx_by_id(elem_id, 0) // do not want the state
			return app.nots[idx].inp
		} else if elem_id & elem_type_mask == 0b01 { // diode
			_, idx := app.get_elem_state_idx_by_id(elem_id, 0) // do not want the state
			return app.diodes[idx].inp
		} else if elem_id & elem_type_mask == 0b10 { // on -> does not have inputs
		} else if elem_id & elem_type_mask == 0b11 { // wire
		}
	}
	return empty_id
}

// get the output of the elem (empty_id for wires & ons)
fn (mut app App) get_output(elem_id u64) u64 {
	if elem_id != empty_id && elem_id != elem_crossing_bits {
		if elem_id & elem_type_mask == 0b00 { // not
			_, idx := app.get_elem_state_idx_by_id(elem_id, 0) // do not want the state
			return app.nots[idx].out
		} else if elem_id & elem_type_mask == 0b01 { // diode
			_, idx := app.get_elem_state_idx_by_id(elem_id, 0) // do not want the state
			return app.diodes[idx].out
		} else if elem_id & elem_type_mask == 0b10 { // on -> does not have inputs
		} else if elem_id & elem_type_mask == 0b11 { // wire
		}
	}
	return empty_id
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
	conv_x := u32(int(x) + x_dir)
	conv_y := u32(int(y) + y_dir)
	mut next_chunkmap := app.get_chunkmap_at_coords(conv_x, conv_y)
	mut next_id := next_chunkmap[conv_x % chunk_size][conv_y % chunk_size]
	mut input := false
	// Check if next gate's orientation is matching and not orthogonal
	if next_id == elem_crossing_bits {
		// check until wire
		mut x_off := x_dir
		mut y_off := y_dir
		for next_id == elem_crossing_bits {
			x_off = x_dir
			y_off += y_dir
			x_conv := u32(int(x) + x_off)
			y_conv := u32(int(y) + y_off)
			next_chunkmap = app.get_chunkmap_at_coords(x_conv, y_conv)
			next_id = next_chunkmap[x_conv % chunk_size][y_conv % chunk_size]
		}
		next_id, input, _, _ = app.wire_next_gate_id_coo(u32(int(x) + x_off - x_dir),
			u32(int(y) + y_off - y_dir), x_dir, y_dir) // coords of the crossing just before the detected good elem
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
				app.log_quit('${@LINE} not a valid step for an orientation')
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
				app.log_quit('${@LINE} not a valid step for an orientation')
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
				app.log_quit('${@LINE} not a valid step for an orientation')
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

// Returns the id of the next gate that is connected to the gate (on x, y) walking on the x_dir/y_dir specified
// Returns empty_id if not a valid input/output
// x_dir -> direction of the step
// gate_ori : the orientation of the gate used as starting point
fn (mut app App) next_gate_id(x u32, y u32, x_dir int, y_dir int, gate_ori u64) u64 {
	conv_x := u32(int(x) + x_dir)
	conv_y := u32(int(y) + y_dir)
	mut next_chunkmap := app.get_chunkmap_at_coords(conv_x, conv_y)
	mut next_id := next_chunkmap[conv_x % chunk_size][conv_y % chunk_size]
	// Check if next gate's orientation is matching and not orthogonal
	if next_id == elem_crossing_bits {
		// check until wire
		mut x_off := x_dir
		mut y_off := y_dir
		for next_id == elem_crossing_bits {
			x_off += x_dir
			y_off += y_dir
			x_conv := u32(int(x) + x_off)
			y_conv := u32(int(y) + y_off)
			next_chunkmap = app.get_chunkmap_at_coords(x_conv, y_conv)
			next_id = next_chunkmap[x_conv % chunk_size][y_conv % chunk_size]
		}
		return app.next_gate_id(u32(int(x) + x_off - x_dir), u32(int(y) + y_off - y_dir),
			x_dir, y_dir, gate_ori) // coords of the crossing just before the detected good elem
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
				app.log_quit('${@LINE} not a valid step for an orientation')
			}
		}
		if step_ori == gate_ori || next_id & ori_mask != gate_ori { // is an output of the gate or is not aligned (because the next is a ON)
			next_id = empty_id
		}
	} else if next_id & elem_type_mask == elem_wire_bits {
	} else if next_id & elem_type_mask == elem_not_bits {
		if next_id & ori_mask != gate_ori {
			next_id = empty_id
		}
	} else if next_id & elem_type_mask == elem_diode_bits {
		if next_id & ori_mask != gate_ori {
			next_id = empty_id
		}
	}
	return next_id
}

fn (mut app App) set_elem_state_by_pos(x u32, y u32, new_state bool) {
	mut chunkmap := app.get_chunkmap_at_coords(x, y)
	xmap := x % chunk_size
	ymap := y % chunk_size
	id := chunkmap[xmap][ymap]
	if id == elem_crossing_bits || id == 0x0 || id & elem_type_mask == elem_on_bits {
		return
	}
	if new_state {
		chunkmap[xmap][ymap] = chunkmap[xmap][ymap] | on_bits
	} else {
		chunkmap[xmap][ymap] = chunkmap[xmap][ymap] & (~on_bits)
	}
	_, i := app.get_elem_state_idx_by_id(chunkmap[xmap][ymap], 0)
	if id & elem_type_mask == elem_wire_bits {
		app.w_states[app.actual_state][i] = new_state	
	} else if id & elem_type_mask == elem_not_bits {
		app.n_states[app.actual_state][i] = new_state	
	} else if id & elem_type_mask == elem_diode_bits {
		app.d_states[app.actual_state][i] = new_state	
	}
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
	app.log_quit('${@LINE} Chunk at ${x} ${y} not found')
}

// previous: 0 for actual state, 1 for the previous state
// returns id of the concerned element & the index in the list
// crossing & ons dont have different states nor idx
fn (mut app App) get_elem_state_idx_by_id(id u64, previous int) (bool, int) {
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
	app.log_quit('${@LINE} id not found in get_elem_state_idx_by_id: ${id}')
}

// TODO: Explain ids

// An element is a something placed on the map (so not empty)
// A gate is an element with some inputs or some outputs or both
// The orientation of a gate is where the output is facing

// Crossing: a special element that links it's north & south sides and (separately) it's west and east sides as if it was not there
// Example: a not gate facing west placed next to a crossing (the not gate is on it's west side), will have as input the element placed next to the crossing on the east side

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

// ON: a gate that is always ON (only on one side)

// Cables are the individually placable element and two cables are connected if one of
// them is already connected to one that is connected to the other or the two cables are next to each other
// If some cables are connected, they shared their states by being a wire

// a Wire is made out of multiple cables that are connected
// It outputs the OR of all it's inputs
struct Wire {
mut:
	rid          u64      // real id
	inps         []u64    // id of the input elements outputing to the wire
	outs         []u64    // id of the output elements whose inputs are the wire
	cable_coords [][2]u32 // all the x y coordinates of the induvidual cables (elements) the wire is made of
}
