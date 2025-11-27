import os

build_dir := 'build_dir'

if !os.exists(build_dir) {
	os.mkdir(build_dir)!
}
os.cp_all('game_data', build_dir + '/game_data', true)!
exec_name := 'not_gates.exe'
println(os.execute('v -prod -no-bounds-checking -o ${build_dir}/${exec_name} .'))
