;; 1) DICHIARAZIONI GLOBALI E DI BREED
globals [
  spark-frequency
  iterations
]

patches-own [
  altitude
  temperature
]
trees-own [
  burning-speed spark-probability
  is-burning is-burnt
  kind ticks-since-spark
]
sparks-own [final-xcor final-ycor]
fires-own [life-in-ticks]
;; … altri patches-own e trees-own …

breed [ sparks spark ]
breed [ trees tree ]
breed [ fires fire ]
breed [bears bear]
breed [mooses moose]

bears-own[stato]
  ;caratteristiche degli orsi:
  ;stato: stato del movimento dell'orso
  ; 0- relax status: l'orso si muove in modo randomico
  ; 1- escape status: l'orso, una volta essersi accorto del fatto che ci sia un incendio vero e
  ; proprio in corso, scappa
  ; 2- fire status: l'orso ha preso fuoco e sta ora bruciando
  ; 3- dead status: l'orso è morto
mooses-own[stato]
  ;caratteristiche dei cervi:
  ;stato: stato del movimento dell'orso
  ; 0- relax status: il cervo si muove in modo randomico
  ; 1- alert status: il cervo si accorge di un potenziale pericolo quando percepisce un possibile
  ; incendio ad una certa distanza, inizia a muoversi più cautamente
  ; 2- escape status: il cervo, una volta essersi accorto del fatto che ci sia un incendio vero e
  ; proprio in corso, scappa
  ; 3- fire status: il cervo ha preso fuoco e sta ora bruciando
  ; 4- dead status: il cervo è morto
to setup
  ;; associa le forme che hai importato/incollato
 set-default-shape bears "bear"
 set-default-shape mooses "moose"

  ;; crea gli agenti in numero pari al valore dei due slider

end


;; 2) Reporter per l’altitudine
to-report calc-altitude [ x ]
  ;; Esempio di profilo altimetrico: più ti sposti in x,
  ;; più l’altitudine aumenta
  report 0.1 * x + 5
end

;; 3) Procedure principali
to import-background
  import-pcolors "img/terra.png"
end

to create-forest
  ;; ----------------------------------------------------------
  ;; 0. reset e setup base
  ;; ----------------------------------------------------------
  clear-all
  set spark-frequency 300
  set-default-shape bears  "bear"
  set-default-shape mooses "moose"

  ;; ----------------------------------------------------------
  ;; 1. terreno + alberi
  ;; ----------------------------------------------------------
  ask patches [
    set pcolor 33
    set altitude calc-altitude pxcor
    set temperature initial-temperature
  ]
  random-seed forest-seed
  ask patches with [ random-float 100 < forest-density ] [
    plant-tree pxcor pycor
  ]

  ;; ----------------------------------------------------------
  ;; 2. orsi neri – mai sovrapposti
  ;; ----------------------------------------------------------
ask n-of num-bears patches
        with [ abs pxcor <= 17 and abs pycor <= 17 ] [
  sprout-bears 1 [ set color black ]
]

  ;; ----------------------------------------------------------
  ;; 3. calcola le taglie dei branchi (2-4, niente solitari)
  ;; ----------------------------------------------------------
  let gruppi []
  let remaining num-mooses
  while [ remaining > 0 ] [
    let g 2 + random 3              ;; 2,3,4
    if remaining - g = 1 [ set g g + 1 ]  ;; evita resto 1
    if g > remaining [ set g remaining ]
    set gruppi lput g gruppi
    set remaining remaining - g
  ]

  ;; ----------------------------------------------------------
  ;; 4. genera i branchi, senza sovrapposizioni
  ;; ----------------------------------------------------------
  foreach gruppi [ bsize ->            ;; ‹bsize› NON è 'size'

    ;; patch “centro-branco” libero
    let centro one-of patches with [ not any? turtles-here ]

    ask centro [
      let r 1                ;; raggio di ricerca
      let fatti 0            ;; cervi creati finora

      while [ fatti < bsize ] [
        ;; cerca un patch libero entro r; se pieno, allarga r
        let sede nobody
        while [ sede = nobody ] [
          set sede one-of (patches in-radius r) with [ not any? turtles-here ]
          if sede = nobody [ set r r + 1 ]
        ]

        ;; crea un cervo bianco sulla sede trovata
        ask sede [
          sprout-mooses 1 [ set color white ]
        ]
        set fatti fatti + 1
      ]
    ]
  ]

  ;; ----------------------------------------------------------
  ;; 5. via!
  ;; ----------------------------------------------------------
  reset-ticks
end




to-report random-tree-type
  let tree-types ["oak-tree" "pine-tree"]
  report one-of tree-types
end

