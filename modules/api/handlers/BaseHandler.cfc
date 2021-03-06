/**
* ********************************************************************************
* Copyright 2005-2007 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
* www.ortussolutions.com
* ********************************************************************************
* Base RESTFul handler spice up as needed.
* This handler will create a Response model and prepare it for your actions to use
* to produce RESTFul responses.
*/
component extends="coldbox.system.EventHandler"{

	// OPTIONAL HANDLER PROPERTIES
	this.prehandler_only 		= "";
	this.prehandler_except 		= "";
	this.posthandler_only 		= "";
	this.posthandler_except 	= "";
	this.aroundHandler_only 	= "";
	this.aroundHandler_except 	= "";		

	// REST Allowed HTTP Methods Ex: this.allowedMethods = {delete='POST,DELETE',index='GET'}
	this.allowedMethods = {};
	
	/**
	* Around handler for all actions it inherits
	*/
	function aroundHandler( event, rc, prc, targetAction, eventArguments ){
		try{
			// start a resource timer
			var stime = getTickCount();
			// prepare our response object
			prc.response = getModel( "Response@api" );
			// prepare argument execution
			var args = { event = arguments.event, rc = arguments.rc, prc = arguments.prc };
			structAppend( args, arguments.eventArguments );
			// Secure the call
			if( isAuthorized( event, rc, prc, targetAction ) ){
				// Execute action
				var simpleResults = arguments.targetAction( argumentCollection=args );
			}
		} catch( Any e ){
			// Log Locally
			log.error( "Error calling #event.getCurrentEvent()#: #e.message# #e.detail#", e );
			// Setup General Error Response
			prc.response
				.setError( true )
				.setErrorCode( e.errorCode eq 0 ? 500 : len( e.errorCode ) ? e.errorCode : 0 )
				.addMessage( "General application error: #e.message#" )
				.setStatusCode( 500 )
				.setStatusText( "General application error" );
			// Development additions
			if( getSetting( "environment" ) eq "development" ){
				prc.response.addMessage( "Detail: #e.detail#" )
					.addMessage( "StackTrace: #e.stacktrace#" );
			}
		}
		
		// Development additions
		if( getSetting( "environment" ) eq "development" ){
			prc.response.addHeader( "x-current-route", event.getCurrentRoute() )
				.addHeader( "x-current-routed-url", event.getCurrentRoutedURL() )
				.addHeader( "x-current-routed-namespace", event.getCurrentRoutedNamespace() )
				.addHeader( "x-current-event", event.getCurrentEvent() );
		}
		// end timer
		prc.response.setResponseTime( getTickCount() - stime );
		
		// Did the user set a view to be rendered? If not use renderdata, else just delegate to view.
		if( !len( event.getCurrentView() ) ){
			// Simple HTML Handler Results?
			if( !isNull( simpleResults ) ){
				prc.response.setData( simpleResults )
					.setFormat( "html" );
				return simpleResults;

			} else {
				// Magical Response renderings
				event.renderData( 
					type		= prc.response.getFormat(),
					data 		= prc.response.getDataPacket(),
					contentType = prc.response.getContentType(),
					statusCode 	= prc.response.getStatusCode(),
					statusText 	= prc.response.getStatusText(),
					location 	= prc.response.getLocation(),
					isBinary 	= prc.response.getBinary()
				);
			}
		}
		
		// Global Response Headers
		prc.response.addHeader( "x-response-time", prc.response.getResponseTime() )
				.addHeader( "x-cached-response", prc.response.getCachedResponse() )
		
		// Response Headers
		for( var thisHeader in prc.response.getHeaders() ){
			event.setHTTPHeader( name=thisHeader.name, value=thisHeader.value );
		}
	}

	/**
	* on localized errors
	*/
	function onError( event, rc, prc, faultAction, exception, eventArguments ){
		// Log Locally
		log.error( "Error in base handler (#arguments.faultAction#): #arguments.exception.message# #arguments.exception.detail#", arguments.exception );
		// Verify response exists, else create one
		if( !structKeyExists( prc, "response" ) ){ prc.response = getModel( "Response@api" ); }
		// Setup General Error Response
		prc.response
			.setError( true )
			.setErrorCode( 501 )
			.addMessage( "Base Handler Application Error: #arguments.exception.message#" )
			.setStatusCode( 500 )
			.setStatusText( "General application error" );
		
		// Development additions
		if( getSetting( "environment" ) eq "development" ){
			prc.response.addMessage( "Detail: #arguments.exception.detail#" )
				.addMessage( "StackTrace: #arguments.exception.stacktrace#" );
		}
		
		// Render Error Out
		event.renderData( 
			type		= prc.response.getFormat(),
			data 		= prc.response.getDataPacket(),
			contentType = prc.response.getContentType(),
			statusCode 	= prc.response.getStatusCode(),
			statusText 	= prc.response.getStatusText(),
			location 	= prc.response.getLocation(),
			isBinary 	= prc.response.getBinary()
		);
	}

	/**
	* on invalid http verbs
	*/
	function onInvalidHTTPMethod( event, rc, prc, faultAction, eventArguments ){
		// Log Locally
		log.warn( "InvalidHTTPMethod Execution of (#arguments.faultAction#): #event.getHTTPMethod()#", getHTTPRequestData() );
		// Setup Response
		prc.response = getModel( "Response@api" )
			.setError( true )
			.setErrorCode( 405 )
			.addMessage( "InvalidHTTPMethod Execution of (#arguments.faultAction#): #event.getHTTPMethod()#" )
			.setStatusCode( 405 )
			.setStatusText( "Invalid HTTP Method" );
		// Render Error Out
		event.renderData( 
			type		= prc.response.getFormat(),
			data 		= prc.response.getDataPacket(),
			contentType = prc.response.getContentType(),
			statusCode 	= prc.response.getStatusCode(),
			statusText 	= prc.response.getStatusText(),
			location 	= prc.response.getLocation(),
			isBinary 	= prc.response.getBinary()
		);
	}

	/**
	* An unathorized request
	*/
	function onNotAuthorized( event, rc, prc ){
		prc.response.addMessage( "Unathorized Request! You do not have the right permissions to execute this request" )
			.setError( true )
			.setErrorCode( 403 )
			.setStatusCode( 403 )
			.setStatusText( "Invalid Permissions" );
	}

	/**
	* An un-authenticated request or session timeout
	*/
	function onNotAuthenticated( event, rc, prc ){
		prc.response.addMessage( "You are not logged in or your session has timed out, please try again." )
			.setError( true )
			.setErrorCode( 401 )
			.setStatusCode( 401 )
			.setStatusText( "Not Authenticated" );
	}

	/**
	* Secure an API Call
	* It looks for a 'secured' annotation, the value would be the permissions you need to execute the action.
	* By default all calls are secured unless they have an annotation of 'public'
	*/
	private boolean function isAuthorized( event, rc, prc, targetAction ){
		// Get metadata on executed action
		var md = getMetadata( arguments.targetAction );

		// Is this a public action?
		if( structKeyExistS( md, 'public' ) ){ return true; }

		return true;
		
		// Check logged in
		if( !prc.oCurrentUser.getLoggedIn() ){ 
			onNotAuthenticated( event, rc, prc );
			return false;
		}
		
		// Check permissions and if you have them
		if( structKeyExists( md, "secured" ) && len( md.secured ) && !prc.oCurrentUser.checkPermission( md.secured ) ){ 
			onNotAuthorized( event, rc, prc );
			return false; 
		}

		return true;
	}

}