####################################################################################################
# i3dPDK NS3K v1.1 milkyway technology file                                                        #
# Author:          Prof. Taigon Song (I3D VLSI Lab, KNU)                                           #
# drawing grid:    0.0001 microns                                                                  #
#                                                                                                  #
# Revision History:                                                                                #
# Rev.     date           what                                                                     #
# -------------------------------------------------------------------------------------            #
# 1.1.0    17/Sep/2026     (Initial Release) First official release for 3nm i3dPDK.                 #
#                         Configured for GAAFET technology node.                                   #
#                                                                                                  #
####################################################################################################

Technology {
  name = "i3dPDK_NS3K"
  date = "Sep 17 2026"
  unitTimeName = "ns"
  timePrecision = 1000
  unitLengthName = "micron"
  lengthPrecision = 1000
  unitVoltageName = "V"
  voltagePrecision = 1000000
  unitCurrentName = "ma"
  unitPowerName = "mw"
  powerPrecision = 100000
  gridResolution = 1
  currentPrecision = 1000
  unitResistanceName = "kohm"
  resistancePrecision = 10000000
  unitCapacitanceName = "pf"
  capacitancePrecision = 10000000
  unitInductanceName = "nh"
  inductancePrecision = 100
  minEdgeMode = 1
}

Color		6 {
		name				= "6"
		rgbDefined			= 1
		redIntensity			= 0
		greenIntensity			= 80
		blueIntensity			= 190
}

Color		8 {
		name				= "8"
		rgbDefined			= 1
		redIntensity			= 0
		greenIntensity			= 175
		blueIntensity			= 0
}

Color		10 {
		name				= "10"
		rgbDefined			= 1
		redIntensity			= 0
		greenIntensity			= 175
		blueIntensity			= 190
}

Color		11 {
		name				= "11"
		rgbDefined			= 1
		redIntensity			= 0
		greenIntensity			= 175
		blueIntensity			= 255
}

Color		13 {
		name				= "13"
		rgbDefined			= 1
		redIntensity			= 0
		greenIntensity			= 255
		blueIntensity			= 100
}

Color		20 {
		name				= "20"
		rgbDefined			= 1
		redIntensity			= 90
		greenIntensity			= 80
		blueIntensity			= 0
}

Color		23 {
		name				= "23"
		rgbDefined			= 1
		redIntensity			= 90
		greenIntensity			= 80
		blueIntensity			= 255
}

Color		25 {
		name				= "25"
		rgbDefined			= 1
		redIntensity			= 90
		greenIntensity			= 175
		blueIntensity			= 100
}

Color		27 {
		name				= "27"
		rgbDefined			= 1
		redIntensity			= 90
		greenIntensity			= 175
		blueIntensity			= 255
}

Color		28 {
		name				= "28"
		rgbDefined			= 1
		redIntensity			= 90
		greenIntensity			= 255
		blueIntensity			= 0
}

Color		31 {
		name				= "31"
		rgbDefined			= 1
		redIntensity			= 90
		greenIntensity			= 255
		blueIntensity			= 255
}

Color		32 {
		name				= "32"
		rgbDefined			= 1
		redIntensity			= 180
		greenIntensity			= 0
		blueIntensity			= 0
}

Color		34 {
		name				= "34"
		rgbDefined			= 1
		redIntensity			= 180
		greenIntensity			= 0
		blueIntensity			= 190
}

Color		35 {
		name				= "35"
		rgbDefined			= 1
		redIntensity			= 180
		greenIntensity			= 0
		blueIntensity			= 255
}

Color		36 {
		name				= "36"
		rgbDefined			= 1
		redIntensity			= 180
		greenIntensity			= 80
		blueIntensity			= 0
}

Color		38 {
		name				= "38"
		rgbDefined			= 1
		redIntensity			= 180
		greenIntensity			= 80
		blueIntensity			= 190
}

