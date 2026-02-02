function handler(event) {
  var request = event.request;
  var uri = request.uri;

  // Redirect root to the main page
  if (uri === "/" || uri === "/index.html") {
    return {
      statusCode: 301,
      statusDescription: "Moved Permanently",
      headers: {
        location: { value: "/get-self-test-kit-for-HIV/" },
      },
    };
  }

  // Handle trailing slash - add index.html for directory-style paths
  if (uri.endsWith("/")) {
    request.uri = uri + "index.html";
  }
  // Handle paths without extension (SPA routing)
  else if (!uri.includes(".")) {
    request.uri = uri + "/index.html";
  }

  return request;
}
