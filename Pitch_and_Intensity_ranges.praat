
###########################################################################
#                                                                         #
#  Praat Script Pitch_and_Intensity_ranges                                #
#  Copyright (C) 2020  R.J.J.H. van Son                                   #
#                                                                         #
#    This program is free software: you can redistribute it and/or modify #
#    it under the terms of the GNU General Public License as published by #
#    the Free Software Foundation, either version 3 of the License, or    #
#    (at your option) any later version.                                  #
#                                                                         #
#    This program is distributed in the hope that it will be useful,      #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of       #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the        #
#    GNU General Public License for more details.                         #
#                                                                         #
#    You should have received a copy of the GNU General Public License    #
#    along with this program.  If not, see http://www.gnu.org/licenses/   #
#                                                                         #
###########################################################################
#
# Scroll down for copyright and license information on the included 
# Syllable Nuclei script by de Jong and Wempe
#

# Initialize
# Set current Locale
.defaultLanguage = 1
uiLanguage$ = "EN"

# Initialize messages
call intialize_UI_messages

call retrieve_settings
.defaultLanguage = retrieve_settings.defaultLanguage
uiLanguage$ = retrieve_settings.preferencesLang$
.languageInput$ = uiMessage$ [uiLanguage$, "Interface Language"]
.languageInputVar$ = replace_regex$(.languageInput$, "^([A-Z])", "\l\1", 0)
.languageInputVar$ = replace_regex$(.languageInputVar$, "\s*\(.*$", "", 0)
.languageInputVar$ = replace_regex$(.languageInputVar$, "(\s|[.?!()/\\\\])", "_", 0)

beginPause: "Measuring Pitch and Dynamic range"
   real: "Silence threshold (dB)", retrieve_settings.silence_Threshold
   real: "Minimum dip between peaks (dB)", retrieve_settings.minimum_dip
   real: "Minimum pause duration (s)", retrieve_settings.minimum_pause
   #sentence directory Audio
   optionMenu: "Scale", retrieve_settings.scale_default
		option: "Hz"
		option: "Mel"
		option: "Bark"
		option: "Semitones"
   boolean: "Normalize intensity", retrieve_settings.normalize_intensity
   optionMenu: .languageInput$, .defaultLanguage
		option: "English"
		option: "Nederlands"
		option: "Deutsch"
		option: "Français"
		option: "汉语"
		option: "Español"
		option: "Português"
		option: "Italiano"
	#   option: "MyLanguage"   
.clicked = endPause: (uiMessage$ [uiLanguage$, "Stop"]), (uiMessage$ [uiLanguage$, "Continue"]), 2, 1

if .clicked = 1
	.continue = 0
	.message$ = uiMessage$ [uiLanguage$, "Nothing to do"]
	exitScript: .message$
endif

uiLanguage$ = "EN"
.defaultLanguage = 1
.display_language$ = '.languageInputVar$'$
if .display_language$ = "Nederlands"
	uiLanguage$ = "NL"
	.defaultLanguage = 2
elsif .display_language$ = "Deutsch"
	uiLanguage$ = "DE"
	.defaultLanguage = 3
elsif .display_language$ = "Français"
	uiLanguage$ = "FR"
	.defaultLanguage = 4
elsif .display_language$ = "汉语"
	uiLanguage$ = "ZH"
	.defaultLanguage = 5
elsif .display_language$ = "Español"
	uiLanguage$ = "ES"
	.defaultLanguage = 6
elsif .display_language$ = "Português"
	uiLanguage$ = "PT"
	.defaultLanguage = 7
elsif .display_language$ = "Italiano"
	uiLanguage$ = "IT"
	.defaultLanguage = 8
#
# Add a new language
# elsif .display_language$ = "MyLanguage"
#	uiLanguage$ = "MyCode"
#	.defaultLanguage = 9
endif

# Store settings
@write_settings: silence_threshold, minimum_dip_between_peaks, minimum_pause_duration, normalize_intensity, scale$

# Alert for crashed on Mac praat 6.1.17 and up
if macintosh and praatVersion >= 6117 and praatVersion <= 6131
	beginPause: "Warning"
		comment: "The script can crash unexpectedly on Mac OSX with Praat 6.1.17-6.1.31."
		comment: "Please upgrade to Praat 6.1.32 or higher."
	clicked = endPause: (uiMessage$ [uiLanguage$, "Continue"]), 0
endif

# shorten variables
silencedb = silence_threshold
mindip = minimum_dip_between_peaks
showtext = 1
minpause = minimum_pause_duration

# Global values
pitchFloor = 75
non_interactive = 0
.recording = 0

bottomAxis = 60
topAxis = 90
leftAxis = 50
rightAxis = 200
if scale$ = "Hz"
	precission = 0
elsif scale$ = "Mel"
	precission = 0
elsif scale$ = "Bark"
	precission = 2
elsif scale$ = "Semitones"
	precission = 1
endif

enteredTitle$ = uiMessage$ [uiLanguage$, "untitled"]


