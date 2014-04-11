Websocket GUI plugin for HEX
============================

# To run

copy (and modify) the priv/hex_wse to a location where your
web server may find the hex_wse.html page. The page reference
canvas.js and wse.js they also need to be copied to that location.
canvas.js is currently in priv/canvas.js but wse.js is found in
the wse project wse/priv/wse.js.

Currently the port is hardwired to 1234 but that will change 
very soon. This is just a peek preview release.

# Input events

    [{type,button},{id,a},{text,"Press"},{x,1},{y,1}]

    [{type,button},{id,c},{image,"but.png"},{x,40},{y,40}]

# Output events

    [{type,rectangle},{id,r},{x,0},{y,50},{width,64},{height,64},
     {fill, solid}, {color, 16#ffff00ff}]
