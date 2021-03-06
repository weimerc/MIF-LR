extensions [ nw ]

globals [ clusters cluster-ops infs ]

turtles-own [ opinion next-opinion ]

;;;;; SETUP ;;;;;

to setup
  clear-all
  set infs [1]
  setup-turtles
  reset-ticks
  setup-plot
end

to setup-turtles
  set-default-shape turtles "dot"
  ifelse SWN? [ ; generate small-world network using Watts-Strogatz method
    nw:generate-watts-strogatz turtles links N num-neighbors p-rewire [
      set size 0.5
      fd min list max-pxcor max-pycor
      initialize-turtle
    ]
  ] [ ; else, don't bother with links
    create-turtles N [
      set size 0.5
      set heading (who / N) * 359
      fd min list max-pxcor max-pycor
      initialize-turtle
    ]
  ]
end

to initialize-turtle
  if init-dist = "Uniform" [set next-opinion random-float 1]
  if init-dist = "Normal" [set next-opinion random-normal 0.5 Std-Dev]
  update-opinion
end

to setup-plot
  set-current-plot "Opinion over time"
  ask turtles [
    create-temporary-plot-pen word "Turtle " who
    set-plot-pen-color color
  ]
  ask turtles [ update-plot ]
end

;;;;; GO ;;;;;

to go
  set infs []
  let prim-actors ifelse-value (num-prim-actors >= N) [ turtles ] [ n-of num-prim-actors turtles ]
  ask prim-actors [
    be-influenced
  ]
  if synchrony = "Synchronous" [ ask prim-actors [ update-opinion ] ]
  tick
  if op-plot? [ if ticks mod update-freq = 0 [ ask turtles [ update-plot ] ] ]
end

;;;;; PROCEDURES ;;;;;

;; OBSERVER PROCEDURES ;;

to draw-force-curve
  set-current-plot "Force curve"
  clear-plot
  foreach range 101 [ [x] ->
    let ops [opinion] of turtles
    let y (influence-MIF (x / 100) ops)
    set-current-plot-pen  "default"
    plotxy (x / 100) y
    set-current-plot-pen "zero"
    plotxy (x / 100) 0
  ]
end

to draw-D-curve
  set-current-plot "Desirability curve"
  clear-plot
  let ops [opinion] of turtles
  let P map [ [x] -> desirability (x / 100) ops ] range 101
  let min-P (floor (1000 * min P)) / 1000
  let max-P (ceiling (1000 * max P)) / 1000
  set-plot-y-range min-P max-P
  let x 0
  set-current-plot-pen  "default"
  foreach P [ [y] ->
    plotxy x y
    set x (x + 0.01)
  ]
  set-plot-x-range 0 1
end

;; TURTLE PROCEDURES ;;

to update-plot
  set-current-plot "Opinion over time"
  set-current-plot-pen word "Turtle " who
  plotxy ticks opinion
end

to update-opinion
  if next-opinion > 1 [ set next-opinion 1 ]
  if next-opinion < 0 [ set next-opinion 0 ]
  set infs lput abs (next-opinion - opinion) infs
  set opinion next-opinion
  set color hsb (260 * opinion + 5) 100 100
end

to be-influenced
  let ops get-ops
  let influence get-influence ops
  set next-opinion next-opinion + influence
  if synchrony = "Asynchronous" [ update-opinion ]
end

;;;;; FUNCTIONS ;;;;;

;; OBSERVER FUNCTIONS ;;

to-report membership [x xi] ; mu(x,x_i) in Salzarulo (2006)
  ;; Note: this assumes agents are unaware of group membership (may not be appropriate in all cases)
  let w group-width
  report exp (- ((x - xi) ^ 2 / (w ^ 2)))
end

to-report saturation [x xi] ; same as membership but different value for w
  let v repulse-range * group-width
  report exp (- ((x - xi) ^ 2 / (v ^ 2)))
end

