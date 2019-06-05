component {

	function init(
		required string secret
	,	required string siteKey
	,	string apiUrl= "https://www.google.com/recaptcha/api/siteverify?"
	,	numeric httpTimeOut= 5
	,	boolean debug= ( request.debug ?: false )
	) {
		this.secret= arguments.secret;
		this.siteKey= arguments.siteKey;
		this.apiUrl= arguments.apiUrl;
		this.httpTimeOut= arguments.httpTimeOut;
		this.debug = arguments.debug;
	}

	function debugLog(required input) {
		if ( structKeyExists( request, "log" ) && isCustomFunction( request.log ) ) {
			if ( isSimpleValue( arguments.input ) ) {
				request.log( "recaptcha: " & arguments.input );
			} else {
				request.log( "recaptcha: (complex type)" );
				request.log( arguments.input );
			}
		} else if( this.debug ) {
			cftrace( text=( isSimpleValue( arguments.input ) ? arguments.input : "" ), var=arguments.input, category="recaptcha", type="information" );
		}
		return;
	}

	private function getRemoteIp(){
		var headers= GetHttpRequestData().headers;
		if( structKeyExists( headers, 'x-cluster-client-ip' ) ){
			return headers[ 'x-cluster-client-ip' ];
		}
		if( structKeyExists( headers, 'X-Forwarded-For' ) ){
			return headers[ 'X-Forwarded-For' ];
		}
		return len( cgi.remote_addr ) ? cgi.remote_addr : '127.0.0.1';
	}

	struct function verify( required string response, string remoteIP=getRemoteIp() ) {
		var http= 0;
		var out= {
			success= false
		,	error= ''
		};
	
		cfhttp( result="http", method="POST", url=this.apiUrl, charset="UTF-8", throwOnError=false, timeOut=this.httpTimeOut ) {
			cfhttpparam( type="formfield", name="secret", value= this.secret );
			cfhttpparam( type="formfield", name="remoteip", value= arguments.remoteIP );
			cfhttpparam( type="formfield", name="response", value= arguments.response );
		}
		out.response = toString( http.fileContent );

		if ( left( out.statusCode, 1 ) == 5 ) {
			arrayAppend( this.apiUrlPool, this.apiUrl );
			this.apiUrl = this.apiUrlPool[ 1 ];
			arrayDeleteAt( this.apiUrlPool, 1 );
		}
		if ( left( out.statusCode, 1 ) == 4 || left( out.statusCode, 1 ) == 5 ) {
			out.error = "status code error: #out.statusCode#";
		} else if ( out.response == "Connection Timeout" || out.response == "Connection Failure" ) {
			out.error = out.response;
		} else if ( left( out.statusCode, 1 ) == 2 ) {
			try {
				out.json= deserializeJSON( out.response );
				if( structKeyExists( out.json, "success" ) ) {
					out.success= out.json.success;
				}
				if( structKeyExists( out.json, "error-codes" ) ) {
					out.error= out.json[ "error-codes" ];
					if( isArray( out.error ) ) {
						out.error= listToArray( out.error, " " );
					}
				}
			} catch (any cfcatch) {
				out.error = "JSON Error: " & cfcatch.message;
			}
		}
		if ( len( out.error ) ) {
			out.success = false;
		}
		if ( !out.success ) {
			this.debugLog( out );
		}
		return out;
	}

	function js() {
		return "https://www.google.com/recaptcha/api.js";
	}

	function script() {
		writeOutput( '<script src="https://www.google.com/recaptcha/api.js" async defer></script>' );
	}

	function div() {
		writeOutput( '<div class="g-recaptcha" data-sitekey="#this.siteKey#"></div>' );
	}

}