Color		40 {
		name				= "40"
		rgbDefined			= 1
		redIntensity			= 180
		greenIntensity			= 175
		blueIntensity			= 0
}

Color		43 {
		name				= "43"
		rgbDefined			= 1
		redIntensity			= 180
		greenIntensity			= 175
		blueIntensity			= 255
}

Color		44 {
		name				= "44"
		rgbDefined			= 1
		redIntensity			= 180
		greenIntensity			= 255
		blueIntensity			= 0
}

Color		47 {
		name				= "47"
		rgbDefined			= 1
		redIntensity			= 180
		greenIntensity			= 255
		blueIntensity			= 255
}

Color		50 {
		name				= "50"
		rgbDefined			= 1
		redIntensity			= 255
		greenIntensity			= 0
		blueIntensity			= 190
}

Color		51 {
		name				= "ltGreen"
		rgbDefined			= 1
		redIntensity			= 0
		greenIntensity			= 240
		blueIntensity			= 110
}

Color		52 {
		name				= "52"
		rgbDefined			= 1
		redIntensity			= 255
		greenIntensity			= 80
		blueIntensity			= 0
}

Color		54 {
		name				= "54"
		rgbDefined			= 1
		redIntensity			= 255
		greenIntensity			= 80
		blueIntensity			= 190
}

Color		58 {
		name				= "58"
		rgbDefined			= 1
		redIntensity			= 255
		greenIntensity			= 175
		blueIntensity			= 190
}

Color		59 {
		name				= "59"
		rgbDefined			= 1
		redIntensity			= 255
		greenIntensity			= 175
		blueIntensity			= 255
}

Color		62 {
		name				= "62"
		rgbDefined			= 1
		redIntensity			= 255
		greenIntensity			= 255
		blueIntensity			= 190
}

Stipple		"twelldot" {
		width			= 16
		height			= 16
		pattern			= (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0) 
}

Stipple		"welldot" {
		width			= 16
		height			= 16
		pattern			= (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0) 
}

Stipple		"impdot" {
		width			= 16
		height			= 16
		pattern			= (1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
					   1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1) 
}

Stipple		"hidot" {
		width			= 16
		height			= 16
		pattern			= (1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 
					   0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
					   1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 
					   0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
					   1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 
					   0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
					   1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 
					   0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
					   1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 
					   0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
					   1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 
					   0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
					   1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 
					   0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
					   1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 
					   0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1) 
}

Stipple		"rhidot" {
		width			= 16
		height			= 16
		pattern			= (0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
					   1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 
					   0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
					   1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 
					   0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
					   1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 
					   0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
					   1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 
					   0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
					   1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 
					   0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
					   1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 
					   0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
					   1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 
					   0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 
					   1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0) 
}

Tile		"i3d_nsfet3nm" {
		width				= 0.044 
		height				= 0.12  
}

Layer           "M0" {
                layerNumber                     = 84
                maskName                        = "metal0"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "silver"
                lineStyle                       = "solid"
                pattern                         = "slash"
                nonPreferredRouteMode           = 1
                pitch                           = 0.024
                defaultWidth   		        = 0.012
                minWidth                        = 0.012
                maxWidth                        = 5 
                minSpacing                      = 0.012
                minArea                         = 0.000144 
}


Layer		"VIA0" {
		layerNumber			= 85
		maskName			= "via0"
		isDefaultLayer			= 1
		visible				= 1
		selectable			= 1
		blink				= 0
		color				= "purple"
		lineStyle			= "solid"
		pattern				= "rectangleX"
		defaultWidth			= 0.01
		minWidth			= 0.01 
		minSpacing			= 0.01
}

Layer		"M1" {
		layerNumber			= 11
		isDefaultLayer			= 1
		maskName			= "metal1"
		visible				= 1
		selectable			= 1
		blink				= 0
		color				= "blue"
		lineStyle			= "solid"
		pattern				= "impdot"
                nonPreferredRouteMode           = 1
		pitch				= 0.044 
		minWidth			= 0.016 
		defaultWidth			= 0.016 
		maxWidth			= 5
		minSpacing			= 0.008
		minArea 			= 0.000256
}

