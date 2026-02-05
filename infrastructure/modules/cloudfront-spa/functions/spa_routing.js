function handler(event) {
    var request = event.request;
    var uri = request.uri;

    // Check if the request is for a file (has extension)
    if (uri.includes('.')) {
        return request;
    }

    // Check if path starts with /api - don't rewrite API calls
    // This covers /api1/, /api2/, /api/, etc.
    if (uri.match(/^\/api[0-9]*\//)) {
        return request;
    }

    // For all other requests, serve index.html
    request.uri = '/index.html';
    return request;
}
