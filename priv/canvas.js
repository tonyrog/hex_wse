//
//  Canvas wrapper class
// 

/* Canvas stuff */
function CanvasClass(element, double_buffer) {
    var canvas = window.document.getElementById(element);
    if (double_buffer == undefined) double_buffer = true;

    if (canvas) {
	this.canvas   = canvas;
	this.ctx      = canvas.getContext('2d');
	this.double_buffer = double_buffer;
	if (double_buffer) {
	    this.canvas2 = document.createElement('canvas');
	    this.canvas2.width = canvas.width;
	    this.canvas2.height = canvas.height;
	    this.ctx2 = this.ctx;                  // the original context
	    this.ctx  = this.canvas2.getContext('2d');  // draw on this
	}
	return this;
    }
    return null;
}

CanvasClass.prototype.swap = function() {
    if (this.double_buffer)
	this.ctx2.drawImage(this.canvas2,0,0);
}

CanvasClass.prototype.save = function() {
    if (this.ctx) this.ctx.save();
}

CanvasClass.prototype.restore = function(canvas) {
    if (this.ctx) this.ctx.restore();
}

CanvasClass.prototype.scale = function (x,y) {
    if (this.ctx) this.ctx.scale(x,y);
}

CanvasClass.prototype.rotate = function (a) {
    if (this.ctx) this.ctx.rotate(a);
}

CanvasClass.prototype.translate = function (x,y) {
    if (this.ctx) this.ctx.translate(x,y);
}

CanvasClass.prototype.transform = function (a,b,c,d,e,f) {
    if (this.ctx) this.ctx.transform(a,b,c,e,d,f);
}

CanvasClass.prototype.setTransform = function (a,b,c,d,e,f) {
    if (this.ctx) this.ctx.setTransform(a,b,c,e,d,f);
}

CanvasClass.prototype.globalAlpha = function(a) {
    if (this.ctx) this.ctx.globalAlpha = a;
}

CanvasClass.prototype.globalCompositeOperation = function(op) {
    if (this.ctx) this.ctx.globalCompositeOperation = op;
}

CanvasClass.prototype.strokeStyle = function(style) {
    if (this.ctx) this.ctx.strokeStyle = style;
}

CanvasClass.prototype.fillStyle = function(style) {
    if (this.ctx) this.ctx.fillStyle = style;
}

/* Fixme: add gradient stuff */

CanvasClass.prototype.lineWidth = function(w) {
    if (this.ctx) this.ctx.lineWidth = w;
}

CanvasClass.prototype.lineCap = function(cap) {
    if (this.ctx) this.ctx.lineCap = cap;
}

CanvasClass.prototype.lineJoin = function(join) {
    if (this.ctx) this.ctx.lineJoin = join;
}
    
CanvasClass.prototype.miterLimit = function(lim) {
    if (this.ctx) this.ctx.miterLimit = lim;
}

/* Shadow */

CanvasClass.prototype.shadowOffsetX = function(x) {
    if (this.ctx) this.ctx.shadowOffsetX = x;
}

CanvasClass.prototype.shadowOffsetY = function(y) {
    if (this.ctx) this.ctx.shadowOffsetX = Y;
}

CanvasClass.prototype.shadowBlur = function(b) {
    if (this.ctx) this.ctx.shadowBlur = b;
}

CanvasClass.prototype.shadowColor = function(color) {
    if (this.ctx) this.ctx.shadowColor = color;
}

/* rects */
CanvasClass.prototype.clearRect = function(x,y,w,h) {
    if (this.ctx) this.ctx.clearRect(x, y, w, h);
}

CanvasClass.prototype.fillRect = function(x,y,w,h) {
    if (this.ctx) this.ctx.fillRect(x, y, w, h);
}

CanvasClass.prototype.strokeRect = function(x,y,w,h) {
    if (this.ctx) this.ctx.strokeRect(x, y, w, h);
}

/* Path API */
CanvasClass.prototype.beginPath = function() {
    if (this.ctx) this.ctx.beginPath();
}

CanvasClass.prototype.closePath = function() {
    if (this.ctx) this.ctx.closePath();
}

CanvasClass.prototype.moveTo = function(x,y) {
    if (this.ctx) this.ctx.moveTo(x,y);
}

CanvasClass.prototype.lineTo = function(x,y) {
    if (this.ctx) this.ctx.lineTo(x,y);
}

CanvasClass.prototype.quadraticCurveTo = function(cp1x,cp1y,x,y) {
    if (this.ctx) this.ctx.quadraticCurveTo(cp1x,cp1y,x,y);
}

CanvasClass.prototype.bezierCurveTo = function(cp1x, cp1y, cp2x, cp2y, x, y) {
    if (this.ctx) this.ctx.bezierCurveTo(cp1x,cp1y,cp2x,cp2y,x,y);
}

