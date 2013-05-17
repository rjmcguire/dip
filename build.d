import std.stdio;
import load_package;
import resolve_dep;
import std.array;
import std.string;
import std.process;
import std.path;
import std.file;

import globals;
import dub;

bool listdeps_heading = true;

DepArgs build_package(string dir, string tabs="") {
	if (verbose) writeln("build package in: ", dir);
	auto curdir = getcwd();
	chdir(dir);
	scope(exit) chdir(curdir);

	Package p;
	if (getDubPackage(&p)) {
		writeln("package is:", p);
	} else {
		p = init(dir);
	}

	if (vverbose) {
		writeln("** ENV **");
		writeln("DROOT:", droot);
		writeln("DPATH - D Package Search PATH:");
		foreach (path; dpath) {
			writeln("\t", path);
		}
		writeln("** END ENV **");
	}

	if (verbose) p.print_details();

	// process dependencies first
	if (listdependencies && listdeps_heading) { writeln("Listing dependencies:"); listdeps_heading=false; }
	auto depargs = check_dependencies(p, tabs);
	depargs.isLibrary = p.isLibrary;
	if (p.isDubPackage) {
		if (verbose) {
			writeln("build dub package");
		}
		buildDubPackage(p);
		return depargs;
	}
	if (listdependencies) return depargs;

	string[] dfiles = p.get_dfiles();

	// skip files as declared in package
	foreach (i,fname; dfiles) {
		foreach (sfname; p.skipDFiles) {
			if (dir~dirSeparator~sfname==fname) {
				dfiles[i] = "";
			}
		}
	}

	if (dfiles.length<1) {
		writeln("No d files in ", p.dir);
		return depargs;
	}

	string command;
	depargs.output_filename = p.dir~"/"~p.name;
	if (p.isLibrary) {
		depargs.output_filename ~=  ".a";
		// compile lib
		command = droot~"/bin/dmd -c "~ p.flags.join(" ") ~" -lib  -of"~ depargs.output_filename ~" -od"~ p.dir ~depargs.compileargs ~" "~ dfiles.join(" ");
		if (vverbose) writeln("Executing: ", command);
		auto compile_success = system(command)==0 ? true: false;

		if (compile_success) {
			// install lib
			if (install) shell("mv "~ depargs.output_filename ~" "~ dpath[0]~"/lib/");
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
		command = droot~"/bin/dmd -c -of"~ filename ~" -od"~ p.dir ~depargs.compileargs ~" "~ dfiles.join(" ");
		if (vverbose) writeln("Executing: ", command);
		auto compile_success = system(command)==0 ? true : false;

		// link
		if (compile_success) {
			command = "/usr/bin/gcc -o"~ depargs.output_filename ~" "~filename ~depargs.linkargs ~" "~  p.flags.join(" ");
			if (vverbose) writeln("Executing: ", command);
			auto link_success = system(command)==0 ? true : false;

			// install to d bin directory
			if (link_success) {
				if (install) {
					if (verbose) writeln("Executing: strip "~ depargs.output_filename);
					shell("strip "~ depargs.output_filename);
					if (verbose) writeln("Executing: mv "~ depargs.output_filename ~" "~ dpath[0]~"/bin/");
					shell("mv "~ depargs.output_filename ~" "~ dpath[0]~"/bin/");
				}
			} else {
				writeln("Linking failed: ", command);
			}
		} else {
			writeln("Compile failed");
		}
	}
	return depargs;
}

/** returns additional command line arguments for dmd **/
DepArgs check_dependencies(Package p, string tabs) {
	DepArgs ret;
	foreach (dep; p.dependencies) {
		if (dep.linkonly) {
			ret.linkargs ~= " -l";
			ret.linkargs ~= dep.name;
			continue;
		}

		if (listdependencies) {
			write(tabs);
			writeln(dep.name);
		}

		auto pdir = package_search(dep.name);
		auto dep_p = build_package(pdir, tabs~"\t");

		ret.compileargs ~= " -I";
		ret.compileargs ~= pdir;
		if (dep_p.isLibrary) {
			ret.linkargs ~= " ";
			ret.linkargs ~= dep_p.output_filename;
			ret.linkargs ~= dep_p.linkargs;
			ret.linkargs ~= " ";
			ret.compileargs ~= dep_p.compileargs;
		}
	}
	return ret;
}


struct DepArgs {
	bool isLibrary;
	string output_filename;
	string compileargs;
	string linkargs;
}
