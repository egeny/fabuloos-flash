package {

	// Flash imports
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.external.ExternalInterface;
	import flash.system.Capabilities;

	// OSMF imports
	import org.osmf.elements.VideoElement;
	import org.osmf.events.DisplayObjectEvent;
	import org.osmf.events.MediaFactoryEvent;
	import org.osmf.events.MediaPlayerCapabilityChangeEvent;
	import org.osmf.events.MediaPlayerStateChangeEvent;
	import org.osmf.events.TimeEvent;
	import org.osmf.media.MediaPlayer;
	import org.osmf.media.MediaPlayerSprite;
	import org.osmf.media.MediaPlayerState;
	import org.osmf.media.URLResource;

	import Console;


	public class FabFlashRenderer extends Sprite {

		// Error states constants
		private const MEDIA_ERR_ABORTED:uint           = 1;
		private const MEDIA_ERR_NETWORK:uint           = 2;
		private const MEDIA_ERR_DECODE:uint            = 3;
		private const MEDIA_ERR_SRC_NOT_SUPPORTED:uint = 4;

		// Network states constants
		private const NETWORK_EMPTY:uint     = 0;
		private const NETWORK_IDLE:uint      = 1;
		private const NETWORK_LOADING:uint   = 2;
		private const NETWORK_NO_SOURCE:uint = 3;

		// Ready states constants
		private const HAVE_NOTHING:uint      = 0;
		private const HAVE_METADATA:uint     = 1;
		private const HAVE_CURRENT_DATA:uint = 2;
		private const HAVE_FUTURE_DATA:uint  = 3;
		private const HAVE_ENOUGH_DATA:uint  = 4;

		// The HTML5's default API properties
		// width & height will be "inherited" from DisplayObject
		private var videoWidth:uint   = 0;
		private var videoHeight:uint  = 0;
		private var poster:String     = "";

		// Error state
		private var error:Object = null;

		// Network state
		private var src:String          = "";
		private var currentSrc:String   = "";
		private var networkState:uint   = NETWORK_EMPTY;
		private var preload:String      = "auto";
		//private var buffered:TimeRanges = new TimeRanges();

		// Ready state
		private var readyState:uint = HAVE_NOTHING;
		private var seeking:Boolean = false;

		// Playback state
		private var currentTime:Number         = 0;
		private var duration:Number            = NaN;
		private var paused:Boolean             = true;
		private var defaultPlaybackRate:Number = 1;
		private var playbackRate:Number        = 1;
		//private var played:TimeRanges          = new TimeRanges();
		//private var seekable:TimeRanges        = new TimeRanges();
		private var ended:Boolean              = false;
		private var autoplay:Boolean           = false;
		private var loop:Boolean               = false;

		// Controls
		private var controls:Boolean     = false;
		private var volume:Number        = 1;
		private var muted:Boolean        = false;
		private var defaultMuted:Boolean = false;

		// Tracks
		// TODO

		// The bridge to use to communicate with the renderer
		// Use Renderer.FabFlashRenderer since Renderer should be the only class exposed
		private static var BRIDGE:String = 'Renderer.FabFlashRenderer.instances["' + ExternalInterface.objectID + '"]';

		// Media objects (OSMF)
		private var sprite:MediaPlayerSprite = new MediaPlayerSprite();
		private var player:MediaPlayer       = sprite.mediaPlayer;


		/**
		 * The main FabFlashRenderer constructor
		 * @constructor
		 */
		public function FabFlashRenderer():void {
			Console.info("Bridge: " + BRIDGE);

			var version:* = Capabilities.version.replace(/(WIN|MAC|UNIX) /, "").split(",");
			    version   = version[0] + "." + version[1] + " (r" + version[2] + ")";
			    version  += Capabilities.isDebugger ? " (debug)" : "";
			Console.info("Flash version:", Capabilities.playerType.toLowerCase(), version);

			// Wait for the stage to be available
			this.addEventListener(Event.ADDED_TO_STAGE, init);
		} // end of FabFlashRenderer()


		/**
		 * Initialize the application
		 *
		 * @param {Event} e The ADDED_TO_STAGE event.
		 * @return {void} Return nothing.
		 */
		private function init(e:Event):void {
			var
				flashvars:Object = stage.loaderInfo.parameters,
				property:String;

			// Align to fit to the stage
			stage.align     = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;

			// Add the sprite to the stage
			stage.addChild(sprite);

			// Resize the sprite to fit to the stage's dimensions
			this.resize();

			// Register callbacks
			this.registerExternalInterface();

			// Add some events listeners
			stage.addEventListener(Event.RESIZE, resize); // Watch for stage resizing to resize viewport
			this.addKeyboardEventListeners();
			this.addMouseEventListeners();

			// Add the media's events listeners
			// TODO: change handlers names
			player.addEventListener(TimeEvent.CURRENT_TIME_CHANGE, handleCurrentTimeChange);
			player.addEventListener(TimeEvent.DURATION_CHANGE, handleDurationChange);
			player.addEventListener(TimeEvent.COMPLETE, handleComplete);
			player.addEventListener(MediaPlayerCapabilityChangeEvent.CAN_PLAY_CHANGE, handleCanPlayChange);
			player.addEventListener(DisplayObjectEvent.MEDIA_SIZE_CHANGE, handleMediaSizeChange);

			// Configure the internal player
			player.autoPlay   = autoplay;
			player.autoRewind = false;

			// Add a listener on the mediaFactory to intercept the creation of Video player (then enable smoothing)
			sprite.mediaFactory.addEventListener(MediaFactoryEvent.MEDIA_ELEMENT_CREATE, enableSmoothing);

			//player.addEventListener(MediaPlayerCapabilityChangeEvent.CAN_BUFFER_CHANGE, handleEvent);
			//player.addEventListener(MediaPlayerCapabilityChangeEvent.CAN_LOAD_CHANGE, handleEvent);
			player.addEventListener(MediaPlayerCapabilityChangeEvent.CAN_SEEK_CHANGE, handleCanSeekChange);
			//player.addEventListener(MediaPlayerCapabilityChangeEvent.HAS_ALTERNATIVE_AUDIO_CHANGE, handleEvent);
			//player.addEventListener(MediaPlayerCapabilityChangeEvent.HAS_AUDIO_CHANGE, handleEvent);
			//player.addEventListener(MediaPlayerCapabilityChangeEvent.HAS_DISPLAY_OBJECT_CHANGE, handleEvent);
			//player.addEventListener(MediaPlayerCapabilityChangeEvent.HAS_DRM_CHANGE, handleEvent);
			//player.addEventListener(MediaPlayerCapabilityChangeEvent.IS_DYNAMIC_STREAM_CHANGE, handleEvent);
			//player.addEventListener(MediaErrorEvent.MEDIA_ERROR, handleEvent);
			player.addEventListener(MediaPlayerStateChangeEvent.MEDIA_PLAYER_STATE_CHANGE, handlePlayerStateChange);
			//player.addEventListener(MediaPlayerCapabilityChangeEvent.TEMPORAL_CHANGE, handleEvent);

			// Try to set the flashvars (if any)
			for (property in flashvars) {
				// Delay the defining the "src" property
				if (property !== "src") {
					this.set(property, flashvars[property]);
				}
			}

			// Define an "src" if any
			if (flashvars.src) {
				this.set("src", flashvars.src);
			}

			// Tell the bridge this player is ready
			ExternalInterface.call(BRIDGE + ".ready");
		} // end of init()


		/**
		 * Register the keyboard's events
		 *
		 * @param {undefined}
		 * @return {void} Return nothing.
		 */
		private function addKeyboardEventListeners():void {
			// TODO
		} // end of addKeyboardEventListeners()


		/**
		 * Register the mouse's events
		 *
		 * @param {undefined}
		 * @return {void} Return nothing.
		 */
		private function addMouseEventListeners():void {
			stage.addEventListener(MouseEvent.CLICK,      this.trigger);
			//stage.addEventListener(MouseEvent.MOUSE_MOVE, this.trigger); // Too bad for performance
			//stage.addEventListener(MouseEvent.MOUSE_OVER, this.trigger);
		} // end of addMouseEventListeners()


		/**
		 * TODO
		 *
		 * @param {String} type The event type to listen.
		 * @return {void} Return nothing.
		 */
		public function bind(type:String):void {
			Console.warn('Asked to bind "' + type + '"');
			// TODO
		} // end of bind()


		/**
		 * Enable the video smoothing
		 *
		 * @param {MediaFactoryEvent} e A MediaFactoryEvent.MEDIA_ELEMENT_CREATE event.
		 * @return {void} Return nothing.
		*/
		private function enableSmoothing(e:MediaFactoryEvent):void {
			// Enable only the smoothing for VideoElement
			if (e.mediaElement is VideoElement) {
				(e.mediaElement as VideoElement).smoothing = true;
			}
		} // end of enableSmoothing()


		/**
		 * Get the value associated to a property
		 *
		 * @param {String} property The property to get.
		 * @return {*} Return the property's value or undefined if this property doesn't exists.
		 */
		public function get(property:String):* {
			/*!
			 * Use a try/catch and a violent solution since:
			 * - property in this will not work
			 * - this.hasOwnProperty(property) will not work
			 * - this[property] will raise an Exception if the property doesn't exists
			 */
			try {
				// Do not return function (duh!)
				return (typeof this[property] === "function") ? undefined : this[property];
			} catch (e:Error) {
				return undefined;
			}
		} // end of get()


		/**
		 * Handle receiving a MediaPlayerCapabilityChangeEvent.CAN_PLAY_CHANGE event
		 *
		 * @param {MediaPlayerCapabilityChangeEvent} e A MediaPlayerCapabilityChangeEvent.CAN_PLAY_CHANGE event.
		 * @return {void} Return nothing.
		 */
		private function handleCanPlayChange(e:MediaPlayerCapabilityChangeEvent):void {
			this.trigger("canplay");
		} // end of handleCanPlayChange()


		/**
		 * Handle receiving a MediaPlayerCapabilityChangeEvent.CAN_SEEK_CHANGE event
		 *
		 * @param {MediaPlayerCapabilityChangeEvent} e A MediaPlayerCapabilityChangeEvent.CAN_SEEK_CHANGE event.
		 * @return {void} Return nothing.
		 */
		private function handleCanSeekChange(e:MediaPlayerCapabilityChangeEvent):void {
			// FIXME: should be elsewhere
			this.trigger("loadeddata");
		} // end of handleCanSeekChange()


		/**
		 * Handle the completion of the playback
		 * Implementation of http://www.w3.org/html/wg/drafts/html/master/embedded-content-0.html#ended
		 *
		 * @param {TimeEvent} e A TimeEvent event.
		 * @return {void} Return nothing.
		 */
		private function handleComplete(e:TimeEvent):void {
			// For an unknown reason this handler can be called twice
			if (ended) { return; }

			// Step 1)
			if (loop) {
				this.seek(0);
				this.play();
				return;
			}

			// Step 2)
			ended = true;

			// Step 3)
			this.trigger("timeupdate");

			// TODO: Step 4)

			// Step 5)
			this.trigger("ended");

			// TODO: Step 6)
		} // end of handleComplete()


		/**
		 * Handle receiving a TimeEvent.CURRENT_TIME_CHANGE event
		 *
		 * @param {TimeEvent} e A TimeEvent.CURRENT_TIME_CHANGE event.
		 * @return {void} Return nothing.
		 */
		private function handleCurrentTimeChange(e:TimeEvent):void {
			currentTime = e.time;
			this.trigger("timeupdate");
		} // end of handleCurrentTimeChange()


		/**
		 * Handle receiving a TimeEvent.DURATION_CHANGE event
		 *
		 * @param {TimeEvent} e A TimeEvent.DURATION_CHANGE event.
		 * @return {void} Return nothing.
		 */
		private function handleDurationChange(e:TimeEvent):void {
			duration = e.time;
			this.trigger("durationchange");
		} // end of handleDurationChange()


		/**
		 * Handle receiving a DisplayObjectEvent.MEDIA_SIZE_CHANGE event
		 *
		 * @param {DisplayObjectEvent} e A DisplayObjectEvent.MEDIA_SIZE_CHANGE event.
		 * @return {void} Return nothing.
		 */
		private function handleMediaSizeChange(e:DisplayObjectEvent):void {
			videoWidth  = e.newWidth;
			videoHeight = e.newHeight;

			this.trigger("loadedmetadata");
		} // end of handleMediaSizeChange()


		/**
		 * Handle receiving a MediaPlayerStateChangeEvent.MEDIA_PLAYER_STATE_CHANGE event
		 *
		 * @param {MediaPlayerStateChangeEvent} e A MediaPlayerStateChangeEvent.MEDIA_PLAYER_STATE_CHANGE event.
		 * @return {void} Return nothing.
		 */
		private function handlePlayerStateChange(e:MediaPlayerStateChangeEvent):void {
			if (e.state === MediaPlayerState.PLAYING) {
				// FIXME: should be elsewhere
				this.trigger("playing");
			}
		} // end of handlePlayerStateChange()


		/**
		 * Launch the playback
		 * Implementation of http://www.w3.org/html/wg/drafts/html/master/embedded-content-0.html#load()
		 *
		 * @param {undefined}
		 * @return {void} Return nothing.
		 */
		public function load():void {
			var changed:Boolean;

			// Step 1) is N/A (abort resource selection algorithm)

			// Step 2) is N/A (remove tasks)

			// Step 3)
			if (networkState === NETWORK_LOADING || networkState === NETWORK_IDLE) {
				this.trigger("abort");
			}

			// Step 4)
			if (networkState !== NETWORK_EMPTY) {
				// Substep 1)
				this.trigger("emptied");

				// Substep 2) is N/A (stop fetching process)

				// TODO: Substep 3)

				// Substep 4)
				readyState = HAVE_NOTHING;

				// Substep 5)
				paused = true;

				// Substep 6)
				seeking = false;

				// Substep 7)
				changed = currentTime !== 0;

				if (player.canSeek) {
					player.seek(0);
				}

				currentTime = 0;

				if (changed) {
					this.trigger("timeupdate")
				}

				// Substep 8) is deprecated (?)

				// TODO: Substep 9)

				// Substep 10)
				duration = NaN;
			}

			// Step 5)
			playbackRate = defaultPlaybackRate;

			// Step 6)
			error = null;
			// autoplaying-flash is N/A

			// Step 7)
			this.resourceSelection();

			// Step 8)
			// Some media cannot be paused
			if (player.canPause) {
				player.pause();
			}

			if (autoplay) {
				player.play();
			}
		} // end of load()


		/**
		 * Launch the playback
		 * Implementation of http://www.w3.org/html/wg/drafts/html/master/embedded-content-0.html#pause()
		 *
		 * @param {undefined}
		 * @return {void} Return nothing.
		 */
		public function pause():void {
			// Some media cannot be paused
			if (!player.canPause) { return; }

			// Step 1)
			if (networkState === NETWORK_EMPTY) {
				// Resource selection algorithm
				this.resourceSelection();
			}

			// Step 2) is N/A (autoplaying-flag)

			// Step 3)
			if (!paused) {
				// Substep 1)
				paused = true;

				// Substep 2)
				this.trigger("timeupdate");

				// Substep 3)
				this.trigger("pause");

				// Substep 4)
				currentTime = player.currentTime;
			}

			// TODO: Step 4)

			// Finally, stop the playback
			player.pause();
		} // end of pause()


		/**
		 * Launch the playback
		 * Implementation of http://www.w3.org/html/wg/drafts/html/master/embedded-content-0.html#play()
		 *
		 * @param {undefined}
		 * @return {void} Return nothing.
		 */
		public function play():void {
			// Step 1)
			if (networkState === NETWORK_EMPTY) {
				this.resourceSelection(); // Resource selection algorithm
			}

			// TODO: Step 2)

			// TODO: Step 3)

			// Step 4)
			if (paused === true) {
				// Substep 1)
				paused = false;

				// TODO: Substep 2)

				// Substep 3)
				this.trigger("play");

				// Substep 4)
				if (readyState <= HAVE_CURRENT_DATA) {
					this.trigger("waiting");
				} else if (readyState >= HAVE_FUTURE_DATA) {
					this.trigger("playing");
				}
			}

			// Step 5) is N/A (autoplaying-flag)

			// TODO: Step 6)

			// Finally, launch the playback
			// Avoid error when calling without resource (should be filled by the resource selection algorithm)
			if (sprite.resource && player.canPlay) {
				player.play();
			}
		} // end of play()


		/**
		 * Register ExternalInterface's callbacks
		 *
		 * @param {undefined}
		 * @return {void} Return nothing.
		 */
		private function registerExternalInterface():void {
			// HTML5 Media API
			ExternalInterface.addCallback("load",  load);
			ExternalInterface.addCallback("pause", pause);
			ExternalInterface.addCallback("_play", play); // We can't use play since it is reserved by ActiveX

			// Renderer specific
			ExternalInterface.addCallback("bind",   bind);
			ExternalInterface.addCallback("unbind", unbind);
			ExternalInterface.addCallback("get",    get);
			ExternalInterface.addCallback("set",    set);
		} // end of registerExternalInterface()


		/**
		 * Resize the sprite
		 *
		 * @param {Event} e An Event.RESIZE event.
		 * @return {void} Return nothing.
		 */
		public function resize(e:Event = null):void {
			sprite.width  = stage.stageWidth;
			sprite.height = stage.stageHeight;
		} // end of resize()


		/**
		 * Fake the resource loading algorithm
		 * Implementation of http://www.w3.org/html/wg/drafts/html/master/embedded-content-0.html#resource-fetch-algorithm
		 *
		 * @param {undefined}
		 * @return {void} Return nothing.
		 */
		private function resourceFetch():void {
			// Note: this is a partial implementation

			// Step 1) is N/A (nothing passed)

			// TODO: Step 2)

			// TODO: Step 3)

			// Step 4)
			sprite.resource = new URLResource(src);
		} // end of resourceFetch()


		/**
		 * Fake the resource selection algorithm
		 * Implementation of http://www.w3.org/html/wg/drafts/html/master/embedded-content-0.html#resource-selection-algorithm
		 *
		 * @param {undefined}
		 * @return {void} Return nothing.
		 */
		private function resourceSelection():void {
			// Step 1)
			networkState = NETWORK_NO_SOURCE;

			// TODO: Step 2)

			// Step 3) is N/A (delaying-the-load-event flag)

			// Step 4) is N/A (await a stable state)

			// TODO: Step 5)

			// Step 6) is N/A

			// Step 7)
			networkState = NETWORK_LOADING;

			// Step 8)
			this.trigger("loadstart");

			// Step 9) is obvious
				// Substep 1)
				if (src !== "") {
					// TODO: Substep 2)

					// Substep 3)
					currentSrc = src;

					// Substep 4) is N/A

					// Substep 5)
					return this.resourceFetch();
				}

				// Substep 6)
					// Substep 1)
					//error = new MediaError(MEDIA_ERR_SRC_NOT_SUPPORTED); // TODO

					// TODO: Substep 2)

					// Substep 3)
					networkState = NETWORK_NO_SOURCE;

					// TODO: Substep 4)

					// Substep 5)
					this.trigger("error");

					// Substep 6) is N/A (delaying-the-load-event flag)

				// Substep 7) is N/A (wait)

				// Substep 8) is N/A (nothing to do)
		} // end of resourceSelection()


		/**
		 * Seek the playback to a number of seconds
		 * Implementation of http://www.w3.org/html/wg/drafts/html/master/embedded-content-0.html#seek
		 *
		 * @param {Number} seconds The number of seconds where to seek to.
		 * @return {void} Return nothing.
		 */
		private function seek(seconds:Number):void {
			// Some media cannot be seeked
			//if (player.canSeek) { return; }

			// TODO: Step 1) (poster-flag)

			// TODO: Step 2)
			/*if (readyState === HAVE_NOTHING) {
				return;
			}*/

			// Step 3) is N/A (aborting another seek)

			// Step 4)
			seeking = true;

			// Step 5) is N/A (seek in response to a DOM method call)

			// Step 6)
			seconds = seconds > duration ? duration : seconds;

			// Step 7)
			seconds = seconds < 0 ? 0 : seconds;

			// TODO: Step 8)

			// TODO: Step 9)

			// Step 10)
			this.trigger("seeking");

			// TODO: Step 11)
			player.seek(seconds);

			// TODO: Step 12)

			// Step 13) is N/A (wait for a stable state)

			// Step 14)
			seeking = false;

			// TODO: Step 15)

			// Step 16)
			this.trigger("timeupdate");

			// Step 17)
			this.trigger("seeked");
		} // end of seek()


		/**
		 * Set a value for a property
		 *
		 * @param {String} property The property to set.
		 * @param {*} value The new property's value.
		 * @return {*} Return the property's value (might be corrected) or undefined if this property doesn't exists.
		 */
		public function set(property:String, value:*):* {
			Console.warn('Asked to set "' + property + '" with ' + value);

			// TODO: width height preload defaultPlaybackRate playbackRate poster
			// Switch through property (pretty straightforward)
			switch (property) {
				case "autoplay":
					autoplay = player.autoPlay = value;
				break;

				case "controls":
					controls = value;
					// TODO: Should display or hide native controls
				break;

				case "currentTime":
					this.seek(value);
				break;

				case "loop":
					loop = value;
				break;

				case "muted":
					muted = player.muted = value;
					this.trigger("volumechange");
				break;

				case "src":
					src = value;
					this.load();
				break;

				case "volume":
					// Change the volume only if receiving a valid value and if we actually have to change it
					if (!isNaN(value) && value !== volume) {
						value  = value > 1 ? 1 : value;
						value  = value < 0 ? 0 : value;
						volume = player.volume = value;
						this.trigger("volumechange");
					}
				break;
			}

			// Return the value (may have been corrected)
			return this.get(property);
		} // end of set()


		/**
		 * Trigger an avent
		 *
		 * @param {String} event The event to trigger. Might be an Event or a string.
		 * @return {void} Return nothing.
		 */
		public function trigger(event:Object):void {
			// Prefer dispatching only a string
			var type:String = event is Event ? event.type : event as String;

			Console.warn('Asked to trigger "' + type + '"');

			ExternalInterface.call(BRIDGE + ".trigger", type);
		} // end of trigger()


		/**
		 * TODO
		 *
		 * @param {String} type The event type to listen.
		 * @return {void} Return nothing.
		 */
		public function unbind(type:String):void {
			Console.warn('Asked to unbind "' + type + '"');
			// TODO
		} // end of unbind()

	} // end of class
} // end of package