to plant-tree [x y]
  let th 1
  set x (random-pcor x th "x")
  set y (random-pcor y th "y")
  let tree-type random-tree-type
  sprout-trees 1 [
    setxy x y
    set color green
    set shape tree-type
    set kind tree-type
    set is-burning false
    set is-burnt false
    ifelse tree-type = "pine-tree" [
      set burning-speed 0.075
      set spark-probability 0.15
    ] [
      set burning-speed 0.025
      set spark-probability 0.05
    ]
  ]
end

to-report random-pcor [pcor th dir]
  let min-pcor min-pxcor
  let max-pcor max-pxcor
  if dir = "y" [
    set min-pcor min-pycor
    set max-pcor max-pycor
  ]
  set pcor pcor + (random-float th) - th
  set pcor median (list min-pcor pcor max-pcor)
  report pcor
end

to go
  ; stop running if no tree is burning
  if not any? (turtle-set trees with [is-burning] sparks) [
    stop
  ]
  ask trees with [is-burning] [
    let fire-altitude [altitude] of patch-here
    ; spread fire if tree is yellow
    if color < yellow [
      ask neighbors with [any? trees-here] [ spread-fire fire-altitude ]
    ]
    ; create sparks
    if color < brown [
      ifelse random-float 1 < spark-probability
      and ticks-since-spark > spark-frequency [
        ask patch-here [
          sprout-sparks 1 [
            set shape "fire"
            set size 0.7
            set final-xcor (spark-final-cor pxcor "x")
            set final-ycor (spark-final-cor pycor "y")
            facexy final-xcor final-ycor
          ]
        ]
        set ticks-since-spark 0
      ] [ set ticks-since-spark ticks-since-spark + 1 ]
    ]
  ]
  ; move sparks
  ask sparks [
    ifelse (distancexy final-xcor final-ycor) > 0.1 [
      fd 0.1
    ] [
        ask patch-here [ ignite ]
        die
    ]
  ]
  ; 'kill' fire turtles, to not block the view
  ask fires [
    set life-in-ticks life-in-ticks - 1
    if life-in-ticks <= 0 [ die ]
  ]
  ; burn trees
  fade-embers
  go-bears
  ;go-mooses
  tick
end

to start-fire
  let fire-started false
  while [not fire-started] [
    ask n-of 1 patches [ ignite ]
    if count fires > 0 [ set fire-started true ]
  ]
  random-seed new-seed
end

to spread-fire [fire-altitude]
  let probability spread-probability
  ; compute the direction from you (the green tree) to the burning tree
  let direction towards myself
  if direction = 0 [
    set probability probability - north-wind-speed
  ]
  if direction = 90 [
    set probability probability - east-wind-speed
  ]
  if direction = 180 [
    set probability probability + north-wind-speed
  ]
  ; burning tree is west -> the west wind aids the spread
  if direction = 270 [
    set probability probability + east-wind-speed
  ]
  ; increase probability according to temperature
  let mean-temp (mean [temperature] of neighbors)
  set probability probability + (ln (mean-temp + 1)) ^ 2
  ; keep probability within boundaries
  set probability median (list 0 probability 100)
  ; decrease probability if fire is at lower altitude
  let altitude-diff fire-altitude - altitude
    if altitude-diff > 0 [
    set probability probability * (1 + abs (tan inclination / 3))
  ]
  ; ignite if probable
  if random 100 < probability [
    ignite
  ]
end


to ignite
  sprout-fires 1 [
    set shape "fire"
    set size 2
    let green-trees trees-here with [not (is-burning or is-burnt)]
    ifelse any? green-trees [
      set life-in-ticks 10
    ] [ die ]
    ask green-trees [
      set is-burning true
    ]
  ]
end

to fade-embers
  ask trees with [is-burning] [
    set color color - burning-speed  ;; make red darker
    ask patch-here [ set temperature temperature + 1 ]
    ask neighbors [ set temperature temperature + 0.25 ]
    if color < red - 3.5 [ ;; are we almost at black?
      ask patch-here [
        set pcolor 2
      ]
      set is-burning false
      set is-burnt true
      set shape "charred-ground"
    ]
  ]
end

