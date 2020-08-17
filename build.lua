local version = 
{
	major = 1,
	minor = 0,
	revision = 0,
}
local buildFlags = 
{
	help = "--help",
	build = "--build",
	author = "--author",
	projectPath = "--path",
	incrementMajor = "--increment-major",
	incrementMinor = "--increment-minor",
	incrementRevision = "--increment-revision",
}
local buildArgs = 
{
	build = nil,
	author = nil,
	path = nil,
}
local requiredBuildFlags = 
{
	buildFlags.build,
	buildFlags.author,
	buildFlags.projectPath,
}
local buildFlagsValid = true
local requiredBuildFlagsFound = 0
local buildVersionKey = "version"
local buildDateKey = "date"
local buildAuthorKey = "author"
local buildConfFilePath = "data/build.conf"
local date = os.date("*t")
local helpMessage = [[
Welcome to the Solar2DBuilder!
Required flags:
  --build
  --author "author name"
  --path - path to the projects workspace folder
]]
local hasRequestedHelp = false
local buildData, errorString = io.open(buildConfFilePath, "r")

-- parse the args
for i = 1, #arg do
	if (arg[i] == buildFlags.help) then
		hasRequestedHelp = true
		print(helpMessage)
		return
	end

	for j = 1, #requiredBuildFlags do
		if (arg[i] == requiredBuildFlags[j]) then
			requiredBuildFlagsFound = requiredBuildFlagsFound + 1
		end
	end

	if (i + 1 <= #arg) then
		if (arg[i] == buildFlags.author) then
			buildArgs.author = arg[i + 1]
		elseif (arg[i] == buildFlags.projectPath) then
			buildArgs.path = arg[i + 1]
		end
	end

	--print(arg[i])
end

local numArgsValid = (requiredBuildFlagsFound == #requiredBuildFlags)
local authorValid = (buildArgs.author ~= nil)
local pathValid = (buildFlags.projectPath ~= nil)
buildFlagsValid = numArgsValid and authorValid and pathValid

if (hasRequestedHelp) then
	return
end

if (not buildFlagsValid) then
	local errorMessage = nil

	if (not numArgsValid) then
		errorMessage = ("Error: build flag requirements not met. You must specify the following: %s."):format(table.concat(requiredBuildFlags, ", "))
	end

	if (not authorValid) then
		errorMessage = ("Error: author name not provided.")
	end

	if (not pathValid) then
		errorMessage = ("Error: path not provided")
	end

	print(errorMessage)
	return
end

local function parseArg(value, delimiter)
	local workValue = value
	local values = {}

	repeat
		values[#values + 1] = workValue:sub(1, workValue:find(delimiter) - 1)
		workValue = workValue:sub(workValue:find(delimiter) + 1, workValue:len())
	until workValue:find(delimiter) == nil

	if (workValue:len() > 0) then
		values[#values + 1] = workValue
	end

	return values
end

-- generates a makefile for the specified project
local function generateMakefile(projectName)
	local verbose = true
	print(("Generating makefile for: %s"):format(projectName))
	os.execute(('codelite-make -w %s/Solar2DTux.workspace -p %s -d clean -c Release -e %s'):format(buildArgs.path, projectName, verbose and "-v" or ""))
	print("-----------------------------------------------------------------------")
end

if (buildData) then
	local buildVersion = nil
	local buildAuthor = nil
	local buildDate = nil

	for line in io.lines(buildConfFilePath) do
		if (line:find(buildVersionKey) ~= nil) then
			buildVersion = line:sub(buildVersionKey:len() + 2)
		elseif (line:find(buildAuthorKey) ~= nil) then
			buildAuthor = line:sub(buildAuthorKey:len() + 2)
		elseif (line:find(buildDateKey) ~= nil) then
			buildDate = line:sub(buildDateKey:len() + 2)
		end
	end

	local buildVer = parseArg(buildVersion, "%.")
	local buildDat = parseArg(buildDate, "%.")
	version.major = tonumber(buildVer[1])
	version.minor = tonumber(buildVer[2])
	version.revision = tonumber(buildVer[3])

	print(("build version: %d.%d.%d"):format(version.major, version.minor, version.revision))
	print(("build author: %s"):format(buildAuthor))
	print(("build date: %d/%d/%d"):format(buildDat[1], buildDat[2], buildDat[3]))
else
	buildData = io.open(buildConfFilePath, "w")

	local buildVersionDefault = ("%s=%d.%d.%d\n"):format(buildVersionKey, version.major, version.minor, version.revision)
	local buildDate = ("%s=%d.%d.%d\n"):format(buildDateKey, date.year, date.month, date.day)
	local buildAuthor = ("%s=%s\n"):format(buildAuthorKey, buildArgs.author)
	buildData:write(buildVersionDefault)
	buildData:write(buildDate)
	buildData:write(buildAuthor)
	buildData:close()
end

-- generate makefiles for each project
generateMakefile("car")
generateMakefile("Solar2DBuilder")
generateMakefile("Solar2DTuxConsole")
generateMakefile("Solar2DSimulator")

