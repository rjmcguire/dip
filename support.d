/** Support functions **/
import std.file;
import load_package;
import std.string;

// get all files in current directory
string[] get_dfiles(string dir) {
	string[] dfiles = [];
	auto entries = dirEntries(dir, SpanMode.shallow);
	foreach (entry;  entries) {
		if (isDir(entry))
			dfiles ~= get_dfiles(entry);
		if (entry.name=="." || entry.name==".." || !entry.name.endsWith(".d"))
			continue;

		dfiles ~= entry.name;
	}
	return dfiles;
}
