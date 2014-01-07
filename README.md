# fabuloos' Flash fallback

This project is a part of the [fabuloos' project](http://fabuloos.org).

This Flash fallback implement the [HTML5's media specification](http://dev.w3.org/html5/spec-author-view/video.html) (well, not completely for the moment). It is used in the [fabuloos-js](https://github.com/egeny/fabuloos-js) project with its [associated renderer](https://github.com/egeny/fabuloos-js/blob/master/src/renderers/FabuloosFlashRenderer.js).


# How to build

In order to compile, you need to install some dependencies:

1. [Apache Flex SDK](http://flex.apache.org/download-binaries.html) is used to compile the ActionScript files to SWF. Download the binaries for your platform and extract the file in the `tools` folder. You may have to adjust the directory in the `build.xml` file. You should have a `tools/flex-sdk-4.xx.xxx` containing a lot of files.
2. [playerglobal.swc](http://www.adobe.com/support/flashplayer/downloads.html) is necessary for the compiler. You may have to dig a little in the page to find the right file. Just put the downloaded file in `tools` and rename it to `playerglobal.swc`.
3. [OSMF.swc](http://sourceforge.net/projects/osmf.adobe/files/) is a precompiled version of the [Open Source Media Framework](http://osmf.org/). Grab the last version and place it in the `tools` folder.
4. [Apache Ant](http://ant.apache.org/) must be installed on your system. It may be already installed, try launching `ant -v` in a terminal console before making anything foolish.

When all the dependencies are installed, simply launch `ant` in a terminal console.  
It will build the sources and create a `FabuloosFlashRenderer.swf` file in the `build` folder.

# How to test

Since FabuloosFlashRenderer use ExternalInterface, you need to use it via a webserver.  
After configuring your favorite webserver to serve the folder of this project, simply browse to it. The `index.html` file contain the basic markup to embed the Flash object.

The player embed a `Console.as` file which allows you to call JavaScript's `console.*` functions. You may want to disable console logging while compiling for production. Just have a look at `Console.as` on line 9.

It is also recommended to install a [Flash player content debugger](http://www.adobe.com/support/flashplayer/downloads.html).

# Interface

Here are the methods exposed by the player:

* `load()` — Launch the loading of a resource.
* `pause()` — Pause the playback (duh!).
* `_play()` — Launch the playback (`play` is a reserved word in ActiveX).
* `bind()` — Ask the player to listen for an event type.
* `unbind()` — Ask the player to stop listening for an event type.
* `get()` — Retrieve a property's value.
* `set()` — Set a property's value. The value may be corrected (calling `set("autoplay", 1)` will set the autoplay value to `true`).

The player will try to call these JavaScript methods:

* `ready()` — The player finished loading and doing its internal stuffs.
* `trigger()` — The player want to trigger an event (e.g. `trigger("playing")`).

These two methods will be called on the “bridge” ; the renderer who created the `<object>`. By default the bridge is set to :

```
Renderer.FabuloosFlashRenderer.instances[" <object>'s id "];
```

So, if you want to test that the player call `ready()` or `trigger()` you will have to add this kind of code in your JavaScript:

```
var
	renderer = {
		ready: function() {
			console.log("Now ready");
		},
		trigger: function(event) {
			console.log("Triggering " + event);
		}
	},
	Renderer = {
		FabuloosFlashRenderer: {
			instances: {
				flash: renderer
			}
		}
	};
```