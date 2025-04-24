module main 
import time 

fn test_save() {
	mut app := App{}
	name := 'test'
	app.text_input = name
	app.create_game()
	app.selected_item = .crossing
	pos := u32(2_000_000_000)
	app.placement(pos, pos, pos + 100, pos + 100)
	mut i := u32(1)
	app.placement(pos + i, pos + i, pos + i + 100, pos + i + 100)
	i++
	app.placement(pos + i, pos + i, pos + i + 100, pos + i + 100)
	i++
	app.placement(pos + i, pos + i, pos + i + 100, pos + i + 100)
	i++
	app.placement(pos + i, pos + i, pos + i + 100, pos + i + 100)
	i++
	app.placement(pos + i, pos + i, pos + i + 100, pos + i + 100)
	i++
	app.placement(pos + i, pos + i, pos + i + 100, pos + i + 100)
	i++
	app.placement(pos + i, pos + i, pos + i + 100, pos + i + 100)
	i++
	time.sleep(time.second)
	app.quit_map()
	time.sleep(time.second)
	app.load_saved_game(name)
	time.sleep(time.second)
	app.quit_map()
	time.sleep(time.second)
	app.load_saved_game(name)
	time.sleep(time.second)
	app.quit_map()
	time.sleep(time.second)
	app.load_saved_game(name)
}