to go-bears
  ask bears[
    set shape "bear"
    if abs pxcor >= 20 or abs pycor >= 20 [
      set hidden? true
      set stato 99            ;; per non rieseguirne il codice
      stop
    ]
    if stato = 0 [set color black]
    if stato = 0 [
      rt random-int-between -15 15
      fd 0.005
      ; controllo sul fuoco
      if any? fires in-radius 10 [
        set stato 1
      ]

    ]
    ; ;; STATO 1: Escape – corri sempre in avanti,
    ;; e ricalcola la direzione solo se trovi un fuoco
    if stato = 1 [
      set color orange
      let vxf 0
      let vyf 0

      ask trees with [is-burning] in-radius 10 [
        let dx1 ([xcor] of myself) - xcor
        let dy1 ([ycor] of myself) - ycor
        let d  distance myself
        if d > 0 [
          set vxf vxf + dx1 / (d * d)
          set vyf vyf + dy1 / (d * d)
        ]
      ]

      if vxf != 0 or vyf != 0 [
        facexy (xcor + vxf) (ycor + vyf)
      ]
      ;; corri sempre avanti, anche se nf = nobody
      fd 0.01


      if any? trees with [is-burning] in-radius 5 [
        set stato 2
      ]
      if not any? trees with [is-burning] in-radius 12 [
        set stato 0
      ]

    ]
    ;; ------------- STATO 2 : orso in fiamme (rosso) -------------
    if stato = 2 [
      set color red

      ;; ----------------------------------------------------------
      ;; 1. direzione di fuga = somma dei vettori repulsivi
      ;;    di tutti gli alberi in fiamme entro 15 patch
      ;; ----------------------------------------------------------
      let vxf 0
      let vyf 0

      ask trees with [is-burning] in-radius 10 [
        let dx2 ([xcor] of myself) - xcor
        let dy2 ([ycor] of myself) - ycor
        let d  distance myself
        if d > 0 [
          set vxf vxf + dx2 / (d * d)
          set vyf vyf + dy2 / (d * d)
        ]
      ]

      if vxf != 0 or vyf != 0 [
        facexy (xcor + vxf) (ycor + vyf)
      ]

      ;; ----------------------------------------------------------
      ;; 2. avanza (un po’ più veloce che nello stato 1)
      ;; ----------------------------------------------------------
      fd 0.025

      ;; ----------------------------------------------------------
      ;; 3. cambi di stato
      ;; ----------------------------------------------------------
      ;; se un albero in fiamme è a ≤ 3 patch → stato 3
      if any? trees with [is-burning] in-radius 3 [
        set stato 3
      ]

      ;; se NON c’è alcun albero in fiamme entro 7 patch → torna a stato 1
      if not any? trees with [is-burning] in-radius 7 [
        set stato 1
      ]
    ]

    ;; ------------- STATO 3 : quasi morto (violet) -------------
    if stato = 3 [
      set color violet

      ;; 1. direzione di fuga = somma dei vettori repulsivi
      let vxf 0
      let vyf 0

      ask trees with [is-burning] in-radius 10 [
        let dx3 ([xcor] of myself) - xcor
        let dy3 ([ycor] of myself) - ycor
        let d  distance myself
        if d > 0 [
          set vxf vxf + dx3 / (d * d)
          set vyf vyf + dy3 / (d * d)
        ]
      ]

      if vxf != 0 or vyf != 0 [
        facexy (xcor + vxf) (ycor + vyf)
      ]

      ;; 2. avanzamento
      fd 0.03

      ;; 3. cambi di stato
      ;;    • fuoco vicinissimo (≤ 1.5) → stato 4
      if any? trees with [is-burning] in-radius 1.5 [
        set stato 4
      ]
      ;;    • nessun fuoco entro 5 → torna a stato 2
      if not any? trees with [is-burning] in-radius 5 [
        set stato 2
      ]
    ]


    ;; STATO 4: Dead – l’orso è morto
    if stato = 4 [
      set heading 0
      set color grey
      set size 1.5
      set shape "tombstone"

    ]
  ]

end


to-report spark-final-cor [pcor dir]
  let wind-speed east-wind-speed
  let min-pcor min-pxcor
  let max-pcor max-pxcor
  if dir = "y" [
    set wind-speed north-wind-speed
    set min-pcor min-pycor
    set max-pcor max-pycor
  ]
  set wind-speed (round wind-speed / 2)
  set pcor pcor + wind-speed
  set pcor median (list min-pcor pcor max-pcor)
  report pcor
end

; Function to pick a random integer in a range
to-report random-int-between [ min-num max-num ]
  report random (max-num  - min-num) + min-num
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
744
545
-1
-1
12.85
1
10
1
1
1
0
0
0
1
-20
20
-20
20
1
1
1
ticks
30.0

BUTTON
19
62
122
95
Create Forest
create-forest
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
18
104
190
137
forest-density
forest-density
1
100
65.0
1
1
NIL
HORIZONTAL

BUTTON
19
19
100
52
Start Fire
start-fire
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
18
152
190
185
spread-probability
spread-probability
1
100
70.0
1
1
%
HORIZONTAL

SLIDER
21
200
193
233
east-wind-speed
east-wind-speed
-25
25
-25.0
1
1
p/t
HORIZONTAL

SLIDER
15
252
187
285
north-wind-speed
north-wind-speed
-25
25
-25.0
1
1
p/t
HORIZONTAL

SLIDER
15
299
187
332
inclination
inclination
-60
60
30.0
1
1
°
HORIZONTAL

BUTTON
116
19
179
52
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
1