to-report desirability [ x ops ]
  let a outgroup-aversion
  let w group-width
  let v repulse-range * w

  let mus map [[xi] -> membership x xi] ops

  let diffs2 map [[y] -> (x - item y ops) ^ 2 ] range length ops
  let summus sum mus ; sum(mu(x,xi))
  let diff2mus sum map [[y] -> (item y mus) * (item y diffs2)] range length ops; sum((x-xi)^2 mu(x,xi))
  let dintra ifelse-value (summus = 0) [0] [-1 * diff2mus / summus]

  let lambda (w ^ 2) / ((exp 1) - (exp (1 - (1 / (w ^ 2)))))
  let diff2mus2 sum map [[y] -> (1 - item y mus) * (item y diffs2)] range length ops; sum((x-xi)^2 (1-mu(x,xi)))
  let summus2 (length ops) - summus ; sum(1-mu(x,xi))
  let dinter lambda * ifelse-value (summus2 = 0) [0] [diff2mus2 / summus2]

  let gamma (w ^ 2) / exp(1)
  let sats map [[xi] -> saturation x xi] ops
  let sumsats sum sats
  let dindiv (1 - a) * b * (w ^ 2) / (exp 1) * ifelse-value (summus = 0) [0] [-1 * sumsats / summus]

  let P (a * dinter) + ((1 - a) * (1 - b) * dintra) + ((1 - a) * b * dindiv)
  report P
end

to-report D-deriv [ x ops ]
  let a outgroup-aversion
  let w group-width
  let v repulse-range * w

  let mus map [[xi] -> membership x xi] ops
  let summus sum mus ; sum(mu(x,xi))
  let diffs map [[xi] -> x - xi] ops
  let diffmus sum map [[y] -> (item y mus) * (item y diffs)] range length ops ; sum((x-xi)mu(x,xi))
  let diffs2 map [[y] -> (item y diffs) ^ 2 ] range length ops
  let diff2mus sum map [[y] -> (item y mus) * (item y diffs2)] range length ops; sum((x-xi)^2 mu(x,xi))
  let diffs3 map [[y] -> (item y diffs) ^ 3 ] range length ops
  let diff3mus sum map [[y] -> (item y mus) * (item y diffs3)] range length ops; sum((x-xi)^3 mu(x,xi))
  let ddintradx ifelse-value ((w * summus) ^ 2 = 0) [0] [(-2 * (((((w ^ 2) * diffmus) - diff3mus) / ((w ^ 2) * summus)) + ((diff2mus * diffmus) / ((w * summus) ^ 2))))]

  let summus2 (length ops) - summus ; sum(1-mu(x,xi)) = n - sum(mu(x,xi))
  let diffmus2 sum map [[y] -> (1 - item y mus) * (item y diffs)] range length ops ; sum((x-xi)(1-mu(x,xi)))
  let diff2mus2 sum map [[y] -> (1 - item y mus) * (item y diffs2)] range length ops; sum((x-xi)^2 (1-mu(x,xi)))
  let lambda (w ^ 2) / ((exp 1) - (exp (1 - (1 / (w ^ 2)))))
  let ddinterdx lambda * ifelse-value ((w * summus2) ^ 2 = 0) [0] [2 * (((((w ^ 2) * diffmus2) + diff3mus) / ((w ^ 2) * summus2)) - ((diff2mus2 * diffmus) / ((w * summus2) ^ 2)))]

  let sats map [[xi] -> (saturation x xi)] ops
  let sumsats sum sats
  let diffsats sum map [[y] -> (item y sats) * (item y diffs)] range length ops ; sum ((x-xi)mu*(x,xi))
  let ddindivdx (w ^ 2) / exp(1) * ifelse-value ((w * summus) ^ 2 = 0) [0] [-2 * ((diffmus * sumsats / ((w ^ 2) * (summus ^ 2))) - (diffsats / ((v ^ 2) * summus)))] ; THIS WORKS

  let dDdx (a * ddinterdx) + ((1 - a) * (1 - b) * ddintradx) + ((1 - a) * b * ddindivdx)
  report dDdx
end

to-report influence-MIF [ x ops ] ; converts P-deriv to actual influence value
  let influence (D-deriv x ops)
  set influence k * influence
  report influence
end

to-report skewness [ xlist ] ; reports skewness of a distribution
  let len length xlist
  let xbar mean xlist
  let skew (sum map [ [x] -> (x - xbar) ^ 3 ] xlist) / ( len * (((len - 1) / len) * variance xlist) ^ 1.5)
  report skew
end

to-report kurtosis [ xlist ] ; reports kurtosis of a distribution
  let len length xlist
  let xbar mean xlist
  let kurt (sum map [ [x] -> (x - xbar) ^ 4 ] xlist) / ( len * (((len - 1) / len) * variance xlist) ^ 2)
  report kurt
end

;; TURTLE FUNCTIONS ;;

