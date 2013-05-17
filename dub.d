import std.file;
import std.json;
import std.stdio;
import std.path;
import std.process;

import load_package;
import globals;

bool getDubPackage(Package* p) {
	if (exists("package.json") && exists("./source")) {
		loadDubPackage(p);
		return true;
	}
	return false;
}

void loadDubPackage(Package* p) {
	auto t = readText("package.json");
	auto json = parseJSON(t);
	p.name = json["name"].str;
	p.isDubPackage = true;
	//p.isLibrary = json[""];
	try {
		if (json["version"].type == JSON_TYPE.STRING)
			p.version_str = json["version"].str;
	} catch (Exception e) {}
	if (json["configurations"].type==JSON_TYPE.ARRAY) {
		foreach (v; json["configurations"].array) {
			if (v.type==JSON_TYPE.OBJECT) {
				try {
					if (v["name"].str=="library") {
						p.isLibrary = true;
					}
				} catch (Exception e) {}
				try {
					if (v["excludedSourceFiles"].type==JSON_TYPE.ARRAY) {
						foreach (f; v["excludedSourceFiles"].array) {
							p.skipDFiles ~= f.str;
						}
					}
				} catch (Exception e) {}
			}
		}
	}

	try {
		if (json["dip-dependencies"].type==JSON_TYPE.OBJECT) {
			foreach (k,v; json["dip-dependencies"].object) {
				p.dependencies ~= Dependency(k, v.str);
			}
		}
	} finally {}
}

void buildDubPackage(Package p) {
	assert(p.isDubPackage);
	if (auto ret = shell("dub build")) {
		writeln(ret);
	}
}