Layer		"VIA1" {
		layerNumber			= 12
		maskName			= "via1"
		isDefaultLayer			= 1
		visible				= 1
		selectable			= 1
		blink				= 0
		color				= "cyan"
		lineStyle			= "solid"
		pattern				= "rectangleX"
		defaultWidth			= 0.01
		minWidth			= 0.01 
		minSpacing			= 0.01
}

Layer		"M2" {
		layerNumber			= 13
		maskName			= "metal2"
		isDefaultLayer			= 1
		visible				= 1
		selectable			= 1
		blink				= 0
		color				= "50"
		lineStyle			= "solid"
		pattern				= "twelldot"
                nonPreferredRouteMode           = 1
		pitch				= 0.024
		defaultWidth			= 0.012 
		minWidth			= 0.012 
		maxWidth			= 5
		minSpacing			= 0.012
		minArea 			= 0.000144
}

Layer           "VIA2" {
                layerNumber                     = 14
                maskName                        = "via2"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "yellow"
                lineStyle                       = "solid"
                pattern                         = "rectangleX"
                defaultWidth                    = 0.01 
                minWidth                        = 0.01 
                minSpacing                      = 0.01
}

Layer           "M3" {
                layerNumber                     = 15
                maskName                        = "metal3"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "38"
                lineStyle                       = "solid"
                pattern                         = "hidot"
                nonPreferredRouteMode           = 1
                pitch                           = 0.022
                defaultWidth                    = 0.012 
                minWidth                        = 0.012 
                maxWidth                        = 5
                minSpacing                      = 0.01
                minArea                         = 0.000144
}

Layer           "VIA3" {
                layerNumber                     = 16
                maskName                        = "via3"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "27"
                lineStyle                       = "solid"
                pattern                         = "rectangleX"
                defaultWidth                    = 0.01 
                minWidth                        = 0.01 
                minSpacing                      = 0.01 
}

Layer           "M4" {
                layerNumber                     = 17
                maskName                        = "metal4"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "green"
                lineStyle                       = "solid"
                pattern                         = "rhidot"
                nonPreferredRouteMode           = 1
                pitch                           = 0.024
                defaultWidth                    = 0.012 
                minWidth                        = 0.012 
                maxWidth                        = 5
                minSpacing                      = 0.012
                minArea                         = 0.000144
}

Layer           "VIA4" {
                layerNumber                     = 18
                maskName                        = "via4"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "orange"
                lineStyle                       = "solid"
                pattern                         = "rectangleX"
                defaultWidth                    = 0.01 
                minWidth                        = 0.01 
                minSpacing                      = 0.01 
}

Layer           "M5" {
                layerNumber                     = 19
                maskName                        = "metal5"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "aqua"
                lineStyle                       = "solid"
                pattern                         = "welldot"
                nonPreferredRouteMode           = 1
                pitch                           = 0.044 
                defaultWidth                    = 0.022 
                minWidth                        = 0.022 
                maxWidth                        = 5
                minSpacing                      = 0.022
                minArea                         = 0.000484
}

Layer           "VIA5" {
                layerNumber                     = 20
                maskName                        = "via5"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "40"
                lineStyle                       = "solid"
                pattern                         = "rectangleX"
                defaultWidth                    = 0.02 
                minWidth                        = 0.02 
                minSpacing                      = 0.02 
}

Layer           "M6" {
                layerNumber                     = 21
                maskName                        = "metal6"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "58"
                lineStyle                       = "solid"
                pattern                         = "impdot"
                nonPreferredRouteMode           = 1
                pitch                           = 0.048 
                defaultWidth                    = 0.024 
                minWidth                        = 0.024 
                maxWidth                        = 5
                minSpacing                      = 0.024
                minArea                         = 0.000576
}

