module main

/*
/*
fn test_save() {
	mut app := App{}
	defer {
		app.comp_running = false
		for app.comp_alive {}
	}
	name := 'test'
	app.text_input = name
	app.create_game()
	pos := u32(2_000_000_000)
	app.placement(pos, pos, pos + 100, pos + 100) /// need to separate backend / frontend
	app.quit_map()
}
*/

fn test_load() {
	mut app := App{}
	app.create_game()
	app.comp_running = false
	for app.comp_alive {}
	app.load_gate_to_copied('sourire')!
	check := app.copied.clone()
	app.load_gate_to_copied('oldsourire')!
	assert check == app.copied
	println('Finished test_load')
}

fn test_placement_small() {
	mut app := App{}
	name := 'test'
	app.text_input = name
	app.create_game()
	app.comp_running = false
	app.cl_thread.wait()
	app.nb_updates = 10_000_000
	mut pos := u32(2_000_000_000)

	app.selected_item = .not
	app.placement(pos, pos, pos, pos + 100)
	app.placement(pos, pos, pos + 100, pos)
	// test if they are nots, with the right orientation

	pos += 1
	app.selected_item = .diode
	app.placement(pos, pos, pos, pos + 100)
	app.placement(pos, pos, pos + 100, pos)
	// todo: check if well placed

	pos += 1
	app.selected_item = .crossing
	app.placement(pos, pos, pos, pos + 100)
	app.placement(pos, pos, pos + 100, pos)
	// todo: check if well placed

	pos += 1
	app.selected_item = .wire
	app.placement(pos, pos, pos, pos + 100)
	app.placement(pos, pos, pos + 100, pos)
	// todo: check if well placed

	pos += 1
	app.selected_item = .on
	app.placement(pos, pos, pos, pos + 100)
	app.placement(pos, pos, pos + 100, pos)
	// todo: check if well placed

	app.update_cycle()
	app.update_cycle()
	mut x_err, mut y_err, mut str_err := app.test_validity(pos, pos, pos + 100, pos + 100,
		true, false)
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}

	pos += 1
	app.placement(pos, pos, pos, pos + 100)
	app.placement(pos, pos, pos + 100, pos)
	// todo: check if well placed

	app.update_cycle()
	app.update_cycle()
	x_err, y_err, str_err = app.test_validity(pos, pos, pos + 100, pos + 100, true, false)
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}

	pos += 1
	app.selected_item = .diode
	app.placement(pos, pos, pos, pos + 100)
	app.placement(pos, pos, pos + 100, pos)
	// todo: check if well placed

	app.update_cycle()
	app.update_cycle()
	x_err, y_err, str_err = app.test_validity(pos, pos, pos + 100, pos + 100, true, false)
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}

	pos += 1
	app.selected_item = .crossing
	app.placement(pos, pos, pos, pos + 100)
	app.placement(pos, pos, pos + 100, pos)
	// todo: check if well placed

	app.update_cycle()
	app.update_cycle()
	x_err, y_err, str_err = app.test_validity(pos, pos, pos + 100, pos + 100, true, false)
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}

	pos += 1
	app.selected_item = .wire
	app.placement(pos, pos, pos, pos + 100)
	app.placement(pos, pos, pos + 100, pos)
	// todo: check if well placed

	app.update_cycle()
	app.update_cycle()
	x_err, y_err, str_err = app.test_validity(pos, pos, pos + 100, pos + 100, true, false)
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}

	pos += 1
	app.selected_item = .on
	app.placement(pos, pos, pos, pos + 100)
	app.placement(pos, pos, pos + 100, pos)
	// todo: check if well placed

	app.update_cycle()
	app.update_cycle()
	x_err, y_err, str_err = app.test_validity(pos, pos, pos + 100, pos + 100, true, false)
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}
	println('Finished test_placement_small')
}

fn test_seeded_fuzz_small() {
	mut app := App{}
	name := 'test'
	app.text_input = name
	app.create_game()
	// kill the thread to have control
	app.comp_running = false
	app.cl_thread.wait()

	app.nb_updates = 10_000_000
	pos := u32(2_000_000_000)
	size := u32(10)
	end := pos + size
	nb_cycles := 10000
	seed_offset := 67897
	for i in 0 .. 1000 {
		eprintln(i)
		app.removal(pos, pos, end, end)
		app.fuzz(pos, pos, end, end, 2 * size * size, 2 * size, [u32(seed_offset), i],
			false)
		app.update_cycle()
		for _ in 0 .. nb_cycles {
			app.update_cycle()
			x_err, y_err, str_err := app.test_validity(pos, pos, end, end, true, false)
			if str_err != '' {
				panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
			}
		}
	}
	println('Finished test_seeded_fuzz_small')
}

