module main

fn test_save() {
	mut app := App{}
	name := 'test'
	app.text_input = name
	app.create_game()
	pos := u32(2_000_000_000)
	app.placement(pos, pos, pos + 100, pos + 100) /// need to separate backend / frontend
	app.quit_map()
}