Layer           "VIA6" {
                layerNumber                     = 22
                maskName                        = "via6"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "52"
                lineStyle                       = "solid"
                pattern                         = "rectangleX"
                defaultWidth                    = 0.02 
                minWidth                        = 0.02 
                minSpacing                      = 0.02 
}

Layer           "M7" {
                layerNumber                     = 23
                maskName                        = "metal7"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "cyan"
                lineStyle                       = "solid"
                pattern                         = "solid"
                nonPreferredRouteMode           = 1
                pitch                           = 0.064
                defaultWidth                    = 0.032
                minWidth                        = 0.032
                maxWidth                        = 5
                minSpacing                      = 0.032
                minArea                         = 0.001024
}
Layer           "VIA7" {
                layerNumber                     = 24
                maskName                        = "via7"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "blue"
                lineStyle                       = "solid"
                pattern                         = "rectangleX"
                defaultWidth                    = 0.030
                minWidth                        = 0.030
                minSpacing                      = 0.030
}

Layer           "M8" {
                layerNumber                     = 25
                maskName                        = "metal8"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "43"
                lineStyle                       = "solid"
                pattern                         = "solid"
                nonPreferredRouteMode           = 1
                pitch                           = 0.072
                defaultWidth                    = 0.036 
                minWidth                        = 0.036 
                maxWidth                        = 5
                minSpacing                      = 0.036 
                minArea                         = 0.001296
}

Layer           "VIA8" {
                layerNumber                     = 26
                maskName                        = "via8"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "drab"
                lineStyle                       = "solid"
                pattern                         = "rectangleX"
                defaultWidth                    = 0.031 
                minWidth                        = 0.031 
                minSpacing                      = 0.031 
}

Layer           "M9" {
                layerNumber                     = 27
                maskName                        = "metal9"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "59"
                lineStyle                       = "solid"
                pattern                         = "solid"
                nonPreferredRouteMode           = 1
                pitch                           = 0.088
                defaultWidth                    = 0.044 
                minWidth                        = 0.044 
                maxWidth                        = 5
                minSpacing                      = 0.044 
                minArea                         = 0.001936
}

Layer           "VIA9" {
                layerNumber                     = 98
                maskName                        = "via9"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "23"
                lineStyle                       = "solid"
                pattern                         = "rectangleX"
                defaultWidth                    = 0.042 
                minWidth                        = 0.042 
                minSpacing                      = 0.042 
}

Layer           "M10" {
                layerNumber                     = 99
                maskName                        = "metal10"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "32"
                lineStyle                       = "solid"
                pattern                         = "solid"
                nonPreferredRouteMode           = 1
                pitch                           = 0.096
                defaultWidth                    = 0.048 
                minWidth                        = 0.048 
                maxWidth                        = 5
                minSpacing                      = 0.048 
                minArea                         = 0.002304
}

Layer           "VIA10" {
                layerNumber                     = 100
                maskName                        = "via10"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "54"
                lineStyle                       = "solid"
                pattern                         = "rectangleX"
                defaultWidth                    = 0.042
                minWidth                        = 0.042 
                minSpacing                      = 0.042 
}

Layer           "M11" {
                layerNumber                     = 101
                maskName                        = "metal11"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "38"
                lineStyle                       = "solid"
                pattern                         = "solid"
                nonPreferredRouteMode           = 1
                pitch                           = 0.11
                defaultWidth                    = 0.056 
                minWidth                        = 0.056 
                maxWidth                        = 5
                minSpacing                      = 0.056 
                minArea                         = 0.003136
}

Layer           "VIA11" {
                layerNumber                     = 102
                maskName                        = "via11"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "36"
                lineStyle                       = "solid"
                pattern                         = "rectangleX"
                defaultWidth                    = 0.054 
                minWidth                        = 0.054
                minSpacing                      = 0.054 
}