CanvasClass.prototype.arcTo = function(x1,y1,x2,y2,r) {
    if (this.ctx) this.ctx.arcTo(x1,y1,x2,y2,r);
}
    
CanvasClass.prototype.rect = function(x,y,w,h) {
    if (this.ctx) this.ctx.rect(x, y, w, h);
}

CanvasClass.prototype.arc = function(x,y,r,a0,a1,acw) {
    if (this.ctx) this.ctx.arc(x,y,r,a0,a1,acw);
}

CanvasClass.prototype.fill = function() {
    if (this.ctx) this.ctx.fill();
}

CanvasClass.prototype.stroke = function() {
    if (this.ctx) this.ctx.stroke();
}

CanvasClass.prototype.clip = function() {
    if (this.ctx) this.ctx.clip();
}

CanvasClass.prototype.isPointInPath = function(x,y) {
    if (this.ctx) 
	return this.ctx.isPointInPath(x,y);
    return false;
}

/* drawFocusRing */

CanvasClass.prototype.font = function(f) {
    if (this.ctx) this.ctx.font = f;
}

CanvasClass.prototype.textAlign = function(a) {    
    if (this.ctx) this.ctx.textAlign = a;
}

CanvasClass.prototype.textBaseline = function(b) {    
    if (this.ctx) this.ctx.textBaseline = b;
}

CanvasClass.prototype.fillText = function(text,x,y,maxWidth) {
    if (this.ctx) this.ctx.fillText(text,x,y,maxWidth);
}

CanvasClass.prototype.strokeText = function(text,x,y,maxWidth) {
    if (this.ctx) this.ctx.strokeText(text,x,y,maxWidth);
}

CanvasClass.prototype.measureText = function(text) {
    if (this.ctx) return this.ctx.measureText(text);
    else return -1;
}

CanvasClass.prototype.drawImage2 =  function(image,x,y) {
    var ni = document.images[image];
    console.log("drawImage2: name=%s", image);
    console.log(ni);
    if (this.ctx) this.ctx.drawImage(ni,x,y);
}

CanvasClass.prototype.drawImage4 = function(image,x,y,w,h) {
    var ni  = document.images[image];
    console.log("drawImage: name=%s", image);
    console.log(ni);
    if (this.ctx) this.ctx.drawImage(ni,x,y,w,h);
}

CanvasClass.prototype.drawImage8 = function(image,x1,y1,w1,h1,x2,y2,w2,h2) {
    var ni  = document.images[image];
    console.log("drawImage: name=%s", image);
    console.log(ni);
    if (this.ctx) this.ctx.drawImage(ni,x1,y1,w1,h1,x2,y2,w2,h2);
}

// may work with double buffer check me
function do_scroll(ctx,x,y,w,h,dx,dy,clearStyle) {
    var ax = (dx >= 0) ? dx : -dx; // abs(dx)
    var ay = (dy >= 0) ? dy : -dy; // abs(dy)
    var sx = x + ((dx >= 0) ? 0  : ax);
    var sy = y + ((dy >= 0) ? 0  : ay);
    var tx = x + ((dx > 0) ? ax : 0);
    var ty = y + ((dy > 0) ? ay : 0);
    ctx.drawImage(ctx.canvas,sx,sy,w-ax,h-ay,tx,ty,w-ax,h-ay);
    if (clearStyle) {
	var cx = x + ((dx < 0) ? (w-ax-1) : 0);
	var cy = y + ((dy < 0) ? (h-ay-1) : 0);
	var cw = ax ? ax : w;
	var ch = ay ? ay : h;
	ctx.save();
	ctx.fillStyle = clearStyle;
	ctx.fillRect(cx,cy,cw,ch);
	ctx.restore();
    }
}

// major fix me!
function do_load_image(ctx,canvas,name,url) {
    var img = document.images[name];
    if (!img) {
	img = new Image();
	document.images[name] = img;
	img.onload = function() {
	    var func = obj('page').imageLoaded;
	    console.log(obj('page'));
	    console.log("func = %s\n", func);
	    // substr6??? fixme!
	    func.call(Bert.atom('loaded'),canvas.substr(6),name);
	}
	console.log("create image: name=%s", name);
    }
    img.src = url;
    console.log("image: set url=%d", url);
}

/* special hacks */
CanvasClass.prototype.scroll = function(x,y,w,h,dx,dy,clearStyle) {
    if (this.ctx) do_scroll(this.ctx, x,y,w,h,dx,dy,clearStyle);
}

CanvasClass.prototype.loadImage = function(name,url) {
    if (this.ctx) do_load_image(this.ctx,this.canvas,name,url);
}

