module dip;

import std.stdio;
import std.array;
import std.string;
import std.process;
import std.getopt;
import std.path;
import std.file;


import load_package;
import support;
import resolve_dep;

bool verbose = false;
bool vverbose = false;
bool install = false;

void main(string[] args) {
	getopt(args, std.getopt.config.passThrough
		, "verbose|v", &verbose
		, "vverbose|vv", &vverbose
		, "install|i", &install);


	if (args.length>1) {
		package_dir = package_search(args[1]);
		writeln("package_dir is: ", package_dir);
	}

	build_package(args[0]);
}

void build_package(string command_line_name) {
	init();

	if (vverbose) {
		writeln("** ENV **");
		writeln("DROOT:", droot);
		writeln("DPATH - D Package Search PATH:");
		foreach (path; dpath) {
			writeln("\t", path);
		}
		writeln("** END ENV **");
	}

	if (verbose) print_package_details();

	// process dependencies first
	auto dependency_args = check_dependencies(command_line_name);

	string[] dfiles = get_dfiles(package_dir);
	if (dfiles.length<1) {
		writeln("No d files in ", package_dir);
		return;
	}

	string command;
	if (is_library) {
		// compile lib
		command = droot~"/bin/dmd -c "~ flags.join(" ") ~" -lib  -of"~ package_dir~"/"~name ~".a -od"~ package_dir ~dependency_args ~" "~ dfiles.join(" ");
		if (vverbose) writeln("Executing: ", command);
		auto compile_success = system(command)==0 ? true: false;

		if (compile_success && install) {
			// install lib
			shell("mv "~ name ~" "~ dpath[0]~"/lib/");
		} else {
			writeln("Compile Failed");
		}
	} else {
		auto filename = "dip_tmpfile.o";
		if (exists(filename)) {
			std.file.remove(filename);
		}
		scope(exit) { if (exists(filename)) { std.file.remove(filename);}}

		// compile
		command = droot~"/bin/dmd -c -of"~ filename ~" -od"~ package_dir ~dependency_args ~" "~ dfiles.join(" ");
		if (vverbose) writeln("Executing: ", command);
		auto compile_success = system(command)==0 ? true : false;

		// link
		if (compile_success) {
			command = "/usr/bin/gcc -o"~package_dir~"/"~name ~" "~filename ~" "~  flags.join(" ");
			if (vverbose) writeln("Executing: ", command);
			auto link_success = system(command)==0 ? true : false;

			// install to d bin directory
			if (link_success) {
				if (install) {
					shell("mv "~ name ~" "~ dpath[0]~"/bin/");
				}
			} else {
				writeln("Linking failed: ", command);
			}
		} else {
			writeln("Compile failed");
		}
	}
}

/** returns additional command line arguments for dmd **/
string check_dependencies(string progname) {
	string str="";
	foreach (dep; dependencies) {
		if (dep.linkonly) {
			str ~= " -l";
			str ~= dep.name;
			continue;
		}

		auto command = progname ~ (verbose?" -v":"")~(vverbose?" -vv":"") ~" "~ dep.name;
		if (vverbose)writeln("running: ", command);

		system(command);

		str ~= " -I";
		str ~= package_search(dep.name);
	}
	return str;
}