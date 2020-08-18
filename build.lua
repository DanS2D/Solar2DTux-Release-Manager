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
	release = "--release",
	author = "--author",
	projectPath = "--path",
	incrementMajor = "--increment-major",
	incrementMinor = "--increment-minor",
	incrementRevision = "--increment-revision",
}
local buildArgs = 
{
	build = false,
	release = false,
	author = nil,
	path = nil,
	incrementMajor = false,
	incrementMinor = false,
	incrementRevision = false,
}
local requiredBuildFlags = 
{
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
local currentDate = 
{
	day = nil,
	month = nil,
	year = nil,
}
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
		elseif (arg[i] == buildFlags.build) then
			buildArgs.build = true
		elseif (arg[i] == buildFlags.release) then
			buildArgs.release = true
		elseif (arg[i] == buildFlags.incrementMajor) then
			buildArgs.incrementMajor = true
		elseif (arg[i] == buildFlags.incrementMinor) then
			buildArgs.incrementMinor = true
		elseif (arg[i] == buildFlags.incrementRevision) then
			buildArgs.incrementMinor = true
		end
	end

	--print(arg[i])
end

local numArgsValid = (requiredBuildFlagsFound == #requiredBuildFlags)
local authorValid = (buildArgs.author ~= nil)
local pathValid = (buildFlags.projectPath ~= nil)
buildFlagsValid = numArgsValid and authorValid and pathValid and (buildArgs.build or buildArgs.release)

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

	if (not buildArgs.build and not buildArgs.release) then
		errorMessage = ("Error: you have to specify either --build or --release at a minimum, or both depending on your intent.")
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
local function generateMakefile(projectName, configuration)
	local verbose = true
	local config = configuration ~= nil and configuration or "Release"
	print(("Generating makefile for: %s - with configuration: %s"):format(projectName, config))
	os.execute(('codelite-make -w %s/Solar2DTux.workspace -p %s -d clean -c %s -e %s'):format(buildArgs.path, projectName, config, verbose and "-v" or ""))
	print("-----------------------------------------------------------------------")
end

-- modify a preprocessor
local function modifyPreprocessor(projectName, preprocessorName, origValue, newValue)
	local makefilePath = ("%s/%s.mk"):format(buildArgs.path, projectName)
	local fileLines = {}

	for line in io.lines(makefilePath) do
		local currentLine = line
		local position = currentLine:find(preprocessorName)
		
		if (position ~= nil) then
			currentLine = string.format("%s%s%s", currentLine:sub(1, position + preprocessorName:len() - 1), newValue, currentLine:sub(position + preprocessorName:len() + origValue:len()))
		end

		fileLines[#fileLines + 1] = currentLine
	end

	-- open the makefile
	local makefile = io.open(makefilePath, "w")

	-- overwrite the old makefile with our new values
	for i = 1, #fileLines do
		makefile:write(fileLines[i] .. "\n")
	end

	makefile:close()
end

-- setup build details
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
	currentDate.year = buildDat[1]
	currentDate.month = buildDat[2]
	currentDate.day = buildDat[3]

	if (buildArgs.incrementMajor) then
		version.major = version.major + 1
	end
	
	if (buildArgs.incrementMinor) then
		version.minor = version.minor + 1
	end

	if (buildArgs.incrementRevision) then
		version.revision = version.revision + 1
	end

	print(("build version: %d.%d.%d"):format(version.major, version.minor, version.revision))
	print(("build author: %s"):format(buildAuthor))
	print(("build date: %d/%d/%d"):format(currentDate.year, currentDate.month, currentDate.day))
else
	buildData = io.open(buildConfFilePath, "w")

	local buildVersionDefault = ("%s=%d.%d.%d\n"):format(buildVersionKey, version.major, version.minor, version.revision)
	local buildDate = ("%s=%d.%d.%d\n"):format(buildDateKey, "2020", "05", "01")
	local buildAuthor = ("%s=%s\n"):format(buildAuthorKey, buildArgs.author)
	buildData:write(buildVersionDefault)
	buildData:write(buildDate)
	buildData:write(buildAuthor)
end

-- start setting up the builders
local buildCommand = nil
local makeCommand = "make -j8 -e -f"
local changeDir = ("cd %s/Solar2DSimulator"):format(buildArgs.path)

-- build the projects
if (buildArgs.build) then
	-- pull the latest changes
	buildCommand = ("cd %s && git fetch && git pull"):format(buildArgs.path)
	os.execute(buildCommand)

	-- #### build car #### --
	generateMakefile("car")
	-- build
	buildCommand = ("cd %s && %s %s"):format(buildArgs.path, makeCommand, "car.mk")
	os.execute(buildCommand)
	-- post build
	buildCommand = ("cd %s/build-%s/bin/ && mv car ../../Solar2DSimulator/Resources/"):format(buildArgs.path, "Release")
	os.execute(buildCommand)
	-- cleanup
	buildCommand = ("cd %s && rm -rf build-%s"):format(buildArgs.path, "Release")
	os.execute(buildCommand)

	-- #### build Solar2DBuilder #### --
	generateMakefile("Solar2DBuilder")
	-- build
	buildCommand = ("cd %s && %s %s clean"):format(buildArgs.path, makeCommand, "Solar2DBuilder.mk")
	os.execute(buildCommand)
	buildCommand = ("cd %s && %s %s"):format(buildArgs.path, makeCommand, "Solar2DBuilder.mk")
	os.execute(buildCommand)
	-- post build
	buildCommand = ("cd %s/build-%s/bin/ && mv Solar2DBuilder ../../Solar2DSimulator/"):format(buildArgs.path, "Release")
	os.execute(buildCommand)
	-- cleanup
	buildCommand = ("cd %s && rm -rf build-%s"):format(buildArgs.path, "Release")
	os.execute(buildCommand)

	-- #### build Solar2DConsole #### --
	generateMakefile("Solar2DConsole")
	-- build
	buildCommand = ("cd %s && %s %s clean"):format(buildArgs.path, makeCommand, "Solar2DConsole.mk")
	os.execute(buildCommand)
	buildCommand = ("cd %s && %s %s"):format(buildArgs.path, makeCommand, "Solar2DConsole.mk")
	os.execute(buildCommand)
	-- post build
	buildCommand = ("cd %s/build-%s/bin/ && mv Solar2DConsole ../../Solar2DSimulator/"):format(buildArgs.path, "Release")
	os.execute(buildCommand)
	-- cleanup
	buildCommand = ("cd %s && rm -rf build-%s"):format(buildArgs.path, "Solar2DConsole")
	os.execute(buildCommand)

	-- #### build Solar2DSimulator #### --
	generateMakefile("Solar2DSimulator")
	modifyPreprocessor("Solar2DSimulator", "Rtt_VERSION_MAJOR=", "3", version.major)
	modifyPreprocessor("Solar2DSimulator", "Rtt_VERSION_MINOR=", "0", version.minor)
	modifyPreprocessor("Solar2DSimulator", "Rtt_VERSION_REVISION=", "0", version.revision)
	modifyPreprocessor("Solar2DSimulator", "Rtt_LOCAL_BUILD_REVISION=", "9999", version.revision)
	modifyPreprocessor("Solar2DSimulator", "Rtt_BUILD_YEAR=", "2100", currentDate.year)
	modifyPreprocessor("Solar2DSimulator", "Rtt_BUILD_MONTH=", "1", currentDate.month)
	modifyPreprocessor("Solar2DSimulator", "Rtt_BUILD_DAY=", "1", currentDate.day)
	-- build
	buildCommand = ("cd %s && %s %s clean"):format(buildArgs.path, makeCommand, "Solar2DSimulator.mk")
	os.execute(buildCommand)
	buildCommand = ("cd %s && %s %s"):format(buildArgs.path, makeCommand, "Solar2DSimulator.mk")
	os.execute(buildCommand)
	-- post build
	buildCommand = ("cd %s/build-%s/bin/ && mv Solar2DSimulator ../../Solar2DSimulator/"):format(buildArgs.path, "Release")
	os.execute(buildCommand)
	-- cleanup
	buildCommand = ("cd %s && rm -rf build-%s"):format(buildArgs.path, "Release")
	os.execute(buildCommand)

	-- #### build x64 Template #### --
	generateMakefile("Solar2DSimulator", "x64Template")
	modifyPreprocessor("Solar2DSimulator", "Rtt_VERSION_MAJOR=", "3", version.major)
	modifyPreprocessor("Solar2DSimulator", "Rtt_VERSION_MINOR=", "0", version.minor)
	modifyPreprocessor("Solar2DSimulator", "Rtt_VERSION_REVISION=", "0", version.revision)
	modifyPreprocessor("Solar2DSimulator", "Rtt_LOCAL_BUILD_REVISION=", "9999", version.revision)
	modifyPreprocessor("Solar2DSimulator", "Rtt_BUILD_YEAR=", "2100", currentDate.year)
	modifyPreprocessor("Solar2DSimulator", "Rtt_BUILD_MONTH=", "1", currentDate.month)
	modifyPreprocessor("Solar2DSimulator", "Rtt_BUILD_DAY=", "1", currentDate.day)
	-- build
	buildCommand = ("cd %s && %s %s clean"):format(buildArgs.path, makeCommand, "Solar2DSimulator.mk")
	os.execute(buildCommand)
	buildCommand = ("cd %s && %s %s"):format(buildArgs.path, makeCommand, "Solar2DSimulator.mk")
	os.execute(buildCommand)
	-- post build
	buildCommand = ("cd %s/build-%s/bin/ && mv Solar2DSimulator template_x64"):format(buildArgs.path, "x64Template")
	os.execute(buildCommand)
	buildCommand = ("cd %s/build-%s/bin/ && tar -czf template_x64.tgz template_x64 && mv template_x64.tgz ../../Solar2DSimulator/Resources/"):format(buildArgs.path, "x64Template")
	os.execute(buildCommand)
	-- cleanup
	buildCommand = ("cd %s && rm -rf build-%s"):format(buildArgs.path, "x64Template")
	os.execute(buildCommand)

	-- #### setup distribution archive #### --
	local releaseFiles = 
	{
		{file = "Solar2DSimulator"},
		{file = "Solar2DConsole"},
		{file = "Solar2DBuilder"},
		{file = "install.sh"},
		{file = "start.sh"},
		{file = "Resources", isDirectory = true}
	}
	-- remove the release directory
	os.execute(("%s && rm -rf Solar2DTux"):format(changeDir))
	-- remove the release file
	os.execute(("%s && rm -rf Solar2DTux_*.tgz"):format(changeDir))
	-- make a directory to house the release files
	os.execute(("%s && mkdir Solar2DTux"):format(changeDir))
	-- copy the required files into the release directory
	for i = 1, #releaseFiles do
		os.execute(("%s && cp %s %s Solar2DTux"):format(changeDir, releaseFiles[i].isDirectory and "-R" or "", releaseFiles[i].file))
	end
	-- tar gz up the release directory, suffixed with the release number
	os.execute(("%s && tar -czf Solar2DTux_%s.%s.%s.tgz Solar2DTux"):format(changeDir, version.major, version.minor, version.revision))
	-- remove the release directory
	os.execute(("%s && rm -rf Solar2DTux"):format(changeDir))
	-- all done!
	print(("Completed building Solar2DTux version %s.%s.%s for release!"):format(version.major, version.minor, version.revision))
end

-- now push the release to GitHub
if (buildArgs.release) then
	-- generate a changelog between the last release and this one
	os.execute(('%s'):format(changeDir) .. (' && git log --format=%B') .. (' --since="%s" --author="Danny Glover|Rob Craig" --no-merges --all > %s/Solar2DSimulator/changelog.txt'):format(("%s-%s-%s"):format(currentDate.year, currentDate.month, currentDate.day), buildArgs.path))
	-- open & read the changelog
	local changelog = io.open(buildArgs.path .. "/Solar2DSimulator/changelog.txt", "r"):read("*a")
	changelog = string.gsub(changelog, "[\"`]", "\\%1")

	-- create and push tags
	os.execute(("%s && git tag v%s.%s.%s"):format(changeDir, version.major, version.minor, version.revision))
	os.execute(("%s && git push --tags"):format(changeDir))
	-- create the release
	os.execute(('%s && ./github-release release --security-token 9bab8a57e7d386d9e826453c6e3c5a150b4da02d --user DannyGlover --repo Solar2DTux --tag v%s.%s.%s --description "%s"'):format(changeDir, version.major, version.minor, version.revision, changelog))
	-- upload the release artifact
	os.execute(('%s && ./github-release upload --security-token 9bab8a57e7d386d9e826453c6e3c5a150b4da02d --user DannyGlover --repo Solar2DTux --tag v%s.%s.%s --name "Solar2DTux-v%s.%s.%s.tgz" --file Solar2DTux_%s.%s.%s.tgz'):format(changeDir, version.major, version.minor, version.revision, version.major, version.minor, version.revision, version.major, version.minor, version.revision))
	-- remove the release file
	os.execute(("%s && rm Solar2DTux_%s.%s.%s.tgz"):format(changeDir, version.major, version.minor, version.revision))
	-- remove the changelog
	os.execute(("%s && rm changelog.txt"):format(changeDir))
	-- update the details
	local buildVersion = ("%s=%d.%d.%d\n"):format(buildVersionKey, version.major, version.minor, version.revision)
	local buildDate = ("%s=%d.%d.%d\n"):format(buildDateKey, date.year, date.month, date.day)
	local buildAuthor = ("%s=%s\n"):format(buildAuthorKey, buildArgs.author)
	buildData = io.open(buildConfFilePath, "w")
	buildData:write(buildVersion)
	buildData:write(buildDate)
	buildData:write(buildAuthor)
	buildData:close()
	-- release submitted
	print(("Completed pushing Solar2DTux version %s.%s.%s to GitHub!"):format(version.major, version.minor, version.revision))
end