CanvasClass.prototype.batch = function(commands) {
    var ctx = this.ctx;
    
    if (!ctx)
	return;
    for (i = 0; i < commands.length; i++) {
	var argv = commands[i];
	switch(argv[0]) {
	case 'save':  ctx.save(); break;
	case 'restore': ctx.restore(); break;
	case 'scale': ctx.scale(argv[1], argv[2]); break;
	case 'rotate': ctx.rotate(argv[1]); break;
	case 'translate': ctx.translate(argv[1],argv[2]); break;
	case 'transform':
	    ctx.transform(argv[1],argv[2],argv[3],argv[4],argv[5]);
	    break;
	case 'setTransform':
	    ctx.setTransform(argv[1],argv[2],argv[3],argv[4],argv[5]);
	    break;
	case 'globalAlpha':	ctx.globalAlpha=argv[1]; break;
	case 'globalCopositeOperation':
	    ctx.globalCopositeOperation=argv[1]; break;
	case 'strokeStyle': ctx.strokeStyle=argv[1]; break;
	case 'fillStyle':   ctx.fillStyle=argv[1]; break;
	case 'lineWidth':   ctx.lineWidth=argv[1]; break;
	case 'lineCap':     ctx.lineCap=argv[1]; break;
	case 'lineJoin':    ctx.lineJoin=argv[1]; break;
	case 'miterLimit':  ctx.miterLimit=argv[1]; break;
	case 'shadowOffsetX': ctx.shadowOffsetX=argv[1]; break;
	case 'shadowOffsetY': ctx.shadowOffsetY=argv[1]; break;
	case 'shadowBlur':    ctx.shadowBlur=argv[1]; break;
	case 'shadowColor':   ctx.shadowColor=argv[1]; break;
	case 'clearRect': 
	    ctx.clearRect(argv[1],argv[2],argv[3],argv[4]);
	    break;
	case 'fillRect': 
	    ctx.fillRect(argv[1],argv[2],argv[3],argv[4]);
	    break;
	case 'strokeRect': 
	    ctx.strokeRect(argv[1],argv[2],argv[3],argv[4]);
	    break;
	case 'beginPath': ctx.beginPath(); break;
	case 'closePath': ctx.closePath(); break;
	case 'moveTo': ctx.moveTo(argv[1],argv[2]); break;
	case 'lineTo': ctx.lineTo(argv[1],argv[2]); break;
	case 'quadraticCurveTo':
	    ctx.quadraticCurveTo(argv[1],argv[2],argv[3],argv[4]);
	    break;
	case 'bezierCurveTo':
	    ctx.bezierCurveTo(argv[1],argv[2],argv[3],argv[4],
			      argv[5],argv[6]);
	    break;
	case 'arcTo':
	    ctx.arcTo(argv[1],argv[2],argv[3],argv[4],argv[5]);
	    break;
	case 'rect':
	    ctx.rect(argv[1],argv[2],argv[3],argv[4]);
	    break;
	case 'arc':
	    ctx.arc(argv[1],argv[2],argv[3],argv[4],
		    argv[5],argv[6]);
	    break;
	case 'fill':   ctx.fill();  break;
	case 'stroke': ctx.stroke(); break;
	case 'clip':   ctx.clip(); break;
	case 'isPointInPath':
	    // fixme handle return values!
	    ctx.isPointInPath(argv[1],argv[2]);
	    break;
	case 'font': ctx.font = argv[1]; break;
	case 'textAlign': ctx.textAlign = argv[1]; break;
	case 'textBaseline': ctx.textBaseline = argv[1]; break;
	case 'fillText':
	    ctx.fillText(argv[1],argv[2],argv[3],argv[4]);
	    break;
	case 'strokeText':
	    ctx.strokeText(argv[1],argv[2],argv[3],argv[4]);
	    break;
	case 'measureText':
	    // fixme handle return value
	    ctx.measureText(argv[1]);
	    break;
	case 'drawImage':
	    switch (argv.length) {
	    case 4: 
		ctx.drawImage(argv[1],argv[2],argv[3]);
		break;
	    case 6:
		ctx.drawImage(argv[1],argv[2],argv[3],argv[4],argv[5]);
		break;
	    case 10:
		ctx.drawImage(argv[1],argv[2],argv[3],argv[4],argv[5],
			      argv[6],argv[7],argv[8],argv[9]);
		break;
	    }
	    break;
	    
	case 'scroll':
	    do_scroll(ctx, argv[1],argv[2],argv[3],argv[4],
		      argv[5],argv[6],argv[7]);
	    break;
	    
	case 'loadImage':
	    do_load_image(ctx,this.canvas,argv[1],argv[2]);
	    break;
	}
    }
}

    