to-report get-ops ; gets appropriate opinions, based on setting of SWN?
  let ops []
  ifelse SWN? [ set ops [opinion] of (turtle-set link-neighbors self) ] [ set ops [opinion] of turtles ]
  report ops
end

to-report get-influence [ ops ] ; gets appropriate influence value. Added to increase modularity.
  let influence (influence-MIF opinion ops)
  report influence
end
@#$#@#$#@
GRAPHICS-WINDOW
414
296
737
620
-1
-1
15.0
1
10
1
1
1
0
0
0
1
-10
10
-10
10
1
1
1
ticks
30.0

TEXTBOX
9
18
87
36
Model Controls:
11
0.0
1

BUTTON
93
10
157
43
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
177
10
240
43
Step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
240
10
303
43
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

TEXTBOX
45
64
85
82
Agents:
11
0.0
1

SLIDER
93
56
235
89
N
N
100
1000
1000.0
100
1
agents
HORIZONTAL

TEXTBOX
3
110
85
128
Agent Schedule:
11
0.0
1

SLIDER
190
103
333
136
num-prim-actors
num-prim-actors
1
N
1000.0
1
1
= t
HORIZONTAL

TEXTBOX
35
178
80
196
Network:
11
0.0
1

SWITCH
93
170
190
203
SWN?
SWN?
0
1
-1000

SLIDER
190
155
333
188
num-neighbors
num-neighbors
1
(N / 2) - 1
8.0
1
1
= c
HORIZONTAL

SLIDER
190
187
333
220
p-rewire
p-rewire
0
1
0.4
0.01
1
NIL
HORIZONTAL

TEXTBOX
118
278
213
296
Model Parameters:
11
0.0
1

SLIDER
13
299
164
332
group-width
group-width
0.01
1
0.18
0.01
1
= w
HORIZONTAL

SLIDER
13
332
164
365
outgroup-aversion
outgroup-aversion
0
1
0.0
0.01
1
= a
HORIZONTAL

PLOT
345
10
899
289
Opinion over Time
updates
opinion
0.0
10.0
0.0
1.0
true
false
"" ""
PENS

PLOT
21
412
394
621
Distribution of opinions
opinion
frequency
0.0
1.01
0.0
10.0
true
false
"" ""
PENS
"default" 0.0505 1 -16777216 true "" "if ticks > 0 [ histogram [opinion] of turtles ]"

SWITCH
777
289
899
322
op-plot?
op-plot?
0
1
-1000

SLIDER
777
322
899
355
update-freq
update-freq
1
100
1.0
1
1
ticks
HORIZONTAL

CHOOSER
92
103
190
148
synchrony
synchrony
"Synchronous" "Asynchronous"
0

SLIDER
13
365
164
398
k
k
0.001
1
0.2
0.001
1
NIL
HORIZONTAL

PLOT
913
10
1258
241
Force curve
NIL
NIL
0.0
1.0
-1.0E-4
1.0E-4
true
false
"" ""
PENS
"default" 1.0 0 -13345367 true "" ""
"zero" 1.0 0 -16777216 true "" ""

BUTTON
1268
113
1395
146
Draw force curve
draw-force-curve
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
174
332
331
365
repulse-range
repulse-range
0.05
1
0.25
0.05
1
= v
HORIZONTAL

PLOT
913
250
1258
481
Desirability curve
NIL
NIL
0.0
1.0
-3.0E-4
-2.0E-4
true
false
"" ""
PENS
"default" 1.0 0 -13345367 true "" ""
"zero" 1.0 0 -16777216 true "" ""

BUTTON
1266
338
1389
371
Draw desirability
draw-D-curve
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
174
365
331
398
b
b
0
1
0.5
0.05
1
NIL
HORIZONTAL

TEXTBOX
17
235
81
253
Initialization:
11
0.0
1

CHOOSER
92
228
190
273
init-dist
init-dist
"Uniform" "Normal"
0

SLIDER
194
239
335
272
Std-Dev
Std-Dev
0.05
1
0.2
0.05
1
NIL
HORIZONTAL

TEXTBOX
198
226
245
244
If normal:
9
0.0
1

