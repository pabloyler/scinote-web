!function(){var a={},b=function(b){for(var c=a[b],e=c.deps,f=c.defn,g=e.length,h=new Array(g),i=0;i<g;++i)h[i]=d(e[i]);var j=f.apply(null,h);if(void 0===j)throw"module ["+b+"] returned undefined";c.instance=j},c=function(b,c,d){if("string"!=typeof b)throw"module id must be a string";if(void 0===c)throw"no dependencies for "+b;if(void 0===d)throw"no definition function for "+b;a[b]={deps:c,defn:d,instance:void 0}},d=function(c){var d=a[c];if(void 0===d)throw"module ["+c+"] was undefined";return void 0===d.instance&&b(c),d.instance},e=function(a,b){for(var c=a.length,e=new Array(c),f=0;f<c;++f)e.push(d(a[f]));b.apply(null,b)},f={};f.bolt={module:{api:{define:c,require:e,demand:d}}};var g=c,h=function(a,b){g(a,[],function(){return b})};h("7",tinymce.util.Tools.resolve),g("1",["7"],function(a){return a("tinymce.PluginManager")}),g("2",["7"],function(a){return a("tinymce.dom.DOMUtils")}),g("3",["7"],function(a){return a("tinymce.util.Tools")}),g("4",["7"],function(a){return a("tinymce.EditorManager")}),g("5",["7"],function(a){return a("tinymce.util.Delay")}),g("6",["7"],function(a){return a("tinymce.Env")}),g("0",["1","2","3","4","5","6"],function(a,b,c,d,e,f){return a.add("tabfocus",function(a){function g(a){9!==a.keyCode||a.ctrlKey||a.altKey||a.metaKey||a.preventDefault()}function h(b){function g(e){function f(a){return"BODY"===a.nodeName||"hidden"!=a.type&&"none"!=a.style.display&&"hidden"!=a.style.visibility&&f(a.parentNode)}function g(a){return/INPUT|TEXTAREA|BUTTON/.test(a.tagName)&&d.get(b.id)&&a.tabIndex!=-1&&f(a)}if(j=i.select(":input:enabled,*[tabindex]:not(iframe)"),c.each(j,function(b,c){if(b.id==a.id)return h=c,!1}),e>0){for(l=h+1;l<j.length;l++)if(g(j[l]))return j[l]}else for(l=h-1;l>=0;l--)if(g(j[l]))return j[l];return null}var h,j,k,l;if(!(9!==b.keyCode||b.ctrlKey||b.altKey||b.metaKey||b.isDefaultPrevented())&&(k=c.explode(a.getParam("tab_focus",a.getParam("tabfocus_elements",":prev,:next"))),1==k.length&&(k[1]=k[0],k[0]=":prev"),j=b.shiftKey?":prev"==k[0]?g(-1):i.get(k[0]):":next"==k[1]?g(1):i.get(k[1]))){var m=d.get(j.id||j.name);j.id&&m?m.focus():e.setTimeout(function(){f.webkit||window.focus(),j.focus()},10),b.preventDefault()}}var i=b.DOM;a.on("init",function(){a.inline&&i.setAttrib(a.getBody(),"tabIndex",null),a.on("keyup",g),f.gecko?a.on("keypress keydown",h):a.on("keydown",h)})}),function(){}}),d("0")()}();
