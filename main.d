module dip;

import std.stdio;
import std.file;
import std.getopt;


import build;
import resolve_dep;
import globals;
import get;

void main(string[] args) {
	getopt(args, std.getopt.config.passThrough
		, "verbose|v", &verbose
		, "vverbose|vv", &vverbose
		, "install|i", &install
		, "listdependencies|l", &listdependencies);

	auto package_dir = getcwd();

	string command = "build";
	if (args.length==3) {
		command = args[1];
		args[1..$-1] = args[2..$];
	}
	switch (command) {
		case "get":
			getpackage(args[2]);
			break;
		case "build":
			if (args.length>1) {
				package_dir = package_search(args[1]);
			}
			build_package(package_dir);
		case "install":
			install = true;
			break;
		default:
			writeln("command unknown");
	}
}

