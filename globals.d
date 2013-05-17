bool verbose = false;
bool vverbose = false;
bool install = false;
bool listdependencies = false;

string droot="/usr/local/d"; // D installation directory
string[] dpath=[]; // list of directories to look for libraries and source files for D

const SOURCE_DIR = "src"; // TODO: how will we handle libraries where we only have .di files and the compiled library
const LIBRARY_DIR = "lib";
const BIN_DIR = "bin";

