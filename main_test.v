module main

fn test_save() {
	mut app := App{}
	name := 'test'
	app.create_game()
	pos := u32(2_000_000_000)
	app.placement()
	app.todo << TodoInfo{name}
	for app.comp_running {}
}
