module main

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
/*
fn test_placement_removal_big() {
	mut app := App{}
	defer {
		app.comp_running = false
		for app.comp_alive {}
	}
	name := 'test'
	app.text_input = name
	app.create_game()
	mut pos := u32(2_000)

	app.selected_item = .not
	app.todo << TodoInfo{.place, pos, pos, pos + 1000, pos + 1000, ''}
	// test if they are nots, with the right orientation

	for app.todo.len > 0 {}
	mut x_err, mut y_err, mut str_err := app.test_validity(pos, pos, pos + 1000, pos + 1000)
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}
	app.todo << TodoInfo{.removal, pos, pos, pos + 1000, pos + 1000, ''}	

	app.selected_item = .diode
	app.todo << TodoInfo{.place, pos, pos, pos + 1000, pos + 1000, ''}
	// test if they are nots, with the right orientation

	for app.todo.len > 0 {}
	x_err, y_err, str_err = app.test_validity(pos, pos, pos + 1000, pos + 1000)
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}
	app.todo << TodoInfo{.removal, pos, pos, pos + 1000, pos + 1000, ''}	

	app.selected_item = .crossing
	app.todo << TodoInfo{.place, pos, pos, pos + 1000, pos + 1000, ''}
	// test if they are nots, with the right orientation

	for app.todo.len > 0 {}
	x_err, y_err, str_err = app.test_validity(pos, pos, pos + 1000, pos + 1000)
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}
	app.todo << TodoInfo{.removal, pos, pos, pos + 1000, pos + 1000, ''}	

	app.selected_item = .on
	app.todo << TodoInfo{.place, pos, pos, pos + 1000, pos + 1000, ''}
	// test if they are nots, with the right orientation

	for app.todo.len > 0 {}
	x_err, y_err, str_err = app.test_validity(pos, pos, pos + 1000, pos + 1000)
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}
	app.todo << TodoInfo{.removal, pos, pos, pos + 1000, pos + 1000, ''}	

	app.selected_item = .wire
	app.todo << TodoInfo{.place, pos, pos, pos + 1000, pos + 1000, ''}
	// test if they are nots, with the right orientation

	for app.todo.len > 0 {}
	x_err, y_err, str_err = app.test_validity(pos, pos, pos + 1000, pos + 1000)
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}
	app.todo << TodoInfo{.removal, pos, pos, pos + 1000, pos + 1000, ''}	
	for app.todo.len > 0 {}
}
*/
fn test_placement_small() {
	mut app := App{}
	defer {
		app.comp_running = false
		for app.comp_alive {}
	}
	app.nb_updates = 10000000
	name := 'test'
	app.text_input = name
	app.create_game()
	mut pos := u32(2_000_000_000)

	app.selected_item = .not
	app.todo << TodoInfo{.place, pos, pos, pos, pos + 100, ''}
	app.todo << TodoInfo{.place, pos, pos, pos + 100, pos, ''}
	// test if they are nots, with the right orientation

	pos += 1
	app.selected_item = .diode
	app.todo << TodoInfo{.place, pos, pos, pos, pos + 100, ''}
	app.todo << TodoInfo{.place, pos, pos, pos + 100, pos, ''}
	// todo: check if well placed

	pos += 1
	app.selected_item = .crossing
	app.todo << TodoInfo{.place, pos, pos, pos, pos + 100, ''}
	app.todo << TodoInfo{.place, pos, pos, pos + 100, pos, ''}
	// todo: check if well placed

	pos += 1
	app.selected_item = .wire
	app.todo << TodoInfo{.place, pos, pos, pos, pos + 100, ''}
	app.todo << TodoInfo{.place, pos, pos, pos + 100, pos, ''}
	// todo: check if well placed

	pos += 1
	app.selected_item = .on
	app.todo << TodoInfo{.place, pos, pos, pos, pos + 100, ''}
	app.todo << TodoInfo{.place, pos, pos, pos + 100, pos, ''}
	// todo: check if well placed

	for app.todo.len > 0 {}
	mut x_err, mut y_err, mut str_err := app.test_validity(pos, pos, pos + 100, pos + 100)
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}

	pos += 1
	app.todo << TodoInfo{.place, pos, pos, pos, pos + 100, ''}
	app.todo << TodoInfo{.place, pos, pos, pos + 100, pos, ''}
	// todo: check if well placed

	for app.todo.len > 0 {}
	x_err, y_err, str_err = app.test_validity(pos, pos, pos + 100, pos + 100)
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}

	pos += 1
	app.selected_item = .diode
	app.todo << TodoInfo{.place, pos, pos, pos, pos + 100, ''}
	app.todo << TodoInfo{.place, pos, pos, pos + 100, pos, ''}
	// todo: check if well placed

	for app.todo.len > 0 {}
	x_err, y_err, str_err = app.test_validity(pos, pos, pos + 100, pos + 100)
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}

	pos += 1
	app.selected_item = .crossing
	app.todo << TodoInfo{.place, pos, pos, pos, pos + 100, ''}
	app.todo << TodoInfo{.place, pos, pos, pos + 100, pos, ''}
	// todo: check if well placed

	for app.todo.len > 0 {}
	x_err, y_err, str_err = app.test_validity(pos, pos, pos + 100, pos + 100)
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}

	pos += 1
	app.selected_item = .wire
	app.todo << TodoInfo{.place, pos, pos, pos, pos + 100, ''}
	app.todo << TodoInfo{.place, pos, pos, pos + 100, pos, ''}
	// todo: check if well placed

	for app.todo.len > 0 {}
	x_err, y_err, str_err = app.test_validity(pos, pos, pos + 100, pos + 100)
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}

	pos += 1
	app.selected_item = .on
	app.todo << TodoInfo{.place, pos, pos, pos, pos + 100, ''}
	app.todo << TodoInfo{.place, pos, pos, pos + 100, pos, ''}
	// todo: check if well placed

	for app.todo.len > 0 {}
	x_err, y_err, str_err = app.test_validity(pos, pos, pos + 100, pos + 100)
	if str_err != '' {
		panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
	}
}