Layer           "M12" {
                layerNumber                     = 103
                maskName                        = "metal12"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "47"
                lineStyle                       = "solid"
                pattern                         = "solid"
                nonPreferredRouteMode           = 1
                pitch                           = 0.12
                defaultWidth                    = 0.06 
                minWidth                        = 0.06 
                maxWidth                        = 5
                minSpacing                      = 0.06 
                minArea                         = 0.0036
}

Layer "M13" {
                layerNumber                     = 104
                maskName                        = "metal13"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "60"
                lineStyle                       = "solid"
                pattern                         = "solid"
                nonPreferredRouteMode           = 1
                pitch                           = 0.132
                defaultWidth                    = 0.066 
                minWidth                        = 0.066 
                maxWidth                        = 5
                minSpacing                      = 0.066 
                minArea                         = 0.004356
}

Layer "M14" {
                layerNumber                     = 105
                maskName                        = "metal14"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "61"
                lineStyle                       = "solid"
                pattern                         = "solid"
                nonPreferredRouteMode           = 1
                pitch                           = 0.144
                defaultWidth                    = 0.072 
                minWidth                        = 0.072 
                maxWidth                        = 5
                minSpacing                      = 0.072 
                minArea                         = 0.005184
}

Layer "M15" {
                layerNumber                     = 106
                maskName                        = "metal15"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "62"
                lineStyle                       = "solid"
                pattern                         = "solid"
                nonPreferredRouteMode           = 1
                pitch                           = 0.176
                defaultWidth                    = 0.088 
                minWidth                        = 0.088 
                maxWidth                        = 5
                minSpacing                      = 0.088 
                minArea                         = 0.007744
}

Layer "M16" {
                layerNumber                     = 107
                maskName                        = "metal16"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "63"
                lineStyle                       = "solid"
                pattern                         = "solid"
                nonPreferredRouteMode           = 1
                pitch                           = 0.192
                defaultWidth                    = 0.096 
                minWidth                        = 0.096 
                maxWidth                        = 5
                minSpacing                      = 0.096 
                minArea                         = 0.009216
}

Layer "VIA12" {
                layerNumber                     = 108
                maskName                        = "via12"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "64"
                lineStyle                       = "solid"
                pattern                         = "rectangleX"
                defaultWidth                    = 0.053 
                minWidth                        = 0.053
                minSpacing                      = 0.053 
}

Layer "VIA13" {
                layerNumber                     = 109
                maskName                        = "via13"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "65"
                lineStyle                       = "solid"
                pattern                         = "rectangleX"
                defaultWidth                    = 0.064 
                minWidth                        = 0.064
                minSpacing                      = 0.064 
}

Layer "VIA14" {
                layerNumber                     = 110
                maskName                        = "via14"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "66"
                lineStyle                       = "solid"
                pattern                         = "rectangleX"
                defaultWidth                    = 0.064 
                minWidth                        = 0.064
                minSpacing                      = 0.064 
}

Layer "VIA15" {
                layerNumber                     = 111
                maskName                        = "via15"
                isDefaultLayer                  = 1
                visible                         = 1
                selectable                      = 1
                blink                           = 0
                color                           = "67"
                lineStyle                       = "solid"
                pattern                         = "rectangleX"
                defaultWidth                    = 0.064 
                minWidth                        = 0.064
                minSpacing                      = 0.064 
}

ContactCode     "VIA01" {
                contactCodeNumber               = 69
                cutLayer                        = "VIA0"
                lowerLayer                      = "M0"
                upperLayer                      = "M1"
                isDefaultContact                = 1
                cutWidth                        = 0.01
                cutHeight                       = 0.01
                minCutSpacing                   = 0.01
                upperLayerEncWidth              = 0.003
                upperLayerEncHeight             = 0.003
                lowerLayerEncWidth              = 0.001
                lowerLayerEncHeight             = 0.001
}

