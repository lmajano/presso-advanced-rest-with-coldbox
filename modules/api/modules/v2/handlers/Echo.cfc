/**
* A normal ColdBox Event Handler
*/
component extends="api.handlers.BaseHandler"{

	/**
	* Echo API Version
	*/
	function index( event, rc, prc ){
		prc.response.setData( "Welcome to the API v2" );
	}

}