fn test_seeded_fuzz_placing() {
	mut app := App{}
	name := 'test'
	app.text_input = name
	app.create_game()
	// kill the thread to have control
	app.comp_running = false
	app.cl_thread.wait()

	app.nb_updates = 10_000_000
	pos := u32(2_000_000_000)
	size := u32(10)
	end := pos + size
	nb_cycles := 10
	seed_offset := 237823
	for i in 0 .. 30000 {
		eprintln(i)
		app.removal(pos, pos, end, end)
		app.fuzz(pos, pos, end, end, 2 * size * size, 2 * size, [u32(seed_offset), i],
			false)
		app.update_cycle()
		for _ in 0 .. nb_cycles {
			app.update_cycle()
			x_err, y_err, str_err := app.test_validity(pos, pos, end, end, true, false)
			if str_err != '' {
				panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
			}
		}
	}
	println('Finished test_seeded_fuzz_placing')
}

fn test_seeded_fuzz() {
	mut app := App{}
	name := 'test'
	app.text_input = name
	app.create_game()
	// kill the thread to have control
	app.comp_running = false
	app.cl_thread.wait()

	app.nb_updates = 10_000_000
	pos := u32(2_000_000_000)
	size := u32(100)
	end := pos + size
	nb_cycles := 100
	seed_offset := 973
	for i in 0 .. 300 {
		eprintln(i)
		app.removal(pos, pos, end, end)
		app.fuzz(pos, pos, end, end, 2 * size * size, 2 * size, [u32(seed_offset), i],
			false) // TODO: set the 0 to an offset
		app.update_cycle()
		for _ in 0 .. nb_cycles {
			app.update_cycle()
			x_err, y_err, str_err := app.test_validity(pos, pos, end, end, true, false)
			if str_err != '' {
				panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
			}
		}
	}
	println('Finished test_seeded_fuzz')
}
*/
fn test_placement_removal_big() {
	mut app := App{}
	name := 'test'
	app.text_input = name
	app.create_game()
	app.comp_running = false
	app.cl_thread.wait()
	mut pos := u32(2_000_000_000)

	app.selected_item = .not
	app.placement(pos, pos, pos + 1000, pos + 1000)
	eprintln('placed nots')
	// test if they are nots, with the right orientation

	app.update_cycle()
	app.update_cycle()
	mut x_err, mut y_err, mut str_err := app.test_validity(pos, pos, pos + 1000, pos + 1000,
		true, false)
	eprintln('tested nots')
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}
	app.removal(pos, pos, pos + 1000, pos + 1000)
	eprintln('removed nots')
/*
	app.selected_item = .diode
	app.placement(pos, pos, pos + 1000, pos + 1000)
	eprintln('placed diodes')
	// test if they are diodes, with the right orientation

	app.update_cycle()
	app.update_cycle()
	x_err, y_err, str_err = app.test_validity(pos, pos, pos + 1000, pos + 1000, true, false)
	eprintln('tested diodes')
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}
	app.removal(pos, pos, pos + 1000, pos + 1000)
	eprintln('removed diodes')

	app.selected_item = .crossing
	app.placement(pos, pos, pos + 1000, pos + 1000)
	eprintln('placed crossings')
	// test if they are crossings, with the right orientation

	app.update_cycle()
	app.update_cycle()
	x_err, y_err, str_err = app.test_validity(pos, pos, pos + 1000, pos + 1000, true, false)
	eprintln('tested crossings')
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}
	app.removal(pos, pos, pos + 1000, pos + 1000)
	eprintln('removed crossings')

	app.selected_item = .on
	app.placement(pos, pos, pos + 1000, pos + 1000)
	eprintln('placed ons')
	// test if they are ons, with the right orientation

	app.update_cycle()
	app.update_cycle()
	x_err, y_err, str_err = app.test_validity(pos, pos, pos + 1000, pos + 1000, true, false)
	eprintln('tested ons')
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}
	app.removal(pos, pos, pos + 1000, pos + 1000)
	eprintln('removed ons')
*/
	app.selected_item = .wire
	app.placement(pos, pos, pos + 1000, pos + 1000)
	eprintln('placed wires')
	// test if they are wires, with the right orientation

	app.update_cycle()
	println('tested wires 1/2')
	app.update_cycle()
	println('updated wires 2/2')
	x_err, y_err, str_err = app.test_validity(pos, pos, pos + 1000, pos + 1000, true, true)
	println('tested wires')
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}
	app.removal(pos, pos, pos + 1000, pos + 1000)
	eprintln('removed wires')
	eprintln('Finished test_placement_removal_big')
}