ContactCode	"VIA12" {
		contactCodeNumber		= 5
		cutLayer			= "VIA1"
		lowerLayer			= "M1"
		upperLayer			= "M2"
		isDefaultContact		= 1
		cutWidth			= 0.01 
		cutHeight			= 0.01 
		minCutSpacing			= 0.01 
		upperLayerEncWidth		= 0.001
		upperLayerEncHeight		= 0.001 
		lowerLayerEncWidth		= 0.003
		lowerLayerEncHeight		= 0.003 
}

ContactCode     "VIA23" {
                contactCodeNumber               = 13
                cutLayer                        = "VIA2"
                lowerLayer                      = "M2"
                upperLayer                      = "M3"
                isDefaultContact                = 1
                cutWidth                        = 0.01 
                cutHeight                       = 0.01 
                minCutSpacing                   = 0.01 
                upperLayerEncWidth              = 0.001
                upperLayerEncHeight             = 0.001
                lowerLayerEncWidth              = 0.001
                lowerLayerEncHeight             = 0.001
}

ContactCode     "VIA34" {
                contactCodeNumber               = 21
                cutLayer                        = "VIA3"
                lowerLayer                      = "M3"
                upperLayer                      = "M4"
                isDefaultContact                = 1
                cutWidth                        = 0.01 
                cutHeight                       = 0.01
                minCutSpacing                   = 0.01 
                upperLayerEncWidth              = 0.001
                upperLayerEncHeight             = 0.001
                lowerLayerEncWidth              = 0.001
                lowerLayerEncHeight             = 0.001
}

ContactCode     "VIA45" {
                contactCodeNumber               = 29
                cutLayer                        = "VIA4"
                lowerLayer                      = "M4"
                upperLayer                      = "M5"
                isDefaultContact                = 1
                cutWidth                        = 0.01 
                cutHeight                       = 0.01 
                minCutSpacing                   = 0.01 
                upperLayerEncWidth              = 0.006
                upperLayerEncHeight             = 0.006
                lowerLayerEncWidth              = 0.001
                lowerLayerEncHeight             = 0.001
}

ContactCode     "VIA56" {
                contactCodeNumber               = 37
                cutLayer                        = "VIA5"
                lowerLayer                      = "M5"
                upperLayer                      = "M6"
                isDefaultContact                = 1
                cutWidth                        = 0.02 
                cutHeight                       = 0.02 
                minCutSpacing                   = 0.02 
                upperLayerEncWidth              = 0.002
                upperLayerEncHeight             = 0.002
                lowerLayerEncWidth              = 0.001
                lowerLayerEncHeight             = 0.001
}

ContactCode     "VIA67" {
                contactCodeNumber               = 45
                cutLayer                        = "VIA6"
                lowerLayer                      = "M6"
                upperLayer                      = "M7"
                isDefaultContact                = 1
                cutWidth                        = 0.02 
                cutHeight                       = 0.02 
                minCutSpacing                   = 0.02 
                upperLayerEncWidth              = 0.006
                upperLayerEncHeight             = 0.006
                lowerLayerEncWidth              = 0.002
                lowerLayerEncHeight             = 0.002
}

ContactCode     "VIA78" {
                contactCodeNumber               = 53
                cutLayer                        = "VIA7"
                lowerLayer                      = "M7"
                upperLayer                      = "M8"
                isDefaultContact                = 1
                cutWidth                        = 0.031  
                cutHeight                       = 0.031  
                minCutSpacing                   = 0.031  
                upperLayerEncWidth              = 0.002
                upperLayerEncHeight             = 0.002
                lowerLayerEncWidth              = 0.001
                lowerLayerEncHeight             = 0.001
}

ContactCode     "VIA89" {
                contactCodeNumber               = 61
                cutLayer                        = "VIA8"
                lowerLayer                      = "M8"
                upperLayer                      = "M9"
                isDefaultContact                = 1
                cutWidth                        = 0.031  
                cutHeight                       = 0.031 
                minCutSpacing                   = 0.031  
                upperLayerEncWidth              = 0.006
                upperLayerEncHeight             = 0.006
                lowerLayerEncWidth              = 0.002
                lowerLayerEncHeight             = 0.002
}