# read files
if non_interactive
	Create Strings as file list... list 'directory$'/*
	numberOfFiles = Get number of strings
	first = 1
	for ifile to numberOfFiles
	   select Strings list
	   fileName$ = Get string... ifile
	   if index_regex(fileName$, "\.(?iwav|aifc|aiff|flac|mp3|snd|next|nist)$")
			.soundFile = Read from file... 'directory$'/'fileName$'
		   
			call syllable_nuclei .soundFile
			
			@pitch_dynamic_range: syllable_nuclei.soundid, syllable_nuclei.textgridid, scale$
			
			# Plot
			.horizontal$ = """"+scale$+""", 'leftAxis', 'rightAxis'"
			.vertical$ = """Intensity"", 'bottomAxis', 'topAxis'"
			@plot_Pitch_Int_table: pitch_dynamic_range.table, .horizontal$, .vertical$, "'ifile'", 2, first, 1
			first = 0
			
			printline 'syllable_nuclei.soundname$';'syllable_nuclei.voicedcount';'syllable_nuclei.npause';'syllable_nuclei.originaldur:2';'syllable_nuclei.speakingtot:2';'syllable_nuclei.speakingrate:2';'syllable_nuclei.articulationrate:2';'syllable_nuclei.asd:3'
		endif
	endfor
else
	
	###############################################
	#
	# Start program: Interactive
	#
	###############################################
	.continue = 1
	# Run master loop
	left = 0
	right = 0
	bottom = 0
	top = 0
	writeInfoLine: "Mean Int;SD Int;Mean 'scale$';SD 'scale$';Slope;R;Area;N;Outliers;Duration;Title"
	while .continue
		first = 1
		
		# Open sound and select
		.open1$ = uiMessage$ [uiLanguage$, "Open1"]
		.open2$ = uiMessage$ [uiLanguage$, "Open2"]
		@read_and_select_audio: .recording, .open1$ , .open2$

		if read_and_select_audio.sound < 1
			goto NEXTROUND
		endif
		.soundFile = read_and_select_audio.sound
		if enteredTitle$ = uiMessage$ [uiLanguage$, "untitled"]
			titleText$ = replace_regex$(read_and_select_audio.filename$, "\.[^\.]+$", "", 0)
			titleText$ = replace_regex$(titleText$, "^.*/([^/]+)$", "\1", 0)
			titleText$ = replace_regex$(titleText$, "_", " ", 0)
		else
			titleText$ = enteredTitle$
		endif

		# Calculate values
		selectObject: .soundFile
		totalDuration = Get total duration
		@syllable_nuclei: .soundFile
		@pitch_dynamic_range: syllable_nuclei.soundid, syllable_nuclei.textgridid, scale$
		
		# Get title
		.titleVar$ = uiMessage$ [uiLanguage$, "Title"]
		.titleVar$ = replace_regex$(.titleVar$, "^([A-Z])", "\l\1", 0)
		beginPause: "Select a title"
			sentence: uiMessage$ [uiLanguage$, "Title"], titleText$
			comment: "Axes"
			real: uiMessage$ [uiLanguage$, "Left"], left
			real: uiMessage$ [uiLanguage$, "Right"], right
			real: uiMessage$ [uiLanguage$, "Bottom"], bottom
			real: uiMessage$ [uiLanguage$, "Top"], top
		.clicked = endPause: (uiMessage$ [uiLanguage$, "Stop"]), (uiMessage$ [uiLanguage$, "Continue"]), 2, 1	
		if .clicked = 1
			.continue = 0
			.message$ = uiMessage$ [uiLanguage$, "Nothing to do"]
			exitScript: .message$
		endif
		if '.titleVar$'$ = ""
			enteredTitle$ = uiMessage$ [uiLanguage$, "untitled"]
		elsif '.titleVar$'$ != uiMessage$ [uiLanguage$, "untitled"] and index_regex('.titleVar$'$, "[^\s]")
			if titleText$ <> '.titleVar$'$
				enteredTitle$ = '.titleVar$'$
			endif
			titleText$ = '.titleVar$'$
		endif
		.resetAxis = 1
		if left != 0
			leftAxis = left
			.resetAxis = 0
		endif
		if right != 0
			rightAxis = right
			.resetAxis = 0
		endif
		if bottom != 0
			bottomAxis = bottom
			.resetAxis = 0
		endif
		if top != 0
			topAxis = top
			.resetAxis = 0
		endif
		
		# Plot
		.horizontal$ = """"+scale$+""", 'leftAxis', 'rightAxis'"
		.vertical$ = """Intensity (dB)"", 'bottomAxis', 'topAxis'"
		@plot_Pitch_Int_table: pitch_dynamic_range.table, .horizontal$, .vertical$, "\bu", 2, first, .resetAxis
		
		# Print info
		# "Mean Int;SD Int;Mean 'scale$';SD 'scale$';Slope;Rsqr;N;Outliers;Area;Duration;Title"
		appendInfoLine: fixed$(plot_Pitch_Int_table.meanInt, precission+1), ";", fixed$(plot_Pitch_Int_table.sdInt, precission+1), ";", fixed$(plot_Pitch_Int_table.meanF0, precission+1), ";", fixed$(plot_Pitch_Int_table.sdF0, precission+1), ";", fixed$(plot_Pitch_Int_table.slope, precission+3), ";", fixed$(plot_Pitch_Int_table.r, precission+2), ";", fixed$(plot_Pitch_Int_table.area, precission), ";", plot_Pitch_Int_table.nrows, ";", plot_Pitch_Int_table.removed, ";", fixed$(totalDuration, precission), ";", titleText$
	
		# Write title
		Helvetica
		Text special: (leftAxis+rightAxis)/2, "Centre", topAxis+0.5, "Bottom", "Helvetica", 24, "0", titleText$	
	
		# Save graphics
		.file$ = chooseWriteFile$: uiMessage$ [uiLanguage$, "SavePicture"], titleText$+"_PitchDynamic.png"
		if .file$ <> ""
			Select outer viewport: 0, 9, 0, 9
			Save as 300-dpi PNG file: .file$
		endif

		# Clean up
		selectObject: syllable_nuclei.soundid, syllable_nuclei.textgridid, pitch_dynamic_range.table
		Remove
			
		# Ready or not?
		beginPause: uiMessage$ [uiLanguage$, "DoContinue"]
			comment: uiMessage$ [uiLanguage$, "CommentContinue"]
		.clicked = endPause: (uiMessage$ [uiLanguage$, "Continue"]), (uiMessage$ [uiLanguage$, "Done"]), 2, 2
		.continue = (.clicked = 1)
		label NEXTROUND
	endwhile
	
endif

procedure pitch_dynamic_range .sound .textgrid .scale$
	selectObject: .sound
	.tmp1 = nocheck noprogress nowarn To Pitch: 0, pitchFloor, 600
	.tmp2 = Interpolate
	.pitch = Down to PitchTier

	selectObject: .sound
	.tmp3 = nocheck noprogress nowarn To Intensity: pitchFloor, 0, "yes"
	.intensity = Down to IntensityTier

	# Clean up
	selectObject: .tmp1, .tmp2, .tmp3
	Remove
	
	# Extract values
	selectObject: .textgrid
	.numSyllables = Get number of points: 1
	.table = Create Table with column names: "Values", .numSyllables, "i t "+.scale$+" Intensity"
	for .i to .numSyllables
		selectObject: .textgrid
		.t = Get time of point: 1, .i
		selectObject: .pitch
		.f0 = Get value at time: .t
		if .scale$ = "Mel"
			.f0 = hertzToMel(.f0)
		endif
		if .scale$ = "Bark"
			.f0 = hertzToBark(.f0)
		endif
		if .scale$ = "Semitones"
			.f0 = hertzToSemitones(.f0)
		endif
		selectObject: .intensity
		.int = Get value at time: .t
		
		# Write table
		selectObject: .table
		Set numeric value: .i, "i", .i
		Set numeric value: .i, "t", .t
		Set numeric value: .i, scale$, .f0
		Set numeric value: .i, "Intensity", .int
	endfor
		
	selectObject: .pitch, .intensity
	Remove
	
endproc

procedure plot_Pitch_Int_table .table .horizontal$ .vertical$ .mark$ .marksize, .first, .resetAxis
	.garnish$ = "no"
	
	.scale$ = replace_regex$(.horizontal$, "^""([^""]+)"".*$", "\1", 0)
	# Next is not used, should go
	.left = extractNumber(.horizontal$, """, ")
	.right = extractNumber(.horizontal$, ", '.left', ")
	.bottom = extractNumber(.vertical$, """, ")
	.top = extractNumber(.vertical$, ", '.bottom', ")
	
	# Set up new canvas
	if .first
		Erase all
		call set_up_Canvas
		.garnish$ = "yes"
	endif
	.top = topAxis
	.bottom = bottomAxis
	.left = leftAxis
	.right = rightAxis
		
	# Clean table (remove 3Sd points)
	selectObject: .table
	.cleanTable = Copy: "CleanTable"
	.nrows = Get number of rows
	.meanInt = Get mean: "Intensity"
	.sdInt = Get standard deviation: "Intensity"
	.meanF0 = Get mean: .scale$
	.sdF0 = Get standard deviation: .scale$
	
	# Adapt mark size
	.currentMarkSize = .marksize*sqrt(200/.nrows)
	if .currentMarkSize < 2.5 
		.currentMarkSize = 2.5
	elsif .currentMarkSize > 5
		.currentMarkSize = 5
	endif

	.removed = 0
	for .j from 0 to .nrows-1
		.r = .nrows - .j
		.intRow = Get value: .r, "Intensity"
		.f0Row = Get value: .r, .scale$
		if .intRow < .meanInt - 3*.sdInt or .intRow > .meanInt + 3*.sdInt
			Red
			Text special: .f0Row, "Centre", .intRow, "Half", "Helvetica", 6*.currentMarkSize, "0", .mark$
			Black
			Remove row: .r
			.removed += 1
		elsif .f0Row < .meanF0 - 3*.sdF0 or .f0Row > .meanF0 + 3*.sdF0
			Red
			Text special: .f0Row, "Centre", .intRow, "Half", "Helvetica", 6*.currentMarkSize, "0", .mark$
			Remove row: .r
			Black
			.removed += 1
		endif
	endfor

	# Recalculate values
	selectObject: .cleanTable
	.nrows = Get number of rows
	.meanInt = Get mean: "Intensity"
	.sdInt = Get standard deviation: "Intensity"
	.meanF0 = Get mean: .scale$
	.sdF0 = Get standard deviation: .scale$
	if .resetAxis
		@set_axes: .scale$, .meanF0 - 2*.sdF0, .meanF0 + 2*.sdF0
	endif
	@calculate_ellipse: .cleanTable
	.area = calculate_ellipse.area
	.theta = calculate_ellipse.theta
	.slope = calculate_ellipse.slope
	.r = calculate_ellipse.r
	.rsqr = .r^2

	.xLow = calculate_ellipse.xLow
	.xHigh = calculate_ellipse.xHigh
	.yLow = calculate_ellipse.yLow
	.yHigh = calculate_ellipse.yHigh
	
	.xLow.minor = calculate_ellipse.xLow.minor
	.xHigh.minor = calculate_ellipse.xHigh.minor
	.yLow.minor = calculate_ellipse.yLow.minor
	.yHigh.minor = calculate_ellipse.yHigh.minor
	
	# Plot
	selectObject: .table
	# Change column name to get correct axis label
	Set column label (label): "Intensity", "Intensity (dB)"
	Scatter plot (mark): .scale$, leftAxis, rightAxis, "Intensity (dB)", bottomAxis, topAxis, .currentMarkSize, .garnish$, .mark$
	Marks left every: 1, 10, "no", "yes", "no"
	.every = 20
	if rightAxis - leftAxis < 1.5
		.every = 0.10
	elsif rightAxis - leftAxis < 15
		.every = 1
	elsif rightAxis - leftAxis < 150
		.every = 10
	endif
	Marks bottom every: 1, .every, "no", "yes", "no"
	
	# Draw bounding lines
	Dotted line
	Draw line: .meanF0-2*.sdF0, topAxis, .meanF0-2*.sdF0, bottomAxis
	Draw line: .meanF0+2*.sdF0, topAxis, .meanF0+2*.sdF0, bottomAxis
	Draw line: leftAxis, .meanInt-2*.sdInt, rightAxis, .meanInt-2*.sdInt
	Draw line: leftAxis, .meanInt+2*.sdInt, rightAxis, .meanInt+2*.sdInt
	
	Solid line
	Text special: .meanF0-2*.sdF0, "Centre", bottomAxis-0.1, "Top", "Helvetica", 12, "0", fixed$(.meanF0-2*.sdF0, precission)
	Text special: .meanF0+2*.sdF0, "Centre", bottomAxis-0.1, "Top", "Helvetica", 12, "0", fixed$(.meanF0+2*.sdF0, precission)
	Text special: rightAxis, "Left", .meanInt-2*.sdInt, "Half", "Helvetica", 12, "0", fixed$(.meanInt-2*.sdInt, 0)
	Text special: rightAxis, "Left", .meanInt+2*.sdInt, "Half", "Helvetica", 12, "0", fixed$(.meanInt+2*.sdInt, 0)

	selectObject: .cleanTable
	Blue
	Draw ellipse (standard deviation): .scale$, leftAxis, rightAxis, "Intensity", bottomAxis, topAxis, 2, "no"
	Dotted line
	Draw line: .xLow, .yLow, .xHigh, .yHigh
	Draw line: .xLow.minor, .yLow.minor, .xHigh.minor, .yHigh.minor
	Solid line
	Black
	Text special: leftAxis, "Left", bottomAxis+1.6, "Bottom", "Helvetica", 12, "0", uiMessage$ [uiLanguage$, "Duration"]+": "+fixed$(totalDuration, precission)+" s"
	Text special: leftAxis, "Left", bottomAxis+0.8, "Bottom", "Helvetica", 12, "0", "N: '.nrows'"
	Text special: leftAxis, "Left", bottomAxis, "Bottom", "Helvetica", 12, "0", "\# Outliers: '.removed' (3 SD)"
	
	
	# Mean X
	Blue
	Text special: .meanF0, "Centre", .meanInt, "Half", "Helvetica", 10, "0", "x"
	Text special: .meanF0, "Centre", .meanInt-0.5, "top", "Helvetica", 9, "0", "("+fixed$(.meanF0, precission)+", "+fixed$(.meanInt, precission)+")"
	Black
	
	Text special: rightAxis, "Right", bottomAxis+1.6, "Bottom", "Helvetica", 10, "0", "R: "+fixed$(.r, 3)+" "
	Text special: rightAxis, "Right", bottomAxis+0.8, "Bottom", "Helvetica", 10, "0", uiMessage$ [uiLanguage$, "SlopeTitle"]+": "+fixed$(.slope, precission+1)+" dB/"+.scale$+" "
	Text special: rightAxis, "Right", bottomAxis, "Bottom", "Helvetica", 10, "0", uiMessage$ [uiLanguage$, "AreaTitle"]+" (2 SD): "+fixed$(.area, precission)+" "+.scale$+"\.cdB"+" "
	
	selectObject: .cleanTable
	Remove
	
	# Axes 
	Text special: (leftAxis + rightAxis)/2, "Centre", bottomAxis, "Top", "Helvetica", 16, "0", "F_0"
	
	if .scale$ <> "Hz"
		# Axis
		.leftHertz$ = ""
		.rightHertz$ = ""
		if .scale$ = "Mel"
			.leftHertz$ = fixed$(melToHertz(leftAxis), 0)
			.rightHertz$ = fixed$(melToHertz(rightAxis), 0)
		elsif .scale$ = "Bark"
			.leftHertz$ = fixed$(barkToHertz(leftAxis), 0)
			.rightHertz$ = fixed$(barkToHertz(rightAxis), 0)
		elsif .scale$ = "Semitones"
			.leftHertz$ = fixed$(semitonesToHertz(leftAxis), 0)
			.rightHertz$ = fixed$(semitonesToHertz(rightAxis), 0)
		endif
		Text special: .left, "Centre", bottomAxis-2, "Top", "Helvetica", 12, "0", "("+.leftHertz$+"Hz)"
		Text special: .right, "Centre", bottomAxis-2, "Top", "Helvetica", 12, "0", "("+.rightHertz$+"Hz)"
		
		# Boundaries
		.leftHertz$ = ""
		.rightHertz$ = ""
		.leftValue = .meanF0-2*.sdF0
		.rightValue = .meanF0+2*.sdF0
		if .scale$ = "Mel"
			.leftHertz$ = fixed$(melToHertz(.leftValue), 0)
			.rightHertz$ = fixed$(melToHertz(.rightValue), 0)
		elsif .scale$ = "Bark"
			.leftHertz$ = fixed$(barkToHertz(.leftValue), 0)
			.rightHertz$ = fixed$(barkToHertz(.rightValue), 0)
		elsif .scale$ = "Semitones"
			.leftHertz$ = fixed$(semitonesToHertz(.leftValue), 0)
			.rightHertz$ = fixed$(semitonesToHertz(.rightValue), 0)
		endif
		Text special: .meanF0-2*.sdF0, "Centre", topAxis, "Bottom", "Helvetica", 12, "0", .leftHertz$+"Hz"
		Text special: .meanF0+2*.sdF0, "Centre", topAxis, "Bottom", "Helvetica", 12, "0", .rightHertz$+"Hz"
	endif
endproc


# Set up Canvas
procedure set_up_Canvas
	Select outer viewport: 0, 9, 0, 9
	Select inner viewport: 1, 8, 1, 8
	Axes: leftAxis, rightAxis, bottomAxis, topAxis
	Solid line
	Black
	Line width: 1.0
endproc

# Set axis boundaries
procedure set_axes .scale$ .lowPitch .highPitch
	.lowest = 50
	.highest = 200
	.range = 4
	
	# Bark
	if .scale$ = "Bark"
		.lowest = 0.5
		.highest = 2.2
		.range = 2
		.step = .range/8
	# Semitones
	elsif .scale$ = "Semitones"
		.lowest = -12
		.highest = 12
		.range = 30
		.step = 3
	# Mel
	elsif .scale$ = "Mel"
		.lowest = 50
		.highest = 175
		.range = 175
		.step = 15
	# Hz
	elsif .scale$ = "Hz"
		.lowest = 50
		.highest = 200
		.range = 5
		.step = 25
	endif

	.lowBoundary = .lowest
	while .lowBoundary <= .highest
		if .scale$ = "Hz"
			.highBoundary = .lowBoundary * .range
		else
			.highBoundary = .lowBoundary + .range
		endif
		
		if .highBoundary >= .highPitch   
			leftAxis = .lowBoundary
			rightAxis = .highBoundary
			goto LAST
		endif
		
		.lowBoundary += .step
	endwhile
	label LAST
endproc


procedure read_and_select_audio .type .message1$ .message2$
	.sound = -1
	if .type
		Record mono Sound...
		beginPause: (uiMessage$ [uiLanguage$, "PauseRecord"])
			comment: uiMessage$ [uiLanguage$, "CommentList"]
		.clicked = endPause: (uiMessage$ [uiLanguage$, "Stop"]), (uiMessage$ [uiLanguage$, "Continue"]), 2, 1
		if .clicked = 1
			pauseScript: (uiMessage$ [uiLanguage$, "Stopped"])
			goto RETURN
		endif
		if numberOfSelected("Sound") <= 0
			pauseScript: (uiMessage$ [uiLanguage$, "ErrorSound"])
			goto RETURN
		endif
		.source = selected ("Sound")
		.filename$ = "Recorded speech"
	else
		.filename$ = chooseReadFile$: .message1$

		if .filename$ = "" or not fileReadable(.filename$) or not index_regex(.filename$, "(?i\.(wav|mp3|aif[fc]))")
			pauseScript: (uiMessage$ [uiLanguage$, "No readable recording selected "])+.filename$
			goto RETURN
		endif
		.source = Open long sound file: .filename$
		.filename$ = selected$("LongSound")
		.fullName$ = selected$()
		.fileType$ = extractWord$ (.fullName$, "")
		if .fileType$ <> "Sound" and .fileType$ <> "LongSound"
			pauseScript:  (uiMessage$ [uiLanguage$, "ErrorSound"])+.filename$
			goto RETURN
		endif
	endif

	selectObject: .source
	.fullName$ = selected$()
	.duration = Get total duration
	.tmp = -1
	if not (macintosh and praatVersion >= 6117 and praatVersion <= 6131)
		if startsWith(.fullName$, "Sound") 
			View & Edit
		else
			View
		endif
		editor: .source
		endeditor
		beginPause: .message2$
			comment: (uiMessage$ [uiLanguage$, "SelectSound1"])
			comment: (uiMessage$ [uiLanguage$, "SelectSound2"])
			comment: (uiMessage$ [uiLanguage$, "SelectSound3"])
		.clicked = endPause: (uiMessage$ [uiLanguage$, "Stop"]), (uiMessage$ [uiLanguage$, "Continue"]), 2, 1
		if .clicked = 1
			selectObject: .source
			Remove
			pauseScript: (uiMessage$ [uiLanguage$, "Stopped"])
			goto RETURN
		endif
		
		editor: .source
			.start = Get start of selection
			.end = Get end of selection
			if .start >= .end
				Select: 0, .duration
			endif
			.tmp = Extract selected sound (time from 0)
		endeditor
	endif
	if .tmp <= 0
		selectObject: .source
		.duration = Get total duration
		.tmp = Extract part: 0, .duration, "yes"
	endif
	
	# Recordings can be in Stereo, change to mono
	selectObject: .tmp
	.numChannels = Get number of channels
	if .numChannels > 1
		.maxInt = -10000
		.bestChannel = 1
		for .c to .numChannels
			selectObject: .tmp
			.tmpChannel = Extract one channel: .c
			.currentInt = Get intensity (dB)
			if .currentInt > .maxInt
				.maxInt = .currentInt
				.bestChannel = .c
			endif
			selectObject: .tmpChannel
			Remove
		endfor
		selectObject: .tmp
		.sound = Extract one channel: .bestChannel
		Rename: .filename$
	else
		selectObject: .tmp
		.sound = Copy: .filename$
	endif

	selectObject: .tmp, .source
	Remove

	selectObject: .sound
	Rename: .filename$
	if normalize_intensity
		Scale intensity: 70
	endif

	label RETURN
endproc

procedure calculate_ellipse .table
	selectObject: .table
	.realTable = Down to TableOfReal: "i"
	Remove column (index): 1
	.correlation = nocheck noprogress nowarn To Correlation
	.r = Get value: 1, 2
	selectObject: .realTable
	.meanPitch = Get column mean (index): 1
	.sdPitch= Get column stdev (index): 1
	.meanInt = Get column mean (index): 2
	.sdInt = Get column stdev (index): 2
	.covariance = nocheck noprogress nowarn To Covariance
	.a = Get value: 1, 1
	.b1 = Get value: 1, 2
	.b2 = Get value: 2, 1
	.c = Get value: 2, 2
	
	.pca = nocheck noprogress nowarn To PCA
	.e1.x = Get eigenvector element: 1, 1
	.e1.y = Get eigenvector element: 1, 2
	.e2.x = Get eigenvector element: 2, 1
	.e2.y = Get eigenvector element: 2, 2

	.lambda.1 = (.a + .c)/2 + sqrt(((.a - .c)/2)^2 + .b1*.b2)
	.lambda.2 = (.a + .c)/2 - sqrt(((.a - .c)/2)^2 + .b1*.b2)
	.area = pi * 2 * sqrt(.lambda.1) * 2 * sqrt(.lambda.2)
	if .b1 = 0 and .a >= .c
		.theta = 0
		.slope = 0
		.slope.2 = undefined
	elsif .b1 = 0 and .a < .c
		.theta = pi /2
		.slope = undefined
		.slope.2 = 0
	else
		.theta = arctan2(.lambda.1 - .a, .b1)
		.slope = (.lambda.1 - .a) / .b1
		.slope.2 = .e2.y / .e2.x
	endif
	.degrees = .theta * 180 / pi
	.xTheta = .lambda.1 - .a
	.yTheta = .b1
	
	.theta.minor = .theta + pi / 2
	.degrees.minor = .degrees + 90
	
	.xLow  = .meanPitch - 2*sqrt(.lambda.1)*.e1.x
	.xHigh = .meanPitch + 2*sqrt(.lambda.1)*.e1.x
	.yLow  = .meanInt   - 2*sqrt(.lambda.1)*.e1.y
	.yHigh = .meanInt   + 2*sqrt(.lambda.1)*.e1.y

	.xLow.minor  = .meanPitch - 2*sqrt(.lambda.2)*.e2.x
	.xHigh.minor = .meanPitch + 2*sqrt(.lambda.2)*.e2.x
	.yLow.minor  = .meanInt   - 2*sqrt(.lambda.2)*.e2.y
	.yHigh.minor = .meanInt   + 2*sqrt(.lambda.2)*.e2.y

	selectObject: .realTable, .covariance, .correlation, .pca
	Remove
endproc

# UI messages and texts

procedure intialize_UI_messages

# English
uiMessage$ ["EN", "PauseRecord"] = "Record continuous speech"
uiMessage$ ["EN", "Record1"] = "Record the ##continuous speech#"
uiMessage$ ["EN", "Record2"] = "Please be ready to start"
uiMessage$ ["EN", "Record3"] = "Select the speech you want to analyse"
uiMessage$ ["EN", "Open1"] = "Open the recording containing the speech"
uiMessage$ ["EN", "Open2"] = "Select the speech you want to analyse"
uiMessage$ ["EN", "Corneri"] = "h##ea#t"
uiMessage$ ["EN", "Corneru"] = "h##oo#t"
uiMessage$ ["EN", "Cornera"] = "h##a#t"
uiMessage$ ["EN", "SlopeTitle"] = "Slope"
uiMessage$ ["EN", "AreaTitle"] = "Area"
uiMessage$ ["EN", "Area1"] = "1"
uiMessage$ ["EN", "Area2"] = "2"
uiMessage$ ["EN", "AreaN"] = "N"
uiMessage$ ["EN", "Duration"] = "Duration"
uiMessage$ ["EN", "VTL"] = "Vocal tract"

uiMessage$ ["EN", "LogFile"] = "Write log to table (""-"" write to the info window)"
uiMessage$ ["EN", "CommentContinue"] = "Click on ""Continue"" if you want to analyze more speech samples"
uiMessage$ ["EN", "CommentOpen"] = "Click on ""Open"" and select a recording"
uiMessage$ ["EN", "CommentRecord"] = "Click on ""Record"" and start speaking"
uiMessage$ ["EN", "CommentList"] = "Record sound, ""Save to list & Close"", then click ""Continue"""
uiMessage$ ["EN", "SavePicture"] = "Save picture"
uiMessage$ ["EN", "DoContinue"] = "Do you want to continue?"
uiMessage$ ["EN", "SelectSound1"] = "Select the sound and continue"
uiMessage$ ["EN", "SelectSound2"] = "It is possible to remove unwanted sounds from the selection"
uiMessage$ ["EN", "SelectSound3"] = "Select the unwanted part and then choose ""Cut"" from the ""Edit"" menu"
uiMessage$ ["EN", "Stopped"] = "Vowel Triangle stopped"
uiMessage$ ["EN", "ErrorSound"] = "Error: Not a sound "
uiMessage$ ["EN", "Nothing to do"] = "Nothing to do"
uiMessage$ ["EN", "No readable recording selected "] = "No readable recording selected "

uiMessage$ ["EN", "Interface Language"] = "Language"
uiMessage$ ["EN", "Speaker is a"] = "Speaker is a"
uiMessage$ ["EN", "Male"] = "Male ♂"
uiMessage$ ["EN", "Female"] = "Female ♀"
uiMessage$ ["EN", "Automatic"] = "Automatic"
uiMessage$ ["EN", "Experimental"] = "Experimental: Select formant tracking method"
uiMessage$ ["EN", "Continue"] = "Continue"
uiMessage$ ["EN", "Done"] = "Done"
uiMessage$ ["EN", "Stop"] = "Stop"
uiMessage$ ["EN", "Open"] = "Open"
uiMessage$ ["EN", "Record"] = "Record"
uiMessage$ ["EN", "untitled"] = "untitled"
uiMessage$ ["EN", "Title"] 			= "Title"

uiMessage$ ["EN", "Left"] 			= "Left"
uiMessage$ ["EN", "Right"] 			= "Right"
uiMessage$ ["EN", "Top"] 			= "Top"
uiMessage$ ["EN", "Bottom"] 		= "Bottom"
uiMessage$ ["EN", "Axes"] 			= "Axes"

# Dutch
uiMessage$ ["NL", "PauseRecord"] 	= "Neem lopende spraak op"
uiMessage$ ["NL", "Record1"] 		= "Neem de ##lopende spraak# op"
uiMessage$ ["NL", "Record2"] 		= "Zorg dat u klaar ben om te spreken"
uiMessage$ ["NL", "Record3"] 		= "Selecteer de spraak die u wilt analyseren"
uiMessage$ ["NL", "Open1"] 			= "Open de spraakopname"
uiMessage$ ["NL", "Open2"] 			= "Selecteer de spraak die u wilt analyseren"
uiMessage$ ["NL", "Corneri"] 		= "h##ie#t"
uiMessage$ ["NL", "Corneru"] 		= "h##oe#d"
uiMessage$ ["NL", "Cornera"] 		= "h##aa#t"
uiMessage$ ["NL", "SlopeTitle"] 	= "Helling"
uiMessage$ ["NL", "AreaTitle"] 		= "Oppervlak"
uiMessage$ ["NL", "Area1"] 			= "1"
uiMessage$ ["NL", "Area2"] 			= "2"
uiMessage$ ["NL", "AreaN"] 			= "N"
uiMessage$ ["NL", "Duration"] 		= "Duur"
uiMessage$ ["NL", "VTL"] 			= "Spraakkanaal"

uiMessage$ ["NL", "LogFile"] 		= "Schrijf resultaten naar log bestand (""-"" schrijft naar info venster)"
uiMessage$ ["NL", "CommentContinue"] = "Klik op ""Doorgaan"" als u meer spraakopnamen wilt analyseren"
uiMessage$ ["NL", "CommentOpen"] 	= "Klik op ""Open"" en selecteer een opname"
uiMessage$ ["NL", "CommentRecord"] 	= "Klik op ""Opnemen"" en start met spreken"
uiMessage$ ["NL", "CommentList"] 	= "Spraak opnemen, ""Save to list & Close"", daarna klik op ""Doorgaan"""
uiMessage$ ["NL", "SavePicture"] 	= "Bewaar afbeelding"
uiMessage$ ["NL", "DoContinue"] 	= "Wilt u doorgaan?"
uiMessage$ ["NL", "SelectSound1"] 	= "Selecteer het spraakfragment en ga door"
uiMessage$ ["NL", "SelectSound2"] 	= "Het is mogelijk om ongewenste geluiden uit de opname te verwijderen"
uiMessage$ ["NL", "SelectSound3"] 	= "Selecteer het ongewenste deel en kies ""Cut"" in het ""Edit"" menu"
uiMessage$ ["NL", "Stopped"] 		= "Vowel Triangle is gestopt"
uiMessage$ ["NL", "ErrorSound"] 	= "Fout: Dit is geen geluid "
uiMessage$ ["NL", "Nothing to do"] 	= "Geen taken"
uiMessage$ ["NL", "No readable recording selected "] = "Geen leesbare opname geselecteerd "

uiMessage$ ["NL", "Interface Language"] = "Taal (Language)"
uiMessage$ ["NL", "Speaker is a"] 	= "De Spreker is een"
uiMessage$ ["NL", "Male"] 			= "Man ♂"
uiMessage$ ["NL", "Female"] 		= "Vrouw ♀"
uiMessage$ ["NL", "Automatic"] 		= "Automatisch"
uiMessage$ ["NL", "Experimental"] 	= "Experimenteel: Kies methode om formanten te berekenen"
uiMessage$ ["NL", "Continue"] 		= "Doorgaan"
uiMessage$ ["NL", "Done"] 			= "Klaar"
uiMessage$ ["NL", "Stop"] 			= "Stop"
uiMessage$ ["NL", "Open"] 			= "Open"
uiMessage$ ["NL", "Record"] 		= "Opnemen"
uiMessage$ ["NL", "untitled"] 		= "zonder titel"
uiMessage$ ["NL", "Title"] 			= "Titel"

uiMessage$ ["NL", "Left"] 			= "Links"
uiMessage$ ["NL", "Right"] 			= "Rechts"
uiMessage$ ["NL", "Top"] 			= "Boven"
uiMessage$ ["NL", "Bottom"] 		= "Onder"
uiMessage$ ["NL", "Axes"] 			= "Assen"

# German
uiMessage$ ["DE", "PauseRecord"] 	= "Zeichne laufende Sprache auf"
uiMessage$ ["DE", "Record1"] 		= "Die ##laufende Sprache# aufzeichnen"
uiMessage$ ["DE", "Record2"] 		= "Bitte seien Sie bereit zu sprechen"
uiMessage$ ["DE", "Record3"] 		= "Wählen Sie die Sprachaufnahme, die Sie analysieren möchten"
uiMessage$ ["DE", "Open1"] 			= "Öffnen Sie die Sprachaufnahme"
uiMessage$ ["DE", "Open2"] 			= "Wählen Sie die Sprachaufnahme, die Sie analysieren möchten"
uiMessage$ ["DE", "Corneri"] 		= "L##ie#d"
uiMessage$ ["DE", "Corneru"] 		= "H##u#t"
uiMessage$ ["DE", "Cornera"] 		= "T##a#l"
uiMessage$ ["DE", "SlopeTitle"] 	= "Steigung"
uiMessage$ ["DE", "AreaTitle"] 		= "Oberfläche"
uiMessage$ ["DE", "Area1"] 			= "1"
uiMessage$ ["DE", "Area2"] 			= "2"
uiMessage$ ["DE", "AreaN"] 			= "N"
uiMessage$ ["DE", "Duration"] 		= "Dauer"
uiMessage$ ["DE", "VTL"] 			= "Vokaltrakt"
                                     
uiMessage$ ["DE", "LogFile"] 		= "Daten in Tabelle schreiben (""-"" in das Informationsfenster schreiben)"
uiMessage$ ["DE", "CommentContinue"]= "Klicken Sie auf ""Weiter"", wenn Sie mehr Sprachproben analysieren möchten"
uiMessage$ ["DE", "CommentOpen"] 	= "Klicke auf ""Öffnen"" und wähle eine Aufnahme"
uiMessage$ ["DE", "CommentRecord"] 	= "Klicke auf ""Aufzeichnen"" und sprich"
uiMessage$ ["DE", "CommentList"] 	= "Sprache aufnehmen, ""Save to list & Close"", dann klicken Sie auf ""Weitergehen"""
uiMessage$ ["DE", "SavePicture"] 	= "Bild speichern"
uiMessage$ ["DE", "DoContinue"] 	= "Möchten Sie weitergehen?"
uiMessage$ ["DE", "SelectSound1"] 	= "Wählen Sie den Aufnahmebereich und gehen Sie weiter"
uiMessage$ ["DE", "SelectSound2"] 	= "Es ist möglich, unerwünschte Geräusche aus der Auswahl zu entfernen"
uiMessage$ ["DE", "SelectSound3"] 	= "Wählen Sie den unerwünschten Teil und wählen Sie dann ""Cut"" aus dem ""Edit"" Menü"
uiMessage$ ["DE", "Stopped"] 		= "VowelTriangle ist gestoppt"
uiMessage$ ["DE", "ErrorSound"] 	= "Fehler: Keine Sprache gefunden"
uiMessage$ ["DE", "Nothing to do"] 	= "Keine Aufgaben"
uiMessage$ ["DE", "No readable recording selected "] = "Keine verwertbare Aufnahme ausgewählt "
               
uiMessage$ ["DE", "Interface Language"] = "Sprache (Language)"
uiMessage$ ["DE", "Speaker is a"] 	= "Der Sprecher ist ein(e)"
uiMessage$ ["DE", "Male"] 			= "Man ♂"
uiMessage$ ["DE", "Female"] 		= "Frau ♀"
uiMessage$ ["DE", "Automatic"] 		= "Selbstauswahl"
uiMessage$ ["DE", "Experimental"] 	= "Experimentell: Wählen Sie die Formant-Berechnungsmethode"
uiMessage$ ["DE", "Continue"] 		= "Weitergehen"
uiMessage$ ["DE", "Done"] 			= "Fertig"
uiMessage$ ["DE", "Stop"] 			= "Halt"
uiMessage$ ["DE", "Open"] 			= "Öffnen"
uiMessage$ ["DE", "Record"] 		= "Aufzeichnen"
uiMessage$ ["DE", "untitled"] 		= "ohne Titel"
uiMessage$ ["DE", "Title"] 			= "Titel"

uiMessage$ ["DE", "Left"] 			= "Links"
uiMessage$ ["DE", "Right"] 			= "Rechts"
uiMessage$ ["DE", "Top"] 			= "Oben"
uiMessage$ ["DE", "Bottom"] 		= "Unten"
uiMessage$ ["DE", "Axes"] 			= "Axes"

# French
uiMessage$ ["FR", "PauseRecord"]	= "Enregistrer un discours continu"
uiMessage$ ["FR", "Record1"]		= "Enregistrer le ##discours continu#"
uiMessage$ ["FR", "Record2"]		= "S'il vous plaît soyez prêt à commencer"
uiMessage$ ["FR", "Record3"]		= "Sélectionnez le discours que vous voulez analyser"
uiMessage$ ["FR", "Open1"]			= "Ouvrir l'enregistrement contenant le discours"
uiMessage$ ["FR", "Open2"]			= "Sélectionnez le discours que vous voulez analyser"
uiMessage$ ["FR", "Corneri"]		= "s##i#"
uiMessage$ ["FR", "Corneru"]		= "f##ou#"
uiMessage$ ["FR", "Cornera"]		= "l##à#"
uiMessage$ ["FR", "SlopeTitle"]		= "Pente"
uiMessage$ ["FR", "AreaTitle"]		= "Surface"
uiMessage$ ["FR", "Area1"]			= "1"
uiMessage$ ["FR", "Area2"]			= "2"
uiMessage$ ["FR", "AreaN"]			= "N"
uiMessage$ ["FR", "Duration"] 		= "Dur\e'e"
uiMessage$ ["FR", "VTL"] 			= "Conduit vocal"
                                     
uiMessage$ ["FR", "LogFile"]		= "Écrire un fichier journal dans une table (""-"" écrire dans la fenêtre d'information)"
uiMessage$ ["FR", "CommentContinue"]= "Cliquez sur ""Continuer"" si vous voulez analyser plus d'échantillons de discours"
uiMessage$ ["FR", "CommentOpen"]	= "Cliquez sur ""Ouvrir"" et sélectionnez un enregistrement"
uiMessage$ ["FR", "CommentRecord"]	= "Cliquez sur ""Enregistrer"" et commencez à parler"
uiMessage$ ["FR", "CommentList"]	= "Enregistrer le son, ""Save to list & Close"", puis cliquez sur ""Continuer"""
uiMessage$ ["FR", "SavePicture"]	= "Enregistrer l'image"
uiMessage$ ["FR", "DoContinue"]		= "Voulez-vous continuer?"
uiMessage$ ["FR", "SelectSound1"]	= "Sélectionnez le son et continuez"
uiMessage$ ["FR", "SelectSound2"]	= "Il est possible de supprimer les sons indésirables de la sélection"
uiMessage$ ["FR", "SelectSound3"]	= "Sélectionnez la partie indésirable, puis choisissez ""Cut"" dans le menu ""Edit"""
uiMessage$ ["FR", "Stopped"]		= "VowelTriangle s'est arrêté"
uiMessage$ ["FR", "ErrorSound"]		= "Erreur: pas du son"
uiMessage$ ["FR", "Nothing to do"] 	= "Rien à faire"
uiMessage$ ["FR", "No readable recording selected "] = "Aucun enregistrement utilisable sélectionné "
                  
uiMessage$ ["FR", "Interface Language"] = "Langue (Language)"
uiMessage$ ["FR", "Speaker is a"]	= "Le locuteur est un(e)"
uiMessage$ ["FR", "Male"] 			= "Homme ♂"
uiMessage$ ["FR", "Female"] 		= "Femme ♀"
uiMessage$ ["FR", "Automatic"] 		= "Auto-sélection"
uiMessage$ ["FR", "Experimental"] 	= "Expérimental: Sélectionner la méthode de calcul du formant"
uiMessage$ ["FR", "Continue"]		= "Continuer"
uiMessage$ ["FR", "Done"]			= "Terminé"
uiMessage$ ["FR", "Stop"]			= "Arrêt"
uiMessage$ ["FR", "Open"]			= "Ouvert"
uiMessage$ ["FR", "Record"]			= "Enregistrer"
uiMessage$ ["FR", "untitled"] 		= "sans titre"
uiMessage$ ["FR", "Title"] 			= "Titre"

uiMessage$ ["FR", "Left"] 			= "Gauche"
uiMessage$ ["FR", "Right"] 			= "Droite"
uiMessage$ ["FR", "Top"] 			= "Supérieur"
uiMessage$ ["FR", "Bottom"] 		= "Inférieur"
uiMessage$ ["FR", "Axes"] 			= "Axes"

# Chinese
uiMessage$ ["ZH", "PauseRecord"] 	= "录制连续语音"
uiMessage$ ["ZH", "Record1"] 		= "录制##连续语音#"
uiMessage$ ["ZH", "Record2"] 		= "请准备好开始"
uiMessage$ ["ZH", "Record3"] 		= "选择你想要分析的语音"
uiMessage$ ["ZH", "Open1"] 			= "打开包含语音的录音文件"
uiMessage$ ["ZH", "Open2"] 			= "选择你想要分析的语音片段"
uiMessage$ ["ZH", "Corneri"] 		= "必"
uiMessage$ ["ZH", "Corneru"] 		= "不"
uiMessage$ ["ZH", "Cornera"] 		= "巴"
uiMessage$ ["ZH", "SlopeTitle"] 	= "斜率"
uiMessage$ ["ZH", "AreaTitle"] 		= "表面积"
uiMessage$ ["ZH", "Area1"] 			= "1"
uiMessage$ ["ZH", "Area2"] 			= "2"
uiMessage$ ["ZH", "AreaN"] 			= "N"
uiMessage$ ["ZH", "Duration"] 		= "时间"
uiMessage$ ["ZH", "VTL"] 			= "声道"


uiMessage$ ["ZH", "LogFile"] 		= "将日志写入表格 (""-"" 写入信息窗口)"
uiMessage$ ["ZH", "CommentContinue"] = "点击 ""继续"" 如果你想分析更多的语音样本"
uiMessage$ ["ZH", "CommentOpen"] 	= "点击 ""打开录音"" 并选择一个录音"
uiMessage$ ["ZH", "CommentRecord"] 	= "点击 ""录音"" 并开始讲话"
uiMessage$ ["ZH", "CommentList"] 	= "录制声音, ""Save to list & Close"", 然后单击 ""继续"""
uiMessage$ ["ZH", "SavePicture"] 	= "保存图片"
uiMessage$ ["ZH", "DoContinue"] 	= "你想继续吗"
uiMessage$ ["ZH", "SelectSound1"] 	= "选择声音并继续"
uiMessage$ ["ZH", "SelectSound2"] 	= "可以从选择中删除不需要的声音"
uiMessage$ ["ZH", "SelectSound3"] 	= "选择不需要的部分，然后从 ""Edit"" 菜单选择 ""Cut"""
uiMessage$ ["ZH", "Stopped"] 		= "VowelTriangle 已停止运行"
uiMessage$ ["ZH", "ErrorSound"] 	= "错误：不是声音"
uiMessage$ ["ZH", "Nothing to do"] 	= "无法进行"
uiMessage$ ["ZH", "No readable recording selected "] = "未选择可读取的录音 "

uiMessage$ ["ZH", "Interface Language"] = "语言 (Language)"
uiMessage$ ["ZH", "Speaker is a"]	= "演讲者是"
uiMessage$ ["ZH", "Male"] 			= "男性 ♂"
uiMessage$ ["ZH", "Female"] 		= "女性 ♀"
uiMessage$ ["ZH", "Automatic"] 		= "自动选择"
uiMessage$ ["ZH", "Experimental"] 	= "试验：选择共振峰值测量方式"
uiMessage$ ["ZH", "Continue"] 		= "继续"
uiMessage$ ["ZH", "Done"] 			= "完成"
uiMessage$ ["ZH", "Stop"] 			= "结束"
uiMessage$ ["ZH", "Open"] 			= "从文件夹打开"
uiMessage$ ["ZH", "Record"] 		= "录音"
uiMessage$ ["ZH", "untitled"] 		= "无标题"
uiMessage$ ["ZH", "Title"] 			= "标题"

uiMessage$ ["ZH", "Left"] 			= "左图轴"
uiMessage$ ["ZH", "Right"] 			= "右图轴"
uiMessage$ ["ZH", "Top"] 			= "上图轴"
uiMessage$ ["ZH", "Bottom"] 		= "下图轴"
uiMessage$ ["ZH", "Axes"] 			= "绘图轴"

# Spanish
uiMessage$ ["ES", "PauseRecord"]	= "Grabar un discurso continuo"
uiMessage$ ["ES", "Record1"]		= "Guardar ##discurso continuo#"
uiMessage$ ["ES", "Record2"]		= "Por favor, prepárate para comenzar"
uiMessage$ ["ES", "Record3"]		= "Seleccione el discurso que quiere analizar"
uiMessage$ ["ES", "Open1"]			= "Abre la grabación que contiene el discurso"
uiMessage$ ["ES", "Open2"]			= "Seleccione el discurso que quiere analizar"
uiMessage$ ["ES", "Corneri"]		= "s##i#"
uiMessage$ ["ES", "Corneru"]		= "##u#so"
uiMessage$ ["ES", "Cornera"]		= "h##a#"
uiMessage$ ["ES", "SlopeTitle"]		= "Pendiente"
uiMessage$ ["ES", "AreaTitle"]		= "Superficie"
uiMessage$ ["ES", "Area1"]			= "1"
uiMessage$ ["ES", "Area2"]			= "2"
uiMessage$ ["ES", "AreaN"]			= "N"
uiMessage$ ["ES", "Duration"] 		= "duraci\o'n"
uiMessage$ ["ES", "VTL"] 			= "Tracto vocal"
                                      
uiMessage$ ["ES", "LogFile"]		= "Escribir un archivo de registro en una tabla (""-"" escribir en la ventana de información)"
uiMessage$ ["ES", "CommentContinue"]= "Haga clic en ""Continúa"" si desea analizar más muestras de voz"
uiMessage$ ["ES", "CommentOpen"]	= "Haga clic en ""Abrir"" y seleccione un registro"
uiMessage$ ["ES", "CommentRecord"]	= "Haz clic en ""Grabar"" y comienza a hablar"
uiMessage$ ["ES", "CommentList"]	= "Grabar sonido, ""Save to list & Close"", luego haga clic en ""Continúa"""
uiMessage$ ["ES", "SavePicture"]	= "Guardar imagen"
uiMessage$ ["ES", "DoContinue"]		= "¿Quieres continuar?"
uiMessage$ ["ES", "SelectSound1"]	= "Selecciona el sonido y continúa"
uiMessage$ ["ES", "SelectSound2"]	= "Es posible eliminar sonidos no deseados de la selección"
uiMessage$ ["ES", "SelectSound3"]	= "Seleccione la parte no deseada, luego elija ""Cut"" desde el menú ""Edit"""
uiMessage$ ["ES", "Stopped"]		= "VowelTriangle se ha detenido"
uiMessage$ ["ES", "ErrorSound"]		= "Error: no hay sonido"
uiMessage$ ["ES", "Nothing to do"] 	= "Nada que hacer"
uiMessage$ ["ES", "No readable recording selected "] = "No se ha seleccionado ningún registro utilizable "

uiMessage$ ["ES", "Interface Language"] = "Idioma (Language)"
uiMessage$ ["ES", "Speaker is a"]	= "El hablante es un(a)"
uiMessage$ ["ES", "Male"] 			= "Hombre ♂"
uiMessage$ ["ES", "Female"] 		= "Mujer ♀"
uiMessage$ ["ES", "Automatic"] 		= "Autoselección"
uiMessage$ ["ES", "Experimental"] 	= "Experimental: seleccione el método de seguimiento de formantes"
uiMessage$ ["ES", "Continue"]		= "Continúa"
uiMessage$ ["ES", "Done"]			= "Terminado"
uiMessage$ ["ES", "Stop"]			= "Detener"
uiMessage$ ["ES", "Open"]			= "Abrir"
uiMessage$ ["ES", "Record"]			= "Grabar"
uiMessage$ ["ES", "untitled"] 		= "no tiene título"
uiMessage$ ["ES", "Title"] 			= "Título"

uiMessage$ ["ES", "Left"] 			= "Izquierdo"
uiMessage$ ["ES", "Right"] 			= "Derecho"
uiMessage$ ["ES", "Top"] 			= "Superior"
uiMessage$ ["ES", "Bottom"] 		= "Inferior"
uiMessage$ ["ES", "Axes"] 			= "Ajes"

# Portugese
uiMessage$ ["PT", "PauseRecord"]	= "Gravar um discurso contínuo"
uiMessage$ ["PT", "Record1"]		= "Salvar ##discurso contínua#"
uiMessage$ ["PT", "Record2"]		= "Por favor, prepare-se para começar"
uiMessage$ ["PT", "Record3"]		= "Selecione o discurso que deseja analisar"
uiMessage$ ["PT", "Open1"]			= "Abra a gravação que contém o discurso"
uiMessage$ ["PT", "Open2"]			= "Selecione o discurso que deseja analisar"
uiMessage$ ["PT", "Corneri"]		= "s##i#"
uiMessage$ ["PT", "Corneru"]		= "r##u#a"
uiMessage$ ["PT", "Cornera"]		= "d##á#"
uiMessage$ ["PT", "SlopeTitle"]		= "Inclina\c,\a~o"
uiMessage$ ["PT", "AreaTitle"]		= "Superf\i'cie"
uiMessage$ ["PT", "Area1"]			= "1"
uiMessage$ ["PT", "Area2"]			= "2"
uiMessage$ ["PT", "AreaN"]			= "N"
uiMessage$ ["PT", "Duration"] 		= "Duração"
uiMessage$ ["PT", "VTL"] 			= "Trato vocal"
                                                                            
uiMessage$ ["PT", "LogFile"]		= "Escreva um arquivo de registro em uma tabela (""-"" escreva na janela de informações)"
uiMessage$ ["PT", "CommentContinue"]= "Clique em ""Continuar"" se quiser analisar mais amostras de voz"
uiMessage$ ["PT", "CommentOpen"]	= "Clique em ""Abrir"" e selecione um registro"
uiMessage$ ["PT", "CommentRecord"]	= "Clique ""Gravar"" e comece a falar "
uiMessage$ ["PT", "CommentList"]	= "Gravar som, ""Save to list & Close"", depois clique em ""Continuar"""
uiMessage$ ["PT", "SavePicture"]	= "Salvar imagem"
uiMessage$ ["PT", "DoContinue"]		= "Você quer continuar?"
uiMessage$ ["PT", "SelectSound1"]	= "Selecione o som e continue"
uiMessage$ ["PT", "SelectSound2"]	= "É possível remover sons indesejados da seleção"
uiMessage$ ["PT", "SelectSound3"]	= "Selecione a parte indesejada, então escolha ""Cut"" no menu ""Edit"""
uiMessage$ ["PT", "Stopped"]		= "VowelTriangle parou"
uiMessage$ ["PT", "ErrorSound"]		= "Erro: não há som"
uiMessage$ ["PT", "Nothing to do"] 	= "Nada para fazer"
uiMessage$ ["PT", "No readable recording selected "] = "Nenhum registro utilizável foi selecionado"

uiMessage$ ["PT", "Interface Language"] = "Idioma (Language)"
uiMessage$ ["PT", "Speaker is a"]	= "O falante é um(a)"
uiMessage$ ["PT", "Male"] 			= "Homem ♂"
uiMessage$ ["PT", "Female"] 		= "Mulher ♀"
uiMessage$ ["PT", "Automatic"] 		= "Auto-seleção"
uiMessage$ ["PT", "Experimental"] 	= "Experimental: Selecione o método de rastreamento formant"
uiMessage$ ["PT", "Continue"]		= "Continuar"
uiMessage$ ["PT", "Done"]			= "Terminado"
uiMessage$ ["PT", "Stop"]			= "Pare"
uiMessage$ ["PT", "Open"]			= "Abrir"
uiMessage$ ["PT", "Record"]			= "Gravar"
uiMessage$ ["PT", "untitled"] 		= "sem título"
uiMessage$ ["PT", "Title"] 			= "Título"

uiMessage$ ["PT", "Left"] 			= "Esquerdo"
uiMessage$ ["PT", "Right"] 			= "Direito"
uiMessage$ ["PT", "Top"] 			= "Superior"
uiMessage$ ["PT", "Bottom"] 		= "Inferior"
uiMessage$ ["PT", "Axes"] 			= "Eixos"

# Italian
uiMessage$ ["IT", "PauseRecord"]	= "Registra un discorso continuo"
uiMessage$ ["IT", "Record1"]		= "Salva ##discorso continuo#"
uiMessage$ ["IT", "Record2"]		= "Per favore, preparati a iniziare"
uiMessage$ ["IT", "Record3"]		= "Seleziona il discorso che vuoi analizzare"
uiMessage$ ["IT", "Open1"]			= "Apri la registrazione che contiene il discorso"
uiMessage$ ["IT", "Open2"]			= "Seleziona il discorso che vuoi analizzare"
uiMessage$ ["IT", "Corneri"]		= "s##ì#"
uiMessage$ ["IT", "Corneru"]		= "##u#si"
uiMessage$ ["IT", "Cornera"]		= "sar##à#"
uiMessage$ ["IT", "SlopeTitle"]		= "Pendenza"
uiMessage$ ["IT", "AreaTitle"]		= "Superficie"
uiMessage$ ["IT", "Area1"]			= "1"
uiMessage$ ["IT", "Area2"]			= "2"
uiMessage$ ["IT", "AreaN"]			= "N"
uiMessage$ ["IT", "Duration"] 		= "Durata"
uiMessage$ ["IT", "VTL"] 			= "Tratto vocale"
                                                                            
uiMessage$ ["IT", "LogFile"]		= "Scrivi un file di registrazione in una tabella (""-"" scrivi nella finestra delle informazioni)"
uiMessage$ ["IT", "CommentContinue"]= "Clicca su ""Continua"" se vuoi analizzare più campioni vocali"
uiMessage$ ["IT", "CommentOpen"]	= "Fare clic su ""Apri"" e selezionare un record"
uiMessage$ ["IT", "CommentRecord"]	= "Fai clic su ""Registra"" e inizia a parlare"
uiMessage$ ["IT", "CommentList"]	= "Registra suono, ""Save to list & Close"", quindi fai clic su ""Continua"""
uiMessage$ ["IT", "SavePicture"]	= "Salva immagine"
uiMessage$ ["IT", "DoContinue"]		= "Vuoi continuare?"
uiMessage$ ["IT", "SelectSound1"]	= "Seleziona il suono e continua"
uiMessage$ ["IT", "SelectSound2"]	= "È possibile rimuovere i suoni indesiderati dalla selezione"
uiMessage$ ["IT", "SelectSound3"]	= "Seleziona la parte indesiderata, quindi scegli ""Cut"" dal menu ""Edit"""
uiMessage$ ["IT", "Stopped"]		= "VowelTriangle si è fermato"
uiMessage$ ["IT", "ErrorSound"]		= "Errore: non c'è suono"
uiMessage$ ["IT", "Nothing to do"] 	= "Niente da fare"
uiMessage$ ["IT", "No readable recording selected "] = "Nessun record utilizzabile è stato selezionato "

uiMessage$ ["IT", "Interface Language"] = "Lingua (Language)"
uiMessage$ ["IT", "Speaker is a"]	= "L‘oratore è un(a)"
uiMessage$ ["IT", "Male"] 			= "Uomo ♂"
uiMessage$ ["IT", "Female"] 		= "Donna ♀"
uiMessage$ ["IT", "Automatic"] 		= "Auto-selezione"
uiMessage$ ["IT", "Experimental"] 	= "Sperimentale: seleziona il metodo di tracciamento dei formanti"
uiMessage$ ["IT", "Continue"]		= "Continua"
uiMessage$ ["IT", "Done"]			= "Finito"
uiMessage$ ["IT", "Stop"]			= "Fermare"
uiMessage$ ["IT", "Open"]			= "Apri"
uiMessage$ ["IT", "Record"]			= "Registra"
uiMessage$ ["IT", "untitled"] 		= "senza titolo"
uiMessage$ ["IT", "Title"] 			= "Titolo"

uiMessage$ ["IT", "Left"] 			= "Sinistro"
uiMessage$ ["IT", "Right"] 			= "Destro"
uiMessage$ ["IT", "Top"] 			= "Superiore"
uiMessage$ ["IT", "Bottom"] 		= "Inferiore"
uiMessage$ ["IT", "Axes"] 			= "Assi"

endproc


###########################################################################
#                                                                         #
#  Praat Script Syllable Nuclei                                           #
#  Copyright (C) 2008  Nivja de Jong and Ton Wempe                        #
#                                                                         #
#    This program is free software: you can redistribute it and/or modify #
#    it under the terms of the GNU General Public License as published by #
#    the Free Software Foundation, either version 3 of the License, or    #
#    (at your option) any later version.                                  #
#                                                                         #
#    This program is distributed in the hope that it will be useful,      #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of       #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the        #
#    GNU General Public License for more details.                         #
#                                                                         #
#    You should have received a copy of the GNU General Public License    #
#    along with this program.  If not, see http://www.gnu.org/licenses/   #
#                                                                         #
###########################################################################
#
# modified 2020.01.27 by Rob van Son
# Updated to Praat 6.1.06
# Converted to a procedure
#
#
# modified 2010.09.17 by Hugo Quené, Ingrid Persoon, & Nivja de Jong
# Overview of changes:
# + change threshold-calculator: rather than using median, use the almost maximum
#     minus 25dB. (25 dB is in line with the standard setting to detect silence
#     in the "To TextGrid (silences)" function.
#     Almost maximum (.99 quantile) is used rather than maximum to avoid using
#     irrelevant non-speech sound-bursts.
# + add silence-information to calculate articulation rate and ASD (average syllable
#     duration.
#     NB: speech rate = number of syllables / total time
#         articulation rate = number of syllables / phonation time
# + remove max number of syllable nuclei
# + refer to objects by unique identifier, not by name
# + keep track of all created intermediate objects, select these explicitly,
#     then Remove
# + provide summary output in Info window
# + do not save TextGrid-file but leave it in Object-window for inspection
#     (if requested in startup-form)
# + allow Sound to have starting time different from zero
#      for Sound objects created with Extract (preserve times)
# + programming of checking loop for mindip adjusted
#      in the orig version, precedingtime was not modified if the peak was rejected !!
#      var precedingtime and precedingint renamed to .currenttime and .currentint
#
# + bug fixed concerning summing total pause, feb 28th 2011
# 
###########################################################################


# counts syllables of all sound utterances in a directory
# NB unstressed syllables are sometimes overlooked
# NB filter sounds that are quite noisy beforehand
# NB use Silence threshold (dB) = -25 (or -20?)
# NB use Minimum .dip between peaks (dB) = between 2-4 (you can first try;
#                                                      For clean and filtered: 4)

procedure syllable_nuclei .soundid
   
   # use object ID
   selectObject: .soundid
   .soundname$ = selected$("Sound")
   .originaldur = Get total duration
   # allow non-zero starting time
   bt = Get starting time

   # Use intensity to get threshold
   .intid = nocheck noprogress nowarn To Intensity: 50, 0, "yes"
   start = Get time from frame number: 1
   nframes = Get number of frames
   end = Get time from frame number: nframes

   # estimate noise floor
   minint = Get minimum: 0, 0, "Parabolic"
   # estimate noise max
   maxint = Get maximum: 0, 0, "Parabolic"
   #get .99 quantile to get maximum (without influence of non-speech sound bursts)
   max99int = Get quantile: 0, 0, 0.99

   # estimate Intensity threshold
   threshold = max99int + silencedb
   threshold2 = maxint - max99int
   threshold3 = silencedb - threshold2
   if threshold < minint
       threshold = minint
   endif

   # get pauses (silences) and speakingtime
   .textgridid = nocheck noprogress nowarn To TextGrid (silences): threshold3, minpause, 0.1, "silent", "sounding"
   .silencetierid = Extract tier: 1
   .silencetableid = Down to TableOfReal... sounding
   nsounding = Get number of rows
   .npauses = 'nsounding'
   .speakingtot = 0
   for ipause from 1 to .npauses
      beginsound = Get value... 'ipause' 1
      endsound = Get value... 'ipause' 2
      speakingdur = 'endsound' - 'beginsound'
      .speakingtot = 'speakingdur' + '.speakingtot'
   endfor

   selectObject: .intid
   Down to Matrix
   .matid = selected("Matrix")
   # Convert intensity to sound
   .sndintid = nocheck noprogress nowarn To Sound (slice): 1

   # use total duration, not end time, to find out duration of .intdur
   # in order to allow nonzero starting times.
   .intdur = Get total duration
   intmax = Get maximum... 0 0 Parabolic

   # estimate peak positions (all peaks)
   .ppid = nocheck noprogress nowarn To PointProcess (extrema)... Left yes no Sinc70

   numpeaks = Get number of points

   # fill array with time points
   for .i from 1 to numpeaks
       t'.i' = Get time from index... '.i'
   endfor

   # fill array with intensity values
   selectObject: .sndintid
   .peakcount = 0
   for .i from 1 to numpeaks
       value = Get value at time... t'.i' Cubic
       if value > threshold
             .peakcount += 1
             int'.peakcount' = value
             .timepeaks'.peakcount' = t'.i'
       endif
   endfor

   # fill array with valid peaks: only intensity values if preceding
   # .dip in intensity is greater than mindip
   select '.intid'
   .validpeakcount = 0
   .currenttime = .timepeaks1
   .currentint = int1

   for .p to .peakcount-1
      .following = .p + 1
      .followingtime = .timepeaks'.following'
      .dip = Get minimum... '.currenttime' '.followingtime' None
      .diffint = abs(.currentint - .dip)

      if .diffint > mindip
         .validpeakcount += 1
         validtime'.validpeakcount' = .timepeaks'.p'
      endif
         .currenttime = .timepeaks'.following'
         .currentint = Get value at time... .timepeaks'.following' Cubic
   endfor

   # Look for only voiced parts
   selectObject: .soundid
   .pitchid = nocheck noprogress nowarn To Pitch (ac): 0.02, 30, 4, "no", 0.03, 0.25, 0.01, 0.35, 0.25, 450

   .voicedcount = 0   
   for .i from 1 to .validpeakcount
      .querytime = validtime'.i'

      select '.textgridid'
      .whichinterval = Get interval at time... 1 '.querytime'
      .whichlabel$ = Get label of interval... 1 '.whichinterval'

      select '.pitchid'
      value = Get value at time... '.querytime' Hertz Linear

      if value <> undefined
         if .whichlabel$ = "sounding"
             .voicedcount = .voicedcount + 1
             voicedpeak'.voicedcount' = validtime'.i'
         endif
      endif
   endfor
   
  
   # calculate time correction due to shift in time for Sound object versus
   # intensity object
   .timecorrection = .originaldur/.intdur

   # Insert voiced peaks in TextGrid
   if showtext > 0
      select '.textgridid'
      Insert point tier... 1 syllables
     
      for .i from 1 to .voicedcount
          position = voicedpeak'.i' * .timecorrection
          Insert point... 1 position '.i'
      endfor
   endif

   # clean up before next sound file is opened
    selectObject: .intid, .matid, .sndintid, .ppid, .pitchid, .silencetierid, .silencetableid
    Remove
    if showtext < 1
       selectObject: .soundid, .textgridid
       Remove
       .soundid = -1
       .textgridid = -1
    endif

	# summarize results in Info window
   .speakingrate = .voicedcount/.originaldur
   .articulationrate = .voicedcount/.speakingtot
   .npause = .npauses-1
   .asd = .speakingtot/.voicedcount
endproc


# 
#######################################################################
# 
# Retrieve last saved settings
# 
#######################################################################
#
procedure retrieve_settings
	.defaultLanguage = 1
	.preferencesLanguageFile$ = preferencesDirectory$+"/Pitch_and_Intensity.prefs"
	.preferencesLang$ = ""
	.silence_Threshold = -25
	.minimum_dip = 2
	.minimum_pause = 0.3
	.normalize_intensity = 1
	.scale_default = 4

	if fileReadable(.preferencesLanguageFile$)
		.preferences$ = readFile$(.preferencesLanguageFile$)
		if index(.preferences$, "Language=") > 0
			.preferencesLang$ = extractWord$(.preferences$, "Language=")
			if .preferencesLang$ = "EN"
				.defaultLanguage = 1
			elsif .preferencesLang$ = "NL"
				.defaultLanguage = 2
			elsif .preferencesLang$ = "DE"
				.defaultLanguage = 3
			elsif .preferencesLang$ = "FR"
				.defaultLanguage = 4
			elsif .preferencesLang$ = "ZH"
				.defaultLanguage = 5
			elsif .preferencesLang$ = "ES"
				.defaultLanguage = 6
			elsif .preferencesLang$ = "PT"
				.defaultLanguage = 7
			elsif .preferencesLang$ = "IT"
				.defaultLanguage = 8
			# elsif .preferencesLang$ = "MY LANG"
			#	.defaultLanguage = 9
			endif
		else
			.preferencesLang$ = ""
			.defaultLanguage = 1
		endif
		
		# Silence_threshold
		if index(.preferences$, "Silence threshold=") > 0
			.silence_Threshold = extractNumber(.preferences$, "Silence threshold=")
		else
			.silence_Threshold = -25
		endif
		
		# Minimum_dip
		if index(.preferences$, "Minimum dip=") > 0
			.minimum_dip = extractNumber(.preferences$, "Minimum dip=")
		else
			.minimum_dip = 2
		endif
		
		# Minimum_pause
		if index(.preferences$, "Minimum pause=") > 0
			.minimum_pause = extractNumber(.preferences$, "Minimum pause=")
		else
			.minimum_pause = 0.3
		endif
		
		# Normalize_intensity
		if index(.preferences$, "Normalize intensity=") > 0
			.normalize_intensity = extractNumber(.preferences$, "Normalize intensity=")
		else
			.normalize_intensity = 1
		endif
		
		# Always assume that the preferences file could be corrupted
		if index(.preferences$, "Scale=") > 0
			.tmp$ = extractWord$(.preferences$, "Scale=")
			if index(.tmp$, "Hz")
				.scale_default = 1
			elsif index(.tmp$, "Mel")
				.scale_default = 2
			elsif index(.tmp$, "Bark")
				.scale_default = 3
			elsif index(.tmp$, "Semitones")
				.scale_default = 4
			endif
		else
			.scale_default = 4
		endif

	endif
endproc

procedure write_settings .silence_Threshold .minimum_dip .minimum_pause .normalize_intensity .scale$
	# Store preferences
	.preferencesLanguageFile$ = preferencesDirectory$+"/Pitch_and_Intensity.prefs"
	writeFileLine: .preferencesLanguageFile$, "Language=", uiLanguage$
	appendFileLine: .preferencesLanguageFile$, "Silence threshold=", .silence_Threshold
	appendFileLine: .preferencesLanguageFile$, "Minimum dip=", .minimum_dip
	appendFileLine: .preferencesLanguageFile$, "Minimum pause=", .minimum_pause
	appendFileLine: .preferencesLanguageFile$, "Normalize intensity=", .normalize_intensity
	appendFileLine: .preferencesLanguageFile$, "Scale=", .scale$
endproc
