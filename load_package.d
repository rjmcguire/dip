import std.stdio;
import std.file;
import std.string;
import std.process;
import std.path;
import std.algorithm : canFind;
import resolve_dep;

string droot="/usr/local/d"; // D installation directory
string[] dpath=[]; // list of directories to look for libraries and source files for D

string package_dir; // package we're working on, normally the current working directory

const SOURCE_DIR = "src"; // TODO: how will we handle libraries where we only have .di files and the compiled library
const LIBRARY_DIR = "lib";
const BIN_DIR = "bin";

static this() {
	auto dpath_tmp = getenv("DPATH");
	if (dpath_tmp=="") {
		writeln("WARNING DPATH NOT SET, suggest DPATH=\"~/d/"~pathSeparator~droot~"\"");
	} else {
		dpath = dpath_tmp.split(pathSeparator);
	}

	// allow override of D's installation directory
	auto droot_env = getenv("DROOT");
	if (droot_env!="") {
		droot = droot_env;
	}

	if (!dpath.canFind(droot))
		dpath ~= droot;
}

// Load environment variables at start up.
void init() {
	if (package_dir==null)
		package_dir = getcwd();

	// set up search path for D files
	load_parent_dir_dpaths();
	name = package_dir;
	name = name[name.lastIndexOf(dirSeparator)+1..$];

	load_package_details();
}

void print_package_details() {
	writefln("Package: %s[%s]", name, version_str);
	writefln("Dependencies: ");
	foreach (dep; dependencies) {
		writefln("\t%s[%s]: %s", dep.name, dep.version_str, (dep.linkonly?"-L-l"~dep.name:package_dependency_dir(dep.name)));
	}
}


string name, version_str;
Dependency[] dependencies;
bool is_library = false;
string[] flags;

void load_package_details() {
	const VERSION_MARKER="*Version:*";
	const NAME_MARKER="# ";
	const DEPENDENCY_MARKER="## Dependencies:";
	const FLAGS_MARKER="## Flags:";

	auto f = new File(package_dir ~dirSeparator~"README.md");

	uint i=0;
	bool in_dependencies = false;
	bool in_flags = false;
	foreach (char[] line; f.byLine()) {
		if (i==0) {
			if (line.length<3 || !line.startsWith(NAME_MARKER)) {
				throw new Exception("Error: package has invalid name in README.md. Should start with #");
			} else {
				auto idx = line.indexOf("-");
				if (idx== -1)
					idx=line.length;

				auto n = strip(line[1..idx]);
				if (n!=name) {
					writeln(n, name);
					throw new Exception("Package name does not match name in README.md");
				}
			}
		}
		i++;

		if (line.startsWith(DEPENDENCY_MARKER)) {
			in_dependencies = true;
			continue;
		}
		if (in_dependencies) {
			if (line.length<1) {
				in_dependencies = false;
				continue;
			}
			if (!line.startsWith(" * ")) {
				throw new Exception("Dependency list invalid, correct format is: \"* name: version\". list ends with blank line.");
			}
			line = line[" * ".length..$];


			if (line.startsWith("link ")) {
				line = line["link ".length..$];
				auto idx = line.indexOf("-");
				if (idx==-1) {
					throw new Exception("Dependency list invalid, correct format is: link name - description. list ends with blank line.");
				}
				dependencies ~= Dependency(strip(line[0..idx]).idup, strip(line[idx+1..$]).idup, true);
			} else {
				auto idx = line.indexOf(":");
				if (idx==-1) {
					throw new Exception("Dependency list invalid, correct format is:\" * name: version\". list ends with blank line.");
				}
				dependencies ~= Dependency(strip(line[0..idx]).idup, strip(line[idx+1..$]).idup);
			}
		}

		if (line.startsWith(FLAGS_MARKER)) {
			in_flags = true;
			continue;
		}
		if (in_flags) {
			if (line.length<1) {
				in_flags = false;
				continue;
			}
			if (!line.startsWith(" * ")) {
				writeln("line is!!!!", line);
				throw new Exception("Invalid flag, flag format is:\" * someflag - description\"");
			}
			line = line[" * ".length..$];
			if (line.strip()=="Library") {
				is_library = true;
			} else {
				auto idx = line.lastIndexOf(" - ");
				if (idx>0) {
					line = line[0..idx];
				}
				flags ~= line.idup;
			}
			continue;
		}

		if (version_str==null && line.length>VERSION_MARKER.length && line[0..VERSION_MARKER.length]==VERSION_MARKER) {
			version_str = strip(line[VERSION_MARKER.length..$]).idup;
		}
	}
}

void load_parent_dir_dpaths() {
	string[] newdpath = [];
	auto cwd = package_dir;
	for (;cwd.lastIndexOf(dirSeparator)>0;cwd = cwd[0..cwd.lastIndexOf(dirSeparator)]) {
		auto entries = dirEntries(cwd, SpanMode.shallow);
		foreach (dir; entries) {
			if (!isDir(dir)) continue;
			if (dir.lastIndexOf(dirSeparator)<=0) continue;
			if (dir[dir.lastIndexOf(dirSeparator)+1..$]==".dpath") {
				newdpath ~= dir;
			}
		}
	}
	foreach (p; dpath) {
		newdpath ~= p;
	}
	dpath = newdpath;
}

struct Dependency {
	string name,version_str;
	bool linkonly;
}