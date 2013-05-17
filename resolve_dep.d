import load_package;

import std.stdio;
import std.file;

/** For a particular dependency find the correct root path for it
	WARN: Do not use this to build dependencies and things, its just informational.
		  When encountering a packages dependency we should run dip with the dependency as
		  its argument. dip will sort out the rest.
 **/
string package_dependency_dir(string dependency) {
	return package_search(dependency);
}

string package_search(string package_str) {
	foreach (dir; dpath) {
		auto tmp = dir ~"/src/"~ package_str;
		if (exists(tmp)) {
			return tmp;
		}
	}
	throw new Exception("Dependency not found: "~ package_str);
}
