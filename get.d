import std.stdio;
import std.string;
import std.array;
import std.file;
import std.path;
import std.process;

import globals;


string[string] hostingsites;

static this() {
	hostingsites = ["github.com":"https://$1.git"];
}

void getpackage(string name) {
	auto package_dir = dpath[0]~dirSeparator~SOURCE_DIR~dirSeparator~name;
	if (!exists(package_dir)) {
		mkdirRecurse(package_dir);
	}
	chdir(package_dir);
	writeln(getcwd());
	auto domain = name[0..name.indexOf("/")];
	auto url = hostingsites[domain].replace("$1", name);
	writeln("Fetching: ", url);
	shell("git clone "~ url ~" ."); // . at end places files directly in current directory
}