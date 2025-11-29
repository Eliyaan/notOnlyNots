import os

build_dir := 'build_dir'
linux_dir := build_dir + '/linux'
exec_name_linux := 'not_gates'
windows_dir := build_dir + '/windows'
exec_name_windows := 'not_gates.exe'

if os.exists(build_dir) {
	os.rmdir_all(build_dir)!
}
os.mkdir(build_dir)!
// linux
os.mkdir(linux_dir)!
os.mkdir(linux_dir + '/player_data')!
os.cp('player_data/palette.toml', linux_dir + '/player_data/palette.toml')!
os.cp_all('game_data', linux_dir + '/game_data', true)!
println(os.execute('v -prod -no-bounds-checking -o ${linux_dir}/${exec_name_linux} .'))
// windows
os.mkdir(windows_dir)!
os.mkdir(windows_dir + '/player_data')!
os.cp('player_data/palette.toml', windows_dir + '/player_data/palette.toml')!
os.cp_all('game_data', windows_dir + '/game_data', true)!
println(os.execute('v -os windows -prod -no-bounds-checking -o ${windows_dir}/${exec_name_windows} .'))