SLIDER
15
352
187
385
initial-temperature
initial-temperature
0
45
20.0
1
1
NIL
HORIZONTAL

SLIDER
15
404
187
437
forest-seed
forest-seed
0
500
369.0
1
1
NIL
HORIZONTAL

SLIDER
16
455
188
488
num-bears
num-bears
0
50
49.0
1
1
NIL
HORIZONTAL

SLIDER
17
507
189
540
num-mooses
num-mooses
0
150
84.0
1
1
NIL
HORIZONTAL

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

bear
false
14
Polygon -16777216 true true 195 181 180 196 165 196 166 178 151 148 151 163 136 178 61 178 45 196 30 196 16 178 16 163 1 133 16 103 46 88 106 73 166 58 225 60 240 75 240 90 240 90 255 105 241 118 226 118 211 133
Rectangle -16777216 true true 165 195 180 225
Rectangle -16777216 true true 30 195 45 225
Polygon -16777216 true true 0 165 0 135 15 135 0 165
Polygon -16777216 true true 195 225 180 210 180 225 195 225 255 240
Polygon -16777216 true true 45 210 60 225 45 225

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

charred-ground
false
0
Polygon -2674135 true false 0 240 45 195 75 180 90 165 90 135 45 120 0 135
Polygon -2674135 true false 300 240 285 210 270 180 270 150 300 135 300 225
Polygon -6459832 true false 225 300 240 270 270 255 285 255 300 285 300 300
Polygon -6459832 true false 0 285 30 300 0 300
Polygon -2674135 true false 225 0 210 15 210 30 255 60 285 45 300 30 300 0
Polygon -2674135 true false 0 30 30 0 0 0
Polygon -6459832 true false 15 30 75 0 180 0 195 30 225 60 210 90 135 60 45 60
Polygon -6459832 true false 0 105 30 105 75 120 105 105 90 75 45 75 0 60
Polygon -6459832 true false 300 60 240 75 255 105 285 120 300 105
Polygon -2674135 true false 120 75 120 105 105 135 105 165 165 150 240 150 255 135 240 105 210 105 180 90 150 75
Polygon -6459832 true false 75 300 135 285 195 300
Polygon -2674135 true false 30 285 75 285 120 270 150 270 150 210 90 195 60 210 15 255
Polygon -6459832 true false 180 285 240 255 255 225 255 195 240 165 195 165 150 165 135 195 165 210 165 255

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

fire
false
0
Polygon -2674135 true false 151 286 134 282 103 282 59 248 40 210 32 157 37 108 68 146 71 109 83 72 111 27 127 55 148 11 167 41 180 112 195 57 217 91 226 126 227 203 256 156 256 201 238 263 213 278 183 281
Polygon -955883 true false 126 284 91 251 85 212 91 168 103 132 118 153 125 181 135 141 151 96 185 161 195 203 193 253 164 286
Polygon -2674135 true false 155 284 172 268 172 243 162 224 148 201 130 233 131 260 135 282

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

moose
false
3
Polygon -6459832 true true 196 228 198 297 180 297 178 244 166 213 136 213 106 213 79 227 73 259 50 257 49 229 38 197 26 168 26 137 46 120 101 122 147 102 181 111 217 121 256 136 294 151 286 169 256 169 241 198 211 188
Polygon -6459832 true true 74 258 87 299 63 297 49 256
Polygon -6459832 true true 25 135 15 186 10 200 23 217 25 188 35 141
Polygon -6459832 true true 270 150 253 100 231 94 213 100 208 135
Polygon -6459832 true true 225 120 204 66 207 29 185 56 178 27 171 59 150 45 165 90
Polygon -6459832 true true 225 120 249 61 241 31 265 56 272 27 280 59 300 45 285 90

oak-tree
false
5
Circle -10899396 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -10899396 true true 65 21 108
Circle -10899396 true true 116 41 127
Circle -10899396 true true 45 90 120
Circle -10899396 true true 104 74 152

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

pine-tree
false
5
Rectangle -6459832 true false 120 225 180 300
Polygon -10899396 true true 150 240 240 270 150 135 60 270
Polygon -10899396 true true 150 75 75 210 150 195 225 210
Polygon -10899396 true true 150 7 90 157 150 142 210 157 150 7

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

tombstone
true
0
Rectangle -7500403 true true 45 225 255 240
Rectangle -7500403 true true 60 210 240 225
Polygon -7500403 true true 75 210 75 210 75 90 105 60 195 60 225 90 225 210 75 210
Rectangle -16777216 true false 375 105 405 210
Rectangle -16777216 true false 105 105 195 135
Rectangle -16777216 true false 135 75 165 195
Rectangle -14835848 true false -15 255 0 270
Rectangle -13840069 true false -90 240 -45 270
Rectangle -10899396 true false -30 240 0 270

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
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
