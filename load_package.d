import std.stdio;
import std.file;
import std.string;
import std.process;
import std.path;
import std.algorithm : canFind;

import globals;
import resolve_dep;

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
Package init(string dir) {
	// set up search path for D files
	load_parent_dir_dpaths(dir);

	return load_package_details(dir);
}

Package load_package_details(string dir) {
	const VERSION_MARKER="*Version:*";
	const NAME_MARKER="# ";
	const DEPENDENCY_MARKER="## Dependencies:";
	const FLAGS_MARKER="## Flags:";
	const SKIP_FILES_MARKER="## Skip D Files:";

	Package ret;
	ret.dir = dir;
	ret.name = ret.dir[ret.dir.lastIndexOf(dirSeparator)+1..$];

	auto f = new File(ret.dir ~dirSeparator~"README.md");

	uint i=0;
	bool in_dependencies = false;
	bool in_flags = false;
	bool in_skip_files = false;
	foreach (char[] line; f.byLine()) {
		if (i==0) {
			if (line.length<3 || !line.startsWith(NAME_MARKER)) {
				throw new Exception("Error: package has invalid name in README.md. Should start with #");
			} else {
				auto idx = line.indexOf("-");
				if (idx== -1)
					idx=line.length;

				auto n = strip(line[1..idx]);
				if (n!=ret.name) {
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
				ret.dependencies ~= Dependency(strip(line[0..idx]).idup, strip(line[idx+1..$]).idup, true);
			} else {
				auto idx = line.indexOf(":");
				if (idx==-1) {
					throw new Exception("Dependency list invalid, correct format is:\" * name: version\". list ends with blank line.");
				}
				ret.dependencies ~= Dependency(strip(line[0..idx]).idup, strip(line[idx+1..$]).idup);
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
				ret.isLibrary = true;
			} else {
				auto idx = line.lastIndexOf(" - ");
				if (idx>0) {
					line = line[0..idx];
				}
				ret.flags ~= line.idup;
			}
			continue;
		}

		if (line.startsWith(SKIP_FILES_MARKER)) {
			in_skip_files = true;
			continue;
		}
		if (in_skip_files) {
			if (line.length<1) {
				in_skip_files = false;
				continue;
			}
			ret.skipDFiles ~= line.strip().idup;
		}

		if (ret.version_str==null && line.length>VERSION_MARKER.length && line[0..VERSION_MARKER.length]==VERSION_MARKER) {
			ret.version_str = strip(line[VERSION_MARKER.length..$]).idup;
		}
	}
	return ret;
}

void load_parent_dir_dpaths(string dir) {
	string[] newdpath = [];
	for (;dir.lastIndexOf(dirSeparator)>0;dir = dir[0..dir.lastIndexOf(dirSeparator)]) {
		auto entries = dirEntries(dir, SpanMode.shallow);
		foreach (dir1; entries) {
			if (!isDir(dir1)) continue;
			if (dir1.lastIndexOf(dirSeparator)<=0) continue;
			if (dir1[dir1.lastIndexOf(dirSeparator)+1..$]==".dpath") {
				newdpath ~= dir1;
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

struct Package {
	bool isLibrary = false;
	string name;
	string version_str;
	Dependency[] dependencies;
	string[] flags;
	string dir;
	string[] skipDFiles;
	bool isDubPackage;

	void print_details() {
		writefln("Package: %s[%s]", this.name, this.version_str);
		writefln("Dependencies: ");
		foreach (dep; this.dependencies) {
			string dirfound = "Not Found";
			try {
				package_dependency_dir(dep.name);
				dirfound = "Found";
			} catch (Exception e) {
			}
			writefln("\t%s[%s]: %s", dep.name, dep.version_str, (dep.linkonly?"-l"~dep.name:dirfound));
		}
	}
	// get all files in current directory
	string[] get_dfiles() {
		return get_dfiles(this.dir);
	}
	string[] get_dfiles(string dir) {
		string[] dfiles = [];
		auto entries = dirEntries(dir, SpanMode.shallow);
		foreach (entry;  entries) {
			if (isDir(entry))
				dfiles ~= this.get_dfiles(entry);
			if (entry.name=="." || entry.name==".." || !entry.name.endsWith(".d"))
				continue;

			dfiles ~= entry.name;
		}
		return dfiles;
	}
}
