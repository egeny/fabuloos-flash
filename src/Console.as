package {

	import flash.external.ExternalInterface;
	import flash.utils.describeType;

	public final class Console {

		// Do we have to call ExternalInterface?
		public static var ACTIVE:Boolean = false;


		/**
			Call the JS console API
			@private @static @function

			@param {String} method The JS console's method to call
			@param {Array} arguments The arguments to provide to the console
		*/
		private static function call(method:String, ... arguments):void {
			if (!Console.ACTIVE) {
				return;
			}

			var
				args:Array = ["console." + method, "[AS3]"], // The console method to call, then a prefix
				i:uint = 0, count:uint, // Loop specific vars
				nativeTypes:Array = ["boolean", "number", "string"]; // An array of native type we can detect with typeof

			// Check if we have arguments (console.clear doesn't have arguments)
			if (arguments.length) {
				arguments = arguments[0]; // WTF? arguments (or whatever the name) is always an array of one element ?!
				count = arguments.length; // … So we have to recount

				// Push the corrected arguments in args
				for (; i < count; i++) {
					args.push(
						// Fix the non-native types
						(nativeTypes.indexOf(typeof arguments[i]) !== -1 || arguments[i] === undefined || arguments[i] === null || arguments[i] is Array || arguments[i] is Date) ?
						arguments[i] : fix(arguments[i])
					);
				}
			}

			// Call the JS method with corrected args
			ExternalInterface.call.apply(null, args);
		} // end of call()


		/**
			ExternalInterface won't allow to pass local variable to JS, so we have to correct these values
			@private @static @function

			@param {Object} obj The object to fix

			@returns {Object} The corrected object
		*/
		private static function fix(obj:*):Object {
			var
				fixed:Object = {}, // The fixed object
				accessor:XML, // We need to read the class properties, so we'll use describeType (WTF seriously…)
				nativeTypes:Array = ["boolean", "number", "string"], // An array of native type we can detect with typeof
				property:String, value:*;

			// Loop through each class properties
			for each (accessor in describeType(obj)..accessor.@name) {
				property = accessor.toString();
				value    = obj[property];

				// Correct the value if it is Object (otherwise ExternalInterface will fail)
				// Limit to one depth (will not correct if value is an Object)
				value = (nativeTypes.indexOf(typeof value) !== -1 || value is Array || value is Date) ? value : value.toString();

				fixed[property] = value;
			}

			// Then, loop through each object's properties
			for (property in obj) {
				value = obj[property];

				// Correct the value if it is Object (otherwise ExternalInterface will fail)
				// Limit to one depth (will not correct if value is an Object)
				value = (nativeTypes.indexOf(typeof value) !== -1 || value is Array || value is Date) ? value : value.toString();

				fixed[property] = value;
			}

			return fixed;
		} // end of fix()


		public static function log(... arguments):void {
			call("log", arguments);
		} // end of log()


		public static function info(... arguments):void {
			call("info", arguments);
		} // end of info()


		public static function warn(... arguments):void {
			call("warn", arguments);
		} // end of warn()


		public static function error(... arguments):void {
			call("error", arguments);
		} // end of error()


		public static function clear():void {
			call("clear");
		} // end of clear()

	} // end of class

} // end of package