ContactCode     "VIA910" {
                contactCodeNumber               = 77
                cutLayer                        = "VIA9"
                lowerLayer                      = "M9"
                upperLayer                      = "M10"
                isDefaultContact                = 1
                cutWidth                        = 0.042  
                cutHeight                       = 0.042 
                minCutSpacing                   = 0.042  
                upperLayerEncWidth              = 0.003
                upperLayerEncHeight             = 0.003
                lowerLayerEncWidth              = 0.001
                lowerLayerEncHeight             = 0.001
}

ContactCode     "VIA1011" {
                contactCodeNumber               = 85
                cutLayer                        = "VIA10"
                lowerLayer                      = "M10"
                upperLayer                      = "M11"
                isDefaultContact                = 1
                cutWidth                        = 0.042  
                cutHeight                       = 0.042 
                minCutSpacing                   = 0.042  
                upperLayerEncWidth              = 0.006
                upperLayerEncHeight             = 0.006
                lowerLayerEncWidth              = 0.003
                lowerLayerEncHeight             = 0.003
}

ContactCode     "VIA1112" {
                contactCodeNumber               = 93
                cutLayer                        = "VIA11"
                lowerLayer                      = "M11"
                upperLayer                      = "M12"
                isDefaultContact                = 1
                cutWidth                        = 0.053  
                cutHeight                       = 0.053 
                minCutSpacing                   = 0.053  
                upperLayerEncWidth              = 0.003
                upperLayerEncHeight             = 0.003
                lowerLayerEncWidth              = 0.001
                lowerLayerEncHeight             = 0.001
}

ContactCode "via1213" {
                contactCodeNumber               = 112
                cutLayer                        = "VIA12"
                lowerLayer                      = "M12"
                upperLayer                      = "M13"
                isDefaultContact                = 1
                cutWidth                        = 0.053  
                cutHeight                       = 0.053 
                minCutSpacing                   = 0.053  
                upperLayerEncWidth              = 0.006
                upperLayerEncHeight             = 0.006
                lowerLayerEncWidth              = 0.003
                lowerLayerEncHeight             = 0.003
}

ContactCode "via1314" {
                contactCodeNumber               = 113
                cutLayer                        = "VIA13"
                lowerLayer                      = "M13"
                upperLayer                      = "M14"
                isDefaultContact                = 1
                cutWidth                        = 0.064  
                cutHeight                       = 0.064 
                minCutSpacing                   = 0.064  
                upperLayerEncWidth              = 0.004
                upperLayerEncHeight             = 0.004
                lowerLayerEncWidth              = 0.001
                lowerLayerEncHeight             = 0.001
}

ContactCode "via1415" {
                contactCodeNumber               = 114
                cutLayer                        = "VIA14"
                lowerLayer                      = "M14"
                upperLayer                      = "M15"
                isDefaultContact                = 1
                cutWidth                        = 0.064  
                cutHeight                       = 0.064 
                minCutSpacing                   = 0.064  
                upperLayerEncWidth              = 0.012
                upperLayerEncHeight             = 0.012
                lowerLayerEncWidth              = 0.004
                lowerLayerEncHeight             = 0.004
}

ContactCode "via1516" {
                contactCodeNumber               = 115
                cutLayer                        = "VIA15"
                lowerLayer                      = "M15"
                upperLayer                      = "M16"
                isDefaultContact                = 1
                cutWidth                        = 0.064  
                cutHeight                       = 0.064 
                minCutSpacing                   = 0.064  
                upperLayerEncWidth              = 0.016
                upperLayerEncHeight             = 0.016
                lowerLayerEncWidth              = 0.012
                lowerLayerEncHeight             = 0.012
}


PRRule		{
		rowSpacingTopTop		= 0.067
		rowSpacingTopBot		= 0.033
		rowSpacingBotBot		= 0.067
		abuttableTopTop			= 1
		abuttableTopBot			= 0
		abuttableBotBot			= 1
}