TEXTBOX
920
490
1258
518
Curves above are drawn for a fully connected (non-SWN) population
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="base-experiment" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2000"/>
    <metric>sort [opinion] of turtles</metric>
    <metric>12 * (N - 1) / N * variance [opinion] of turtles</metric>
    <metric>skewness [opinion] of turtles</metric>
    <metric>kurtosis [opinion] of turtles</metric>
    <enumeratedValueSet variable="p-rewire">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-neighbors">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="outgroup-aversion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="group-width">
      <value value="0.12"/>
      <value value="0.15"/>
      <value value="0.23"/>
      <value value="0.45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-prim-actors">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SWN?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="synchrony">
      <value value="&quot;Synchronous&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-freq">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="op-plot?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="repulse-range">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-dist">
      <value value="&quot;Uniform&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Std-Dev">
      <value value="0.2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Normal-experiment" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2000"/>
    <metric>sort [opinion] of turtles</metric>
    <metric>12 * (N - 1) / N * variance [opinion] of turtles</metric>
    <metric>skewness [opinion] of turtles</metric>
    <metric>kurtosis [opinion] of turtles</metric>
    <enumeratedValueSet variable="num-neighbors">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-dist">
      <value value="&quot;Normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Std-Dev">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="group-width">
      <value value="0.12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-freq">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="p-rewire">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="outgroup-aversion">
      <value value="0"/>
      <value value="0.25"/>
      <value value="0.5"/>
      <value value="0.75"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-prim-actors">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SWN?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="synchrony">
      <value value="&quot;Synchronous&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="op-plot?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="repulse-range">
      <value value="0.25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Normal-experiment2" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2000"/>
    <metric>sort [opinion] of turtles</metric>
    <metric>12 * (N - 1) / N * variance [opinion] of turtles</metric>
    <metric>skewness [opinion] of turtles</metric>
    <metric>kurtosis [opinion] of turtles</metric>
    <enumeratedValueSet variable="num-neighbors">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-dist">
      <value value="&quot;Normal&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Std-Dev" first="0.05" step="0.05" last="0.25"/>
    <enumeratedValueSet variable="group-width">
      <value value="0.12"/>
      <value value="0.15"/>
      <value value="0.23"/>
      <value value="0.45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-freq">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="p-rewire">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="outgroup-aversion">
      <value value="0"/>
      <value value="0.25"/>
      <value value="0.5"/>
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-prim-actors">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SWN?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="synchrony">
      <value value="&quot;Synchronous&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="op-plot?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="repulse-range">
      <value value="0.25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="b-vary" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3000"/>
    <metric>sort [opinion] of turtles</metric>
    <metric>12 * (N - 1) / N * variance [opinion] of turtles</metric>
    <metric>skewness [opinion] of turtles</metric>
    <metric>kurtosis [opinion] of turtles</metric>
    <enumeratedValueSet variable="num-neighbors">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-dist">
      <value value="&quot;Uniform&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Std-Dev">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="group-width">
      <value value="0.12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-freq">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b">
      <value value="0"/>
      <value value="0.25"/>
      <value value="0.5"/>
      <value value="0.75"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="p-rewire">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="outgroup-aversion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-prim-actors">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SWN?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="synchrony">
      <value value="&quot;Synchronous&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="op-plot?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="repulse-range">
      <value value="0.25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="p-vary" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2000"/>
    <metric>sort [opinion] of turtles</metric>
    <metric>12 * (N - 1) / N * variance [opinion] of turtles</metric>
    <metric>skewness [opinion] of turtles</metric>
    <metric>kurtosis [opinion] of turtles</metric>
    <enumeratedValueSet variable="num-neighbors">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-dist">
      <value value="&quot;Uniform&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Std-Dev">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="group-width">
      <value value="0.18"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-freq">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="p-rewire">
      <value value="0"/>
      <value value="0.05"/>
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.25"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="outgroup-aversion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-prim-actors">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SWN?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="synchrony">
      <value value="&quot;Synchronous&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="op-plot?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="repulse-range">
      <value value="0.25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="fullconnect" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2000"/>
    <exitCondition>max infs &lt; 0.001</exitCondition>
    <metric>sort [opinion] of turtles</metric>
    <metric>12 * (N - 1) / N * variance [opinion] of turtles</metric>
    <metric>skewness [opinion] of turtles</metric>
    <metric>kurtosis [opinion] of turtles</metric>
    <enumeratedValueSet variable="num-neighbors">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-dist">
      <value value="&quot;Uniform&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Std-Dev">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="group-width">
      <value value="0.12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-freq">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="p-rewire">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="outgroup-aversion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="N">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-prim-actors">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SWN?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="synchrony">
      <value value="&quot;Synchronous&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="op-plot?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="repulse-range">
      <value value="0.25"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
