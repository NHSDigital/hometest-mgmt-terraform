// CloudFront Function for SPA routing
// This function is templated - API_PREFIXES_PATTERN is replaced at deploy time
// with a regex pattern matching all configured API path prefixes

function handler(event) {
    var request = event.request;
    var uri = request.uri;

    // Check if the request is for a file (has extension like .js, .css, .png, etc.)
    if (uri.includes('.')) {
        return request;
    }

    // API path prefixes pattern - TEMPLATED at deploy time
    // Example: /^\\/(api1|api2|hello-world|test-order|orders)(\\/|$)/
    // This is replaced by Terraform with actual API prefixes from lambdas configuration
    var apiPattern = /^\/(${API_PREFIXES_PATTERN})(\/|$)/;

    // Check if path matches any API prefix - don't rewrite API calls
    if (apiPattern.test(uri)) {
        return request;
    }

    // For all other requests (SPA client-side routes), serve index.html
    request.uri = '/index.html';
    return